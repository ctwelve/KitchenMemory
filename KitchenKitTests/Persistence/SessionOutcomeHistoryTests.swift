// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import UndoKit
import XCTest

@MainActor
final class SessionOutcomeHistoryTests: XCTestCase {
  func testSetChangeClearUndoAndRedoRestoreExactOptionalOutcomesWithFreshFacts() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    assertOrganizationHistoryAccepted(try await history.outcome(fixture.id, to: .coarse(.great)))
    assertOrganizationHistoryAccepted(try await history.outcome(fixture.id, to: .coarse(.okay)))
    assertOrganizationHistoryAccepted(try await history.outcome(fixture.id, to: nil))
    XCTAssertNil(try fixture.session().outcome)
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.session().outcome, .coarse(.okay))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.session().outcome, .coarse(.great))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertNil(try fixture.session().outcome)
    for _ in 0..<3 { assertOrganizationHistoryAccepted(await history.redo()) }
    XCTAssertNil(try fixture.session().outcome)
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 9)
    await history.close()
  }

  func testNoOpsPreserveRedoAndOutcomeInterleavesWithScaleProgressFolderAndTags() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    let emptyNoOp = try await history.outcome(fixture.id, to: nil)
    XCTAssertEqual(emptyNoOp, .rejected)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    let original = try fixture.session().workingScale
    let tag = Tag.ID()
    try fixture.base.repository.accept(fixture.base.repository.load(in: fixture.base.kitchenID).prepare(
      tag: .create(id: tag, name: "Dinner")))
    assertOrganizationHistoryAccepted(try await history.progress(fixture.id, to: fixture.completed))
    assertOrganizationHistoryAccepted(try await history.scale(fixture.id,
      to: SessionWorkingScale(exactScale: RationalQuantity(numerator: 2))))
    assertOrganizationHistoryAccepted(try await history.outcome(fixture.id, to: .coarse(.great)))
    assertOrganizationHistoryAccepted(try await history.move([fixture.base.recipeID], to: fixture.base.first))
    assertOrganizationHistoryAccepted(try await history.classify([fixture.base.recipeID], tagID: tag, adding: true))
    assertOrganizationHistoryAccepted(try await history.outcome(fixture.id, to: .coarse(.unsuccessful)))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.session().outcome, .coarse(.great))
    let currentNoOp = try await history.outcome(fixture.id, to: .coarse(.great))
    XCTAssertEqual(currentNoOp, .rejected)
    XCTAssertTrue(try XCTUnwrap(history.session).status.canRedo)
    for _ in 0..<3 { assertOrganizationHistoryAccepted(await history.undo()) }
    XCTAssertNil(try fixture.session().outcome)
    XCTAssertNil(try fixture.base.placement())
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.session().workingScale, original)
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.progress(), .instruction(.open))
    assertOrganizationHistoryAccepted(await history.redo())
    assertOrganizationHistoryAccepted(try await history.outcome(fixture.id, to: .coarse(.okay)))
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    await history.close()
  }

  func testPendingSessionWorkWithholdsOutcomeWithoutCreatingAnotherPendingOwner() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    var pending = false
    let history = RecipeOrganizationHistory(repository: fixture.base.repository, sessionAdmission: { _ in !pending })
    do {
      _ = try await history.outcome(fixture.id, to: .coarse(.great))
      XCTFail("Closed history must refuse")
    } catch { XCTAssertEqual(error as? RecipeOrganizationHistoryError, .notOpen) }
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    pending = true
    do {
      _ = try await history.outcome(fixture.id, to: .coarse(.great))
      XCTFail("Earlier Session work must settle first")
    } catch { XCTAssertEqual(error as? RecipeOrganizationHistoryError, .ineligible) }
    pending = false
    assertOrganizationHistoryAccepted(try await history.outcome(fixture.id, to: .coarse(.great)))
    pending = true
    XCTAssertTrue(history.sessionDeliveryIsBlocked)
    let refused = await history.undo()
    XCTAssertEqual(refused, .rejected)
    pending = false
    assertOrganizationHistoryAccepted(await history.undo())
    pending = true
    let lateCallback = await history.session?.redo()
    XCTAssertEqual(lateCallback, .rejected)
    XCTAssertNil(history.pendingSessionID)
    XCTAssertNil(try fixture.session().outcome)
    await history.close()
  }

  func testStopRetiresInterleavedOutcomeHistoryAndResumeDoesNotResurrectIt() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    assertOrganizationHistoryAccepted(try await history.outcome(fixture.id, to: .coarse(.great)))
    assertOrganizationHistoryAccepted(try await history.scale(fixture.id,
      to: SessionWorkingScale(exactScale: RationalQuantity(numerator: 2))))
    _ = try fixture.sessions.perform(.stop(.init(id: .init(), sessionID: fixture.id, authoredAt: Date())))
    let refused = await history.undo()
    XCTAssertEqual(refused, .rejected)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    _ = try fixture.sessions.perform(.resume(.init(id: .init(), sessionID: fixture.id, authoredAt: Date())))
    await history.close()
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    XCTAssertEqual(try fixture.session().outcome, .coarse(.great))
    await history.close()
  }

}
