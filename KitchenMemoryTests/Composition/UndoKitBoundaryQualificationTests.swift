// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenMemory
import UndoKit
import XCTest

@MainActor
final class UndoKitBoundaryQualificationTests: XCTestCase {
  func testPersistedHistoryRefusesMismatchedWorkingIdentityAndUnknownScopeWithoutReplacement() async throws {
    let rig = try await UndoQualificationRig()
    addTeardownBlock { await rig.remove() }
    let commands = try rig.session.commands(for: rig.operation)
    assertAccepted(await commands.submit(UndoQualificationChange(before: rig.host.values,
      after: Array(rig.host.values.reversed()))))
    await rig.session.close()
    let historyURL = rig.directory.appendingPathComponent("History.sqlite")
    let original = try Data(contentsOf: historyURL)
    let mismatches = [(rig.scope, UUID()), (UUID(), rig.working)]
    for (scope, working) in mismatches {
      let owners = HistorySessions()
      let refused = await owners.open(configuration: qualificationConfiguration(rig.directory,
        scope: scope, working: working, mode: .existing), lease: rig.host, operations: [rig.operation.erased])
      XCTAssertEqual(refused.status.phase, .blocked)
      XCTAssertFalse(refused.status.canUndo)
      XCTAssertFalse(refused.status.canRedo)
      await refused.close()
      XCTAssertEqual(try Data(contentsOf: historyURL), original)
      XCTAssertEqual(rig.host.acceptanceCount, 1)
    }
    try await rig.reopen()
    XCTAssertEqual(rig.session.status.phase, .ready)
    assertAccepted(await rig.session.undo())
    XCTAssertEqual(rig.host.values.map(\.title), ["Soup", "Bread"])
  }

  func testInvalidBatchAndProvedHostWriteFailureLeaveNoPartialEffectOrHistory() async throws {
    let rig = try await UndoQualificationRig()
    addTeardownBlock { await rig.remove() }
    let commands = try rig.session.commands(for: rig.operation)
    let before = rig.host.values
    let change = UndoQualificationChange(before: before, after: Array(before.reversed()))
    let invalid = UndoQualificationChange(before: [], after: before)
    let batchResult = await commands.submitGroup([change, invalid])
    XCTAssertEqual(batchResult, .rejected)
    XCTAssertEqual(rig.host.values, before)
    XCTAssertEqual(rig.host.acceptanceCount, 0)
    XCTAssertFalse(rig.session.status.canUndo)
    rig.host.failNextWrite = true
    let writeResult = await commands.submit(change)
    XCTAssertEqual(writeResult, .rejected)
    try await rig.reopen()
    XCTAssertEqual(rig.host.values, before)
    XCTAssertEqual(rig.host.acceptanceCount, 0)
    XCTAssertFalse(rig.session.status.canUndo)
  }

  func testHundredGroupPolicyBoundsRetainedDetailAndRestoredUndoDepth() async throws {
    let rig = try await UndoQualificationRig()
    addTeardownBlock { await rig.remove() }
    let commands = try rig.session.commands(for: rig.operation)
    for index in 0..<101 {
      let before = rig.host.values
      let after = [UndoQualificationItem(id: before[0].id, title: String(index)), before[1]]
      assertAccepted(await commands.submit(UndoQualificationChange(before: before, after: after)))
    }
    let checkpoint = try rig.session.advanced.createCheckpoint(id: UUID(), name: nil,
      state: HistoryPayload(family: "qualification.baseline", data: JSONEncoder().encode(rig.host.values)),
      resources: [])
    let consolidated = try rig.session.advanced.consolidateHistory(through: checkpoint.id,
      policy: HistoryRetentionPolicy(targetDetailedGroups: 100))
    XCTAssertEqual(consolidated.retainedGroups, 100)
    try await rig.reopen()
    for _ in 0..<100 { assertAccepted(await rig.session.undo()) }
    XCTAssertFalse(rig.session.status.canUndo)
    XCTAssertEqual(rig.host.values.map(\.title), ["0", "Bread"], "The 101st-oldest group is outside the Undo frontier")
  }

  func testExplicitDisposalRetiresGenerationAndStaleCommandsCannotResurrectAfterReopen() async throws {
    let rig = try await UndoQualificationRig()
    addTeardownBlock { await rig.remove() }
    let commands = try rig.session.commands(for: rig.operation)
    let change = UndoQualificationChange(before: rig.host.values, after: Array(rig.host.values.reversed()))
    assertAccepted(await commands.submit(change))
    _ = try rig.session.advanced.clearHistory(adopting: HistoryPayload(family: "qualification.baseline",
      data: JSONEncoder().encode(rig.host.values)))
    guard case .unexecuted = await commands.submit(change.inverse) else {
      XCTFail("Disposed scene generation accepted a stale capability")
      return
    }
    try await rig.reopen()
    XCTAssertFalse(rig.session.status.canUndo)
    XCTAssertFalse(rig.session.status.canRedo)
    XCTAssertEqual(rig.host.acceptanceCount, 1)
  }

  func testUnreadableHistoryIsRefusedAndPreservedWithoutOpeningAnEmptyReplacement() async throws {
    let rig = try await UndoQualificationRig()
    addTeardownBlock { await rig.remove() }
    await rig.session.close()
    let historyURL = rig.directory.appendingPathComponent("History.sqlite")
    let sentinel = Data("unsupported-history-format".utf8)
    try sentinel.write(to: historyURL, options: .atomic)
    try await rig.reopen()
    XCTAssertEqual(rig.session.status.phase, .blocked)
    XCTAssertFalse(rig.session.status.canUndo)
    XCTAssertEqual(try Data(contentsOf: historyURL), sentinel)
    XCTAssertEqual(rig.host.acceptanceCount, 0)
  }
}
