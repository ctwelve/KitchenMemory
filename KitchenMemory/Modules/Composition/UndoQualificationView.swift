// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if TESTING
import Foundation
import SwiftUI
import UndoKit

/// A signed, disposable native test host; absent from distributed builds.
@MainActor
@Observable
final class UndoQualificationModel {
  static var launchIdentifier: UUID? {
    let arguments = ProcessInfo.processInfo.arguments
    guard AppBuildEnvironment.current.permitsUITestHarness, arguments.contains("--ui-testing"),
      let index = arguments.firstIndex(of: "--undo-qualification"), index + 1 < arguments.count
    else { return nil }
    return UUID(uuidString: arguments[index + 1])
  }

  private let owners = HistorySessions()
  private let identifier: UUID
  private var directory: URL?
  private var host: UndoQualificationHost?
  private var commands: HistoryCommands<UndoQualificationChange>?
  private var session: HistorySession?
  private var attachment: HistoryAttachment?
  var state = "Opening"
  var canUndo = false
  var canRedo = false
  var ready = false

  init(identifier: UUID) { self.identifier = identifier }

  func open() async {
    guard session == nil else { return }
    do {
      // UUID-only paths in the disposable test app's container; never a Kitchen URL.
      let directory = try FileManager.default.url(for: .applicationSupportDirectory,
        in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent("UndoQualification", isDirectory: true)
        .appendingPathComponent(identifier.uuidString, isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      self.directory = directory
      let host = UndoQualificationHost(url: directory.appendingPathComponent("Host.json"), initial: [
        UndoQualificationItem(id: UUID(uuidString: "E2360000-0000-4000-8000-000000000001")!, title: "Soup"),
        UndoQualificationItem(id: UUID(uuidString: "E2360000-0000-4000-8000-000000000002")!, title: "Bread"),
      ])
      self.host = host
      let operation = try HistoryOperation(operation: "kitchenmemory.qualification.collection",
        commandCodec: HistoryCodec<UndoQualificationChange>.json(), effectCodec: .json(), handler: host,
        fingerprint: { changes in
          let encoder = JSONEncoder()
          encoder.outputFormatting = [.sortedKeys]
          return try encoder.encode(changes)
        })
      let historyURL = directory.appendingPathComponent("History.sqlite")
      let mode: HistoryOpenMode = FileManager.default.fileExists(atPath: historyURL.path) ? .existing : .create
      let session = await owners.open(configuration: HistorySessionConfiguration(historyURL: historyURL,
        scope: identifier, workingIdentity: identifier, mode: mode,
        limits: HistoryLimits(maxUndoGroups: 100)), lease: host, operations: [operation.erased])
      self.session = session
      guard session.status.phase == .ready else {
        state = "Blocked"
        return
      }
      commands = try session.commands(for: operation)
      attachment = try session.attach(owner: self) { owner, _ in owner.refresh() }
      refresh()
    } catch { state = "Blocked" }
  }

  func apply(losingReply: Bool = false) async {
    guard let host, let commands else { return }
    host.loseNextReply = losingReply
    host.withholdOutcomes = losingReply
    _ = await commands.submit(UndoQualificationChange(before: host.values, after: Array(host.values.reversed())))
    refresh()
  }

  func undo() async {
    attachment?.undoManager.undo()
    await session?.waitForNativeOperations()
    refresh()
  }

  func redo() async {
    attachment?.undoManager.redo()
    await session?.waitForNativeOperations()
    refresh()
  }

  func cleanup() async {
    attachment?.disconnect()
    await session?.close()
    guard session?.status.phase == .closed, let directory else { return }
    do {
      try FileManager.default.removeItem(at: directory)
      state = "Removed"
      ready = false
    } catch { state = "Cleanup failed" }
  }

  private func refresh() {
    guard let host, let session else { return }
    state = host.values.map(\.title).joined(separator: ", ") + "; accepted: \(host.acceptanceCount)"
    canUndo = session.status.canUndo
    canRedo = session.status.canRedo
    ready = session.status.phase == .ready
  }
}

struct UndoQualificationView: View {
  @State private var model: UndoQualificationModel

  init(identifier: UUID) { _model = State(initialValue: UndoQualificationModel(identifier: identifier)) }

  var body: some View {
    VStack(spacing: 16) {
      Text(verbatim: model.state).accessibilityIdentifier("undo-qualification-state")
      Button(action: { Task { await model.apply() } }, label: { Text(verbatim: "Apply") })
        .accessibilityIdentifier("undo-qualification-apply").disabled(!model.ready)
      Button(action: { Task { await model.apply(losingReply: true) } },
        label: { Text(verbatim: "Apply and lose reply") })
        .accessibilityIdentifier("undo-qualification-lose-reply").disabled(!model.ready)
      Button(action: { Task { await model.undo() } }, label: { Text(verbatim: "Undo") })
        .accessibilityIdentifier("undo-qualification-undo").disabled(!model.canUndo)
      Button(action: { Task { await model.redo() } }, label: { Text(verbatim: "Redo") })
        .accessibilityIdentifier("undo-qualification-redo").disabled(!model.canRedo)
      Button(action: { Task { await model.cleanup() } }, label: { Text(verbatim: "Remove test files") })
        .accessibilityIdentifier("undo-qualification-cleanup")
    }
    .padding().frame(minWidth: 250, minHeight: 250)
    .task { await model.open() }
  }
}
#endif
