// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import UndoKit
import XCTest

@MainActor
final class SessionProgressHistoryRecoveryTests: XCTestCase {
  func testFrozenCompensationCannotCrossFinishDeletionOrRestoration() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    let change = try XCTUnwrap(fixture.base.repository.prepareHistoryProgress(fixture.id,
      to: fixture.completed, in: fixture.base.scope))
    let identity = try XCTUnwrap(history.session?.configuration?.scope)
    _ = try fixture.sessions.perform(.finish(.init(closureID: .init(), sessionID: fixture.id,
      finishedAt: Date(), hasMeaningfulDraft: false)))
    let deletionID = SessionDeletion.ID()
    _ = try fixture.sessions.perform(.delete(.init(deletionID: deletionID, sessionID: fixture.id, deletedAt: Date())))
    _ = try fixture.sessions.perform(.restore(.init(id: .init(), sessionID: fixture.id, restoredAt: Date(),
      observedDeletionIDs: [deletionID])))
    let frozen = try fixture.base.repository.prepareHistoryDelivery(change, memberID: UUID(),
      token: HistoryToken(scope: identity, generation: UUID(), sequence: 1, command: UUID()), in: fixture.base.scope)
    XCTAssertThrowsError(try fixture.base.repository.acceptHistory(frozen))
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 0)
    await history.close()
  }

  func testLateNativeCallbackCannotCreateASecondPendingOwner() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    var ordinaryPending = false
    let history = RecipeOrganizationHistory(repository: fixture.base.repository,
      sessionAdmission: { _ in !ordinaryPending })
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    assertOrganizationHistoryAccepted(try await history.progress(fixture.id, to: fixture.completed))
    ordinaryPending = true
    let result = await history.session?.undo()
    XCTAssertEqual(result, .rejected)
    XCTAssertNil(history.pendingSessionID, "An unadmitted callback must not block the earlier ordinary retry")
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 1)
    await history.close()
  }

  func testPublicPreparationRefusesStaleScopeTargetsAndUnsupportedPayloads() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let repository = fixture.base.repository
    let scope = fixture.base.scope
    let history = RecipeOrganizationHistory(repository: repository)
    try await history.open(scope: scope, historyURL: fixture.base.historyURL)
    let identity = try XCTUnwrap(history.session?.configuration?.scope)
    for target in [SessionProgressTarget.ingredient(.init()), .instruction(.init())] {
      XCTAssertThrowsError(try repository.prepareHistoryProgress(fixture.id,
        to: SessionProgress(target: target, state: .instruction(.completed)), in: scope))
    }
    let change = try XCTUnwrap(repository.prepareHistoryProgress(fixture.id, to: fixture.completed, in: scope))
    XCTAssertThrowsError(try repository.prepareHistoryDelivery(change, memberID: UUID(),
      token: HistoryToken(scope: UUID(), generation: UUID(), sequence: 1, command: UUID()), in: scope))
    var encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(change)) as? [String: Any])
    encoded["version"] = 99
    XCTAssertThrowsError(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self,
      from: JSONSerialization.data(withJSONObject: encoded)))
    encoded["version"] = 4
    var progress = try XCTUnwrap(encoded["sessionProgress"] as? [String: Any])
    progress["sessionID"] = UUID().uuidString
    encoded["sessionProgress"] = progress
    let missing = try JSONDecoder().decode(RecipeOrganizationHistoryChange.self,
      from: JSONSerialization.data(withJSONObject: encoded))
    XCTAssertThrowsError(try repository.prepareHistoryDelivery(missing, memberID: UUID(),
      token: HistoryToken(scope: identity, generation: UUID(), sequence: 1, command: UUID()), in: scope))
    let stale = try repository.prepareHistoryDelivery(change, memberID: UUID(),
      token: HistoryToken(scope: identity, generation: UUID(), sequence: 1, command: UUID()), in: scope)
    _ = try fixture.sessions.perform(.setOutcome(.init(id: .init(), sessionID: fixture.id, authoredAt: Date()),
      .coarse(.okay)))
    XCTAssertThrowsError(try repository.acceptHistory(stale))
    let wrongKind = try XCTUnwrap(repository.prepareHistoryProgress(fixture.id,
      to: SessionProgress(target: fixture.completed.target, state: .ingredient(.accounted)), in: scope))
    let invalid = try repository.prepareHistoryDelivery(wrongKind, memberID: UUID(),
      token: HistoryToken(scope: identity, generation: UUID(), sequence: 1, command: UUID()), in: scope)
    XCTAssertThrowsError(try repository.acceptHistory(invalid))
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 1)
    await history.close()
  }

  func testLostReplyReopensWithoutDuplicateFactsThenExactInverseRetrySettles() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let boundary = ControlledHistoryRepository(fixture.base.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    boundary.loseNextReply = true
    boundary.withholdReceipts = true
    let lost = try await history.progress(fixture.id, to: fixture.completed)
    guard case .unresolved = lost else { XCTFail("Lost reply requires recovery")
      return }
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 1)
    await history.close()
    boundary.withholdReceipts = false
    XCTAssertEqual(try RecipeOrganizationHistory.pendingSessionID(in: fixture.base.scope,
      historyURL: fixture.base.historyURL), fixture.id)
    let reopened = RecipeOrganizationHistory(repository: boundary)
    try await reopened.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    XCTAssertEqual(boundary.deliveries.count, 1)
    boundary.failNextAcceptance = true
    _ = await reopened.undo()
    let frozen = try XCTUnwrap(boundary.deliveries.last)
    XCTAssertTrue(reopened.hasPendingCompensation)
    XCTAssertEqual(reopened.pendingSessionID, fixture.id)
    XCTAssertFalse(try XCTUnwrap(reopened.session).status.canRedo)
    _ = try await reopened.retryPending()
    XCTAssertEqual(boundary.deliveries.last, frozen)
    XCTAssertEqual(try fixture.progress(), .instruction(.open))
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 2)
    XCTAssertTrue(try XCTUnwrap(reopened.session).status.canRedo)
    await reopened.close()
  }

}
