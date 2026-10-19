// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if TESTING
import Foundation
import UndoKit

nonisolated struct UndoQualificationItem: Codable, Equatable, Sendable {
  let id: UUID
  let title: String
}

nonisolated struct UndoQualificationChange: Codable, Equatable, Sendable {
  let before: [UndoQualificationItem]
  let after: [UndoQualificationItem]

  var inverse: Self { Self(before: after, after: before) }
}

/// Disposable single-writer domain store. Never opens KitchenMemory production data.
/// One atomic file replacement commits both collection values and accepted receipts.
@MainActor
final class UndoQualificationHost: MainActorHistoryOperationHandler, HistoryHostLease {
  typealias Command = UndoQualificationChange
  typealias Effect = UndoQualificationChange

  private struct StoredToken: Codable, Equatable {
    let scope: UUID
    let generation: UUID
    let sequence: Int64
    let command: UUID

    init(_ token: HistoryToken) {
      scope = token.scope
      generation = token.generation
      sequence = token.sequence
      command = token.command
    }

    var value: HistoryToken {
      HistoryToken(scope: scope, generation: generation, sequence: sequence, command: command)
    }
  }

  private struct MemberEffect: Codable {
    let memberID: UUID
    let undo: UndoQualificationChange
    let redo: UndoQualificationChange

    var value: HistoryTypedEffect<Effect> {
      HistoryTypedEffect(memberID: memberID, undo: undo, redo: redo)
    }
  }

  private struct Receipt: Codable {
    let token: StoredToken
    let effects: [MemberEffect]

    var outcome: HistoryTypedOutcome<Effect> { .accepted(effects.map(\.value)) }
  }

  private struct Stored: Codable {
    var values: [UndoQualificationItem]
    var receipts: [Receipt]
  }

  private enum StoreError: Error {
    case invalidStore
  }

  private let url: URL
  private let initial: [UndoQualificationItem]
  private var stored: Stored
  private(set) var outcomeLookupCount = 0

  var values: [UndoQualificationItem] { stored.values }
  var acceptanceCount: Int { stored.receipts.count }
  var receiptTokens: [HistoryToken] { stored.receipts.map { $0.token.value } }

  /// Inject a proved pre-write rejection; the file and in-memory values stay intact.
  var failNextWrite = false
  /// Commit successfully, then simulate losing the host's reply.
  var loseNextReply = false
  var withholdOutcomes = false
  var rejectNextInverse = false

  init(url: URL, initial: [UndoQualificationItem]) {
    self.url = url
    self.initial = initial
    stored = Stored(values: initial, receipts: [])
  }

  func open(_ mode: HistoryOpenMode) async throws {
    if FileManager.default.fileExists(atPath: url.path) {
      stored = try load()
    } else if mode == .create {
      guard Self.uniqueItems(initial) else { throw StoreError.invalidStore }
      let candidate = Stored(values: initial, receipts: [])
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try persist(candidate)
      stored = candidate
    } else {
      // A missing or corrupt existing store must never be silently recreated.
      stored = try load()
    }
  }

  func close() async throws {}

  func apply(
    _ commands: [(UUID, Command)], context: HistoryOperationContext
  ) async -> HistoryTypedOutcome<Effect> {
    execute(commands, token: context.token, inverse: false)
  }

  func undo(
    _ effects: [(UUID, Effect)], context: HistoryOperationContext
  ) async -> HistoryTypedOutcome<Effect> {
    execute(effects, token: context.token, inverse: true)
  }

  func redo(
    _ effects: [(UUID, Effect)], context: HistoryOperationContext
  ) async -> HistoryTypedOutcome<Effect> {
    execute(effects, token: context.token, inverse: true)
  }

  func outcome(for token: HistoryToken) async -> HistoryTypedOutcome<Effect> {
    outcomeLookupCount += 1
    guard !withholdOutcomes else { return .unresolved }
    do {
      stored = try load()
      // This fixture owns the only writer: absence in an intact file proves no effect.
      return stored.receipts.first { $0.token == StoredToken(token) }?.outcome ?? .rejected
    } catch {
      return .unresolved
    }
  }

  private func execute(
    _ changes: [(UUID, UndoQualificationChange)], token: HistoryToken, inverse: Bool
  ) -> HistoryTypedOutcome<Effect> {
    do {
      stored = try load()
    } catch {
      return .unresolved
    }
    // An exact retry returns durable evidence before examining current values or faults.
    if let receipt = stored.receipts.first(where: { $0.token == StoredToken(token) }) {
      return receipt.outcome
    }
    if inverse && rejectNextInverse {
      rejectNextInverse = false
      return .rejected
    }
    guard !changes.isEmpty, Set(changes.map(\.0)).count == changes.count else {
      return .rejected
    }
    var candidate = stored
    var effects: [MemberEffect] = []
    for (memberID, change) in changes {
      guard candidate.values == change.before, Self.uniqueItems(change.after) else {
        return .rejected
      }
      candidate.values = change.after
      effects.append(MemberEffect(memberID: memberID, undo: change.inverse, redo: change))
    }
    if failNextWrite {
      failNextWrite = false
      return .rejected
    }
    let receipt = Receipt(token: StoredToken(token), effects: effects)
    candidate.receipts.append(receipt)
    do {
      try persist(candidate)
      stored = candidate
    } catch {
      // A real write failure may have happened after replacement: require disk lookup.
      return .unresolved
    }
    if loseNextReply {
      loseNextReply = false
      return .unresolved
    }
    return receipt.outcome
  }

  private func load() throws -> Stored {
    let value = try JSONDecoder().decode(Stored.self, from: Data(contentsOf: url))
    let tokens = value.receipts.map { $0.token.value }
    guard Self.uniqueItems(value.values), Set(tokens).count == tokens.count else {
      throw StoreError.invalidStore
    }
    for receipt in value.receipts {
      let members = receipt.effects.map(\.memberID)
      guard !members.isEmpty, Set(members).count == members.count,
        receipt.effects.allSatisfy({
          $0.undo == $0.redo.inverse
            && Self.uniqueItems($0.redo.before) && Self.uniqueItems($0.redo.after)
        })
      else { throw StoreError.invalidStore }
    }
    return value
  }

  private func persist(_ value: Stored) throws {
    try JSONEncoder().encode(value).write(to: url, options: .atomic)
  }

  private static func uniqueItems(_ values: [UndoQualificationItem]) -> Bool {
    Set(values.map(\.id)).count == values.count
  }
}

#endif
