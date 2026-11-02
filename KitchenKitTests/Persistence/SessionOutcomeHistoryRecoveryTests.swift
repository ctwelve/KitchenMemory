// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import UndoKit
import XCTest

@MainActor
final class SessionOutcomeHistoryRecoveryTests: XCTestCase {
  func testLostReplyAndFailedClearInverseRecoverExactOptionalOutcomeAcrossReopen() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let boundary = ControlledHistoryRepository(fixture.base.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    boundary.loseNextReply = true
    boundary.withholdReceipts = true
    let lost = try await history.outcome(fixture.id, to: .coarse(.great))
    guard case .unresolved = lost else { XCTFail("Lost reply requires recovery"); return }
    let accepted = try XCTUnwrap(boundary.deliveries.last)
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 1)
    XCTAssertEqual(history.pendingSessionID, fixture.id)
    do {
      _ = try await history.outcome(fixture.id, to: .coarse(.okay))
      XCTFail("Unresolved history must block later Outcome work")
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
    XCTAssertNil(try fixture.session().outcome)
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 2)
    XCTAssertTrue(try XCTUnwrap(history.session).status.canRedo)
    await history.close()
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 2)
    assertOrganizationHistoryAccepted(await history.redo())
    XCTAssertEqual(try fixture.session().outcome, .coarse(.great))
    await history.close()
  }

  func testExternalProgressRefusesFrozenOutcomeAndExternalScaleRetiresAcceptedHistory() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    let change = try XCTUnwrap(fixture.base.repository.prepareHistoryOutcome(fixture.id,
      to: .coarse(.great), in: fixture.base.scope))
    let frozen = try fixture.base.repository.prepareHistoryDelivery(change, memberID: UUID(),
      token: HistoryToken(scope: try XCTUnwrap(history.session?.configuration?.scope),
        generation: UUID(), sequence: 1, command: UUID()), in: fixture.base.scope)
    _ = try fixture.sessions.perform(.progress(.init(id: .init(), sessionID: fixture.id, authoredAt: Date()),
      fixture.completed))
    XCTAssertThrowsError(try fixture.base.repository.acceptHistory(frozen))
    assertOrganizationHistoryAccepted(try await history.outcome(fixture.id, to: .coarse(.okay)))
    _ = try fixture.sessions.perform(.replaceWorkingScale(.init(id: .init(), sessionID: fixture.id, authoredAt: Date()),
      SessionWorkingScale(exactScale: RationalQuantity(numerator: 2))))
    _ = await history.reconcile()
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    await history.close()
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    XCTAssertEqual(try fixture.session().outcome, .coarse(.okay))
    await history.close()
  }

  func testReceiptRecoveryAfterRemoteFinishDoesNotReplayOrResurrectOutcomeHistory() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let boundary = ControlledHistoryRepository(fixture.base.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    boundary.loseNextReply = true
    boundary.withholdReceipts = true
    _ = try await history.outcome(fixture.id, to: .coarse(.great))
    _ = try fixture.sessions.perform(.finish(.init(closureID: .init(), sessionID: fixture.id,
      finishedAt: Date(), hasMeaningfulDraft: false)))
    await history.close()
    boundary.withholdReceipts = false
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    XCTAssertEqual(boundary.deliveries.count, 1)
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 1)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    XCTAssertEqual(try fixture.session().lifecycle, .finished)
    XCTAssertEqual(try fixture.session().outcome, .coarse(.great))
    await history.close()
  }
}
