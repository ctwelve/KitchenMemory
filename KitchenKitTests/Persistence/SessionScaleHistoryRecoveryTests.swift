// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import UndoKit
import XCTest

@MainActor
final class SessionScaleHistoryRecoveryTests: XCTestCase {
  func testAcceptedReplyLossAndFailedInverseRetainExactScaleDeliveryAcrossReopen() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let original = try XCTUnwrap(fixture.session().workingScale)
    let boundary = ControlledHistoryRepository(fixture.base.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    boundary.loseNextReply = true
    boundary.withholdReceipts = true
    let lost = try await history.scale(fixture.id, to: SessionWorkingScale(exactScale: RationalQuantity(numerator: 2)))
    guard case .unresolved = lost else { XCTFail("Lost reply requires recovery"); return }
    let accepted = try XCTUnwrap(boundary.deliveries.last)
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 1)
    XCTAssertEqual(history.pendingSessionID, fixture.id)
    do {
      _ = try await history.scale(fixture.id, to: original)
      XCTFail("Unresolved history must block later scale work")
    } catch { XCTAssertEqual(error as? RecipeOrganizationHistoryError, .ineligible) }
    await history.close()
    boundary.withholdReceipts = false
    XCTAssertEqual(try RecipeOrganizationHistory.pendingSessionID(in: fixture.base.scope,
      historyURL: fixture.base.historyURL), fixture.id)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    XCTAssertEqual(boundary.deliveries, [accepted])
    boundary.failNextAcceptance = true
    _ = await history.undo()
    let frozen = try XCTUnwrap(boundary.deliveries.last)
    XCTAssertTrue(history.hasPendingCompensation)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    _ = try await history.retryPending()
    XCTAssertEqual(boundary.deliveries.last, frozen)
    XCTAssertEqual(try fixture.session().workingScale, original)
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 2)
    XCTAssertTrue(try XCTUnwrap(history.session).status.canRedo)
    await history.close()
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 2)
    assertOrganizationHistoryAccepted(await history.redo())
    XCTAssertEqual(try fixture.session().workingScale?.exactScale, RationalQuantity(numerator: 2))
    await history.close()
  }

  func testExternalOutcomeRetiresScaleAndFrozenDeliveryCannotOverwriteIt() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    let change = try XCTUnwrap(fixture.base.repository.prepareHistoryScale(fixture.id,
      to: SessionWorkingScale(exactScale: RationalQuantity(numerator: 2)), in: fixture.base.scope))
    let frozen = try fixture.base.repository.prepareHistoryDelivery(change, memberID: UUID(),
      token: HistoryToken(scope: try XCTUnwrap(history.session?.configuration?.scope),
        generation: UUID(), sequence: 1, command: UUID()),
      in: fixture.base.scope)
    _ = try fixture.sessions.perform(.setOutcome(.init(id: .init(), sessionID: fixture.id, authoredAt: Date()),
      .coarse(.okay)))
    XCTAssertThrowsError(try fixture.base.repository.acceptHistory(frozen))
    assertOrganizationHistoryAccepted(try await history.scale(fixture.id,
      to: SessionWorkingScale(exactScale: RationalQuantity(numerator: 3))))
    _ = try fixture.sessions.perform(.setOutcome(.init(id: .init(), sessionID: fixture.id, authoredAt: Date()),
      .coarse(.great)))
    _ = await history.reconcile()
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    await history.close()
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    XCTAssertEqual(try fixture.session().workingScale?.exactScale, RationalQuantity(numerator: 3))
    await history.close()
  }
}
