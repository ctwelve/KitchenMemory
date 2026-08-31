// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Darwin
import Foundation
import KitchenKit
import SwiftData

enum AcceptanceHarnessError: Error {
  case developmentContainerRequired
  case disposableRootRequired
  case generatedModelUnavailable
  case inconclusive
  case invalidArguments
  case invalidFixture
  case unsupportedActor
}

private enum AcceptanceStore: String {
  case local
  case cloud
}

private struct HarnessArguments {
  let command: String
  let values: [String: String]

  init(_ arguments: [String]) throws {
    guard let command = arguments.first else {
      throw AcceptanceHarnessError.invalidArguments
    }
    self.command = command
    var values: [String: String] = [:]
    var index = 1
    while index < arguments.count {
      let key = arguments[index]
      guard key.hasPrefix("--"), index + 1 < arguments.count else {
        throw AcceptanceHarnessError.invalidArguments
      }
      values[String(key.dropFirst(2))] = arguments[index + 1]
      index += 2
    }
    self.values = values
  }

  func required(_ key: String) throws -> String {
    guard let value = values[key], !value.isEmpty else {
      throw AcceptanceHarnessError.invalidArguments
    }
    return value
  }

  func integer(_ key: String, default fallback: Int) throws -> Int {
    guard let raw = values[key] else { return fallback }
    guard let value = Int(raw), value >= 0 else {
      throw AcceptanceHarnessError.invalidArguments
    }
    return value
  }
}

@main
@MainActor
struct SessionCloudKitAcceptance {
  static let developmentContainer = "iCloud.net.ctwelve.dev.KitchenMemory"

  static func main() async {
    do {
      try validateDisposableRoot()
      let arguments = try HarnessArguments(Array(CommandLine.arguments.dropFirst()))
      try await run(arguments)
    } catch AcceptanceHarnessError.inconclusive {
      AcceptanceOutput.emit([
        "event": "conclusion",
        "result": "inconclusive",
        "rerunnable": true,
      ])
      exit(2)
    } catch {
      AcceptanceOutput.emit([
        "event": "harness-error",
        "reason": safeReason(error),
      ])
      exit(1)
    }
  }

  private static func run(_ arguments: HarnessArguments) async throws {
    switch arguments.command {
    case "schema":
      try SchemaInspection.printV3()
    case "initialize":
#if os(macOS)
      let container = try checkedContainer(arguments)
      try CloudKitDevelopmentSchemaInitializer.initialize(
        containerIdentifier: container
      )
      AcceptanceOutput.emit([
        "event": "schema-initialization",
        "container": "development",
        "result": "operation-succeeded",
        "productionTouched": false,
      ])
#else
      throw AcceptanceHarnessError.invalidArguments
#endif
    case "stage":
      try await stage(arguments)
    case "reconnect":
      try await reconnect(arguments)
    case "observe":
      try await observe(arguments)
    case "local-matrix":
      try runLocalMatrix()
    default:
      throw AcceptanceHarnessError.invalidArguments
    }
  }

  private static func stage(_ arguments: HarnessArguments) async throws {
    let fixture = try makeFixture(arguments)
    let actor = try arguments.required("actor")
    let wait = try arguments.integer("wait", default: 30)
    let store = try makeStore(arguments)
    let recorder = CloudEventRecorder()
    let container = try makeContainer(store: store, arguments: arguments)
    let repository = SwiftDataCookingSessionRepository(modelContainer: container)
    let transactions = try fixture.transactions(for: actor)
    for transaction in transactions { try repository.append(transaction) }
    AcceptanceOutput.emit([
      "event": "stage",
      "scenario": fixture.scenario.rawValue,
      "run": fixture.runID.uuidString,
      "actor": actor,
      "transactions": transactions.count,
      "store": store.rawValue,
      "result": "locally-durable",
      "globalSyncClaim": false,
    ])
    await waitForOperations(seconds: wait)
    AcceptanceOutput.emit([
      "event": "stage-window-ended",
      "completedOperations": recorder.completedEventCount,
      "remoteChanges": recorder.remoteChangeCount,
      "claim": "diagnostic-only",
    ])
    _ = container
  }

  private static func observe(_ arguments: HarnessArguments) async throws {
    let fixture = try makeFixture(arguments)
    let checkpoint = arguments.values["checkpoint"] ?? "final"
    let timeout = try arguments.integer("timeout", default: 300)
    let store = try makeStore(arguments)
    let recorder = CloudEventRecorder()
    let container = try makeContainer(store: store, arguments: arguments)
    let repository = SwiftDataCookingSessionRepository(modelContainer: container)
    let deadline = ContinuousClock.now + .seconds(timeout)
    var lastSignature = ""
    repeat {
      repository.refreshFromPersistentStore()
      let observations = try fixture.observedSessionIDs().compactMap {
        try AcceptanceObservation.read(sessionID: $0, repository: repository)
      }
      let signature = observations.map { "\($0.classification):\($0.digest)" }
        .joined(separator: "|")
      if signature != lastSignature {
        AcceptanceOutput.emit([
          "event": "receiving-store-observation",
          "scenario": fixture.scenario.rawValue,
          "run": fixture.runID.uuidString,
          "checkpoint": checkpoint,
          "sessions": observations.map(\.output),
          "source": "domain-evidence",
        ])
        lastSignature = signature
      }
      if AcceptanceExpectation.isSatisfied(
        scenario: fixture.scenario,
        checkpoint: checkpoint,
        observations: observations
      ) {
        AcceptanceOutput.emit([
          "event": "conclusion",
          "scenario": fixture.scenario.rawValue,
          "run": fixture.runID.uuidString,
          "checkpoint": checkpoint,
          "result": "pass",
          "completedOperations": recorder.completedEventCount,
          "remoteChanges": recorder.remoteChangeCount,
          "authority": "receiving-store-domain-evidence",
        ])
        _ = container
        return
      }
      try await Task.sleep(for: .seconds(2))
    } while ContinuousClock.now < deadline
    _ = container
    throw AcceptanceHarnessError.inconclusive
  }

  private static func reconnect(_ arguments: HarnessArguments) async throws {
    let fixture = try makeFixture(arguments)
    let wait = try arguments.integer("wait", default: 30)
    let recorder = CloudEventRecorder()
    let container = try makeContainer(store: .cloud, arguments: arguments)
    let repository = SwiftDataCookingSessionRepository(modelContainer: container)
    repository.refreshFromPersistentStore()
    let observations = try fixture.observedSessionIDs().compactMap {
      try AcceptanceObservation.read(sessionID: $0, repository: repository)
    }
    AcceptanceOutput.emit([
      "event": "reconnect",
      "scenario": fixture.scenario.rawValue,
      "run": fixture.runID.uuidString,
      "localSessionsAtOpen": observations.map(\.output),
      "claim": "transport-window-only",
    ])
    await waitForOperations(seconds: wait)
    AcceptanceOutput.emit([
      "event": "reconnect-window-ended",
      "completedOperations": recorder.completedEventCount,
      "remoteChanges": recorder.remoteChangeCount,
      "globalSyncClaim": false,
    ])
    _ = container
  }

  private static func runLocalMatrix() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataCookingSessionRepository(modelContainer: container)
    for (offset, scenario) in AcceptanceScenario.allCases.enumerated() {
      let runID = UUID(uuid: (
        0x90, 0, 0, 0, 0, 0, 0x40, UInt8(offset),
        0x80, 0, 0, 0, 0, 0, 0, UInt8(offset + 1)
      ))
      let fixture = AcceptanceFixture(runID: runID, scenario: scenario)
      let actors: [String]
      switch scenario {
      case .e1, .e2b, .e4a, .e4b: actors = ["A", "B"]
      case .e3: actors = ["A"]
      case .e5: actors = ["A", "B", "R"]
      case .e7: actors = ["A1", "A2"]
      }
      for actor in actors {
        for transaction in try fixture.transactions(for: actor) {
          try repository.append(transaction)
        }
      }
      let observations = try fixture.observedSessionIDs().compactMap {
        try AcceptanceObservation.read(sessionID: $0, repository: repository)
      }
      guard AcceptanceExpectation.isSatisfied(
        scenario: scenario,
        checkpoint: "final",
        observations: observations
      ) else { throw AcceptanceHarnessError.invalidFixture }
      AcceptanceOutput.emit([
        "event": "local-matrix",
        "scenario": scenario.rawValue,
        "result": "pass",
        "sessions": observations.map(\.output),
      ])
    }
  }

  private static func makeFixture(
    _ arguments: HarnessArguments
  ) throws -> AcceptanceFixture {
    guard let runID = UUID(uuidString: try arguments.required("run")),
          let scenario = AcceptanceScenario(rawValue: try arguments.required("scenario"))
    else { throw AcceptanceHarnessError.invalidArguments }
    return AcceptanceFixture(runID: runID, scenario: scenario)
  }

  private static func makeStore(
    _ arguments: HarnessArguments
  ) throws -> AcceptanceStore {
    guard let store = AcceptanceStore(rawValue: arguments.values["store"] ?? "cloud") else {
      throw AcceptanceHarnessError.invalidArguments
    }
    return store
  }

  private static func makeContainer(
    store: AcceptanceStore,
    arguments: HarnessArguments
  ) throws -> ModelContainer {
    let environment = ProcessInfo.processInfo.environment
    guard let replica = environment["KM_ACCEPTANCE_REPLICA"],
          !replica.isEmpty,
          replica.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" })
    else { throw AcceptanceHarnessError.disposableRootRequired }
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "SessionCloudKitAcceptance")
      .appending(path: replica)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    let schema = Schema(versionedSchema: KitchenMemorySchemaV3.self)
    let database: ModelConfiguration.CloudKitDatabase
    switch store {
    case .local: database = .none
    case .cloud:
      database = .private(try checkedContainer(arguments))
    }
    let configuration = ModelConfiguration(
      "KitchenMemory",
      schema: schema,
      url: directory.appending(path: "KitchenMemory.store"),
      cloudKitDatabase: database
    )
    return try ModelContainer(
      for: schema,
      migrationPlan: KitchenMemoryMigrationPlan.self,
      configurations: [configuration]
    )
  }

  private static func checkedContainer(
    _ arguments: HarnessArguments
  ) throws -> String {
    let identifier = arguments.values["container"] ?? developmentContainer
    guard identifier == developmentContainer, identifier.contains(".dev.") else {
      throw AcceptanceHarnessError.developmentContainerRequired
    }
    return identifier
  }

  private static func validateDisposableRoot() throws {
    let environment = ProcessInfo.processInfo.environment
    // Core Foundation consumes CFFIXED_USER_HOME before Swift receives the
    // process environment. The wrapper supplies both variables; this retained
    // marker lets the executable independently refuse an ordinary user store.
    guard let fixedHome = environment["KM_ACCEPTANCE_DISPOSABLE_ROOT"],
          fixedHome.hasPrefix("/private/tmp/KitchenMemorySessionAcceptance-")
    else { throw AcceptanceHarnessError.disposableRootRequired }
  }

  private static func waitForOperations(seconds: Int) async {
    guard seconds > 0 else { return }
    try? await Task.sleep(for: .seconds(seconds))
  }

  private static func safeReason(_ error: any Error) -> String {
    switch error {
    case AcceptanceHarnessError.developmentContainerRequired: "development-container-required"
    case AcceptanceHarnessError.disposableRootRequired: "disposable-root-required"
    case AcceptanceHarnessError.generatedModelUnavailable: "generated-model-unavailable"
    case AcceptanceHarnessError.invalidArguments: "invalid-arguments"
    case AcceptanceHarnessError.invalidFixture: "invalid-fixture"
    case AcceptanceHarnessError.unsupportedActor: "unsupported-actor"
    default: "operation-failed"
    }
  }
}
