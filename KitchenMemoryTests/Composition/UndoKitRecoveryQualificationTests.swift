// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenMemory
import UndoKit
import XCTest

@MainActor
final class UndoKitRecoveryQualificationTests: XCTestCase {
  func testAcceptedEffectWithLostReplyRecoversByReceiptWithoutRedelivery() async throws {
    let rig = try await UndoQualificationRig()
    addTeardownBlock { await rig.remove() }
    let commands = try rig.session.commands(for: rig.operation)
    let change = UndoQualificationChange(before: rig.host.values, after: Array(rig.host.values.reversed()))
    rig.host.loseNextReply = true
    rig.host.withholdOutcomes = true
    let result = await commands.submit(change)
    guard case .unresolved = result else {
      XCTFail("Expected a retained unresolved outcome")
      return
    }
    XCTAssertEqual(rig.host.acceptanceCount, 1)
    XCTAssertFalse(rig.session.status.canUndo)
    try await rig.reopen()
    XCTAssertEqual(rig.session.status.phase, .ready)
    XCTAssertEqual(rig.host.values.map(\.title), ["Bread", "Soup"])
    XCTAssertEqual(rig.host.acceptanceCount, 1)
    XCTAssertGreaterThan(rig.host.outcomeLookupCount, 0)
    assertAccepted(await rig.session.undo())
    XCTAssertEqual(rig.host.values.map(\.title), ["Soup", "Bread"])
  }

  func testUnknownOutcomeStaysBlockedAcrossReopeningUntilAuthoritativeLookupSucceeds() async throws {
    let rig = try await UndoQualificationRig()
    addTeardownBlock { await rig.remove() }
    let commands = try rig.session.commands(for: rig.operation)
    rig.host.loseNextReply = true
    rig.host.withholdOutcomes = true
    _ = await commands.submit(UndoQualificationChange(before: rig.host.values,
      after: Array(rig.host.values.reversed())))
    let originalToken = try XCTUnwrap(rig.host.receiptTokens.first)
    try await rig.reopen(withholdOutcomes: true)
    XCTAssertFalse(rig.session.status.canUndo)
    XCTAssertFalse(rig.session.status.canRedo)
    XCTAssertEqual(rig.host.acceptanceCount, 1)
    rig.host.withholdOutcomes = false
    _ = await rig.session.reconcile()
    XCTAssertEqual(rig.session.status.phase, .ready)
    XCTAssertEqual(rig.host.receiptTokens, [originalToken])
    assertAccepted(await rig.session.undo())
    XCTAssertEqual(rig.host.values.map(\.title), ["Soup", "Bread"])
  }

  func testRejectedInverseInvalidatesOlderHistoryDurablyAndNeverOffersFalseRedo() async throws {
    let rig = try await UndoQualificationRig()
    addTeardownBlock { await rig.remove() }
    let commands = try rig.session.commands(for: rig.operation)
    for _ in 0..<2 {
      assertAccepted(await commands.submit(UndoQualificationChange(before: rig.host.values,
        after: Array(rig.host.values.reversed()))))
    }
    rig.host.rejectNextInverse = true
    let result = await rig.session.undo()
    XCTAssertEqual(result, .rejected)
    XCTAssertFalse(rig.session.status.canUndo, "Failure must not fall through to an older app action")
    XCTAssertFalse(rig.session.status.canRedo)
    try await rig.reopen()
    XCTAssertFalse(rig.session.status.canUndo)
    XCTAssertFalse(rig.session.status.canRedo)
    XCTAssertEqual(rig.host.acceptanceCount, 2)
    XCTAssertEqual(rig.host.values.map(\.title), ["Soup", "Bread"])
  }
}
