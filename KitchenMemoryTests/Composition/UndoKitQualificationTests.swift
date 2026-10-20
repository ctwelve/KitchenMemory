// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenMemory
import UndoKit
import XCTest

@MainActor
final class UndoKitQualificationTests: XCTestCase {
  func testOrderedIdentityValuesSurviveNativeUndoRedoAndReopeningWithoutReplay() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let first = UndoQualificationItem(id: UUID(), title: "Soup")
    let second = UndoQualificationItem(id: UUID(), title: "Bread")
    let before = [first, second]
    let after = [second, first]
    let scope = UUID()
    let working = UUID()
    let owners = HistorySessions()
    let host = UndoQualificationHost(url: directory.appendingPathComponent("Host.json"), initial: before)
    let operation = try qualificationOperation(host)
    let session = await owners.open(configuration: qualificationConfiguration(directory, scope: scope,
      working: working, mode: .create), lease: host, operations: [operation.erased])
    XCTAssertEqual(session.status.phase, .ready)
    session.setNativeActionNameResolver { qualificationActionName($0, label: "Reorder items") }
    let commands = try session.commands(for: operation)
    assertAccepted(await commands.submit(UndoQualificationChange(before: before, after: after)))
    let attachment = try session.attach(owner: host)
    XCTAssertEqual(attachment.undoManager.undoActionName, "Reorder items")
    attachment.undoManager.undo()
    await session.waitForNativeOperations()
    XCTAssertEqual(host.values, before)
    XCTAssertTrue(attachment.undoManager.canRedo)
    XCTAssertEqual(attachment.undoManager.redoActionName, "Reorder items")
    attachment.undoManager.redo()
    await session.waitForNativeOperations()
    XCTAssertEqual(host.values, after)
    XCTAssertEqual(attachment.undoManager.undoActionName, "Reorder items")
    XCTAssertEqual(host.acceptanceCount, 3)
    attachment.disconnect()
    await session.close()

    let reopenedHost = UndoQualificationHost(url: directory.appendingPathComponent("Host.json"), initial: [])
    let reopenedOperation = try qualificationOperation(reopenedHost)
    let reopened = await HistorySessions().open(configuration: qualificationConfiguration(directory, scope: scope,
      working: working, mode: .existing), lease: reopenedHost, operations: [reopenedOperation.erased])
    XCTAssertEqual(reopened.status.phase, .ready)
    reopened.setNativeActionNameResolver { qualificationActionName($0, label: "Réordonner les éléments") }
    XCTAssertEqual(reopenedHost.values, after)
    XCTAssertEqual(reopenedHost.acceptanceCount, 3, "Restoration must not execute historical commands")
    let restoredAttachment = try reopened.attach(owner: reopenedHost)
    XCTAssertEqual(restoredAttachment.undoManager.undoActionName, "Réordonner les éléments")
    assertAccepted(await reopened.undo())
    XCTAssertEqual(reopenedHost.values, before)
    restoredAttachment.disconnect()
    await reopened.close()
  }
}

@MainActor
func qualificationOperation(_ host: UndoQualificationHost) throws -> HistoryOperation<UndoQualificationChange> {
  try HistoryOperation(operation: "kitchenmemory.qualification.collection", commandCodec: .json(),
    effectCodec: .json(), handler: host, fingerprint: { changes in
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      return try encoder.encode(changes)
    }, metadata: { _ in
      HistoryOperationMetadata(presentation: HistoryPayload(
        family: "kitchenmemory.qualification.action", data: Data("reorder".utf8)))
    })
}

func qualificationConfiguration(_ directory: URL, scope: UUID, working: UUID,
                                mode: HistoryOpenMode) -> HistorySessionConfiguration {
  HistorySessionConfiguration(historyURL: directory.appendingPathComponent("History.sqlite"), scope: scope,
    workingIdentity: working, mode: mode, limits: HistoryLimits(maxUndoGroups: 100))
}

func assertAccepted(_ result: HistorySubmissionResult, file: StaticString = #filePath, line: UInt = #line) {
  guard case .accepted = result else {
    XCTFail("Expected accepted history transaction, got \(result)", file: file, line: line)
    return
  }
}

private func qualificationActionName(_ payload: HistoryPayload, label: String) -> String? {
  guard payload.family == "kitchenmemory.qualification.action",
        String(data: payload.data, encoding: .utf8) == "reorder" else { return nil }
  return label
}
