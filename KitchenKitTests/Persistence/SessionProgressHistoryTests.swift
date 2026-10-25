// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import UndoKit
import XCTest

@MainActor
final class SessionProgressHistoryTests: XCTestCase {
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

  func testMixedProgressFolderOrderingNoOpAndNewActionClearsRedo() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    let open = SessionProgress(target: fixture.completed.target, state: .instruction(.open))
    let noOp = try await history.progress(fixture.id, to: open)
    XCTAssertEqual(noOp, .rejected)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    assertOrganizationHistoryAccepted(try await history.progress(fixture.id, to: fixture.completed))
    assertOrganizationHistoryAccepted(try await history.move([fixture.base.recipeID], to: fixture.base.first))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertNil(try fixture.base.placement())
    XCTAssertEqual(try fixture.progress(), .instruction(.completed))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.progress(), .instruction(.open))
    assertOrganizationHistoryAccepted(await history.redo())
    assertOrganizationHistoryAccepted(try await history.progress(fixture.id,
      to: SessionProgress(target: fixture.completed.target, state: .instruction(.skipped))))
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.progress(), .instruction(.completed))
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

  func testFinishEntryAndOtherFieldChangesRetireHistoryAcrossReopen() async throws {
    for boundary in 0..<5 {
      let fixture = try ProgressHistoryFixture()
      defer { fixture.base.removeFiles() }
      let history = RecipeOrganizationHistory(repository: fixture.base.repository)
      try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
      assertOrganizationHistoryAccepted(try await history.progress(fixture.id, to: fixture.completed))
      let fact = SessionFactIntention(id: .init(), sessionID: fixture.id, authoredAt: Date())
      switch boundary {
      case 0:
        _ = try fixture.sessions.perform(.finish(.init(closureID: .init(), sessionID: fixture.id,
          finishedAt: Date(), hasMeaningfulDraft: false)))
      case 1: _ = try fixture.sessions.perform(.setOutcome(fact, .coarse(.great)))
      default:
        _ = try fixture.sessions.perform(.submitEntry(fact, text: "A note", target: nil))
        let edit = SessionFactIntention(id: .init(), sessionID: fixture.id, authoredAt: Date())
        let entry = SessionEntry.ID(rawValue: fact.id.rawValue)
        if boundary == 2 { _ = try fixture.sessions.perform(.reviseEntry(edit, entryID: entry,
          text: "Revised note", target: nil)) }
        if boundary == 3 { _ = try fixture.sessions.perform(.retargetEntry(edit, entryID: entry,
          target: fixture.completed.target)) }
        if boundary == 4 { _ = try fixture.sessions.perform(.withdrawEntry(edit, entryID: entry)) }
      }
      _ = await history.reconcile()
      XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
      await history.close()
      let reopened = RecipeOrganizationHistory(repository: fixture.base.repository)
      try await reopened.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
      XCTAssertFalse(try XCTUnwrap(reopened.session).status.canUndo)
      XCTAssertFalse(try XCTUnwrap(reopened.session).status.canRedo)
      XCTAssertEqual(try fixture.progress(), .instruction(.completed))
      await reopened.close()
    }
  }

  func testIngredientUndoAndPendingWorkWithholdWithoutRetiringEligibleHistory() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    guard case let .session(session) = try fixture.repository.session(id: fixture.id) else {
      XCTFail("Expected Session")
      return
    }
    let target = SessionProgressTarget.ingredient(session.snapshot.ingredientSections[0].ingredients[0].id)
    var pending = false
    let history = RecipeOrganizationHistory(repository: fixture.base.repository, sessionAdmission: { _ in !pending })
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    assertOrganizationHistoryAccepted(try await history.progress(fixture.id,
      to: SessionProgress(target: target, state: .ingredient(.accounted))))
    pending = true
    XCTAssertTrue(history.sessionDeliveryIsBlocked)
    let refused = await history.undo()
    XCTAssertEqual(refused, .rejected)
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 1)
    pending = false
    assertOrganizationHistoryAccepted(await history.undo())
    guard case let .session(undone) = try fixture.repository.session(id: fixture.id) else {
      XCTFail("Expected Session")
      return
    }
    XCTAssertEqual(undone.progress.first(where: { $0.target == target })?.state, .ingredient(.open))
    await history.close()
  }

  func testStopRetiresInterleavedFolderHistoryAndResumeDoesNotResurrectIt() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    assertOrganizationHistoryAccepted(try await history.progress(fixture.id, to: fixture.completed))
    assertOrganizationHistoryAccepted(try await history.move([fixture.base.recipeID], to: fixture.base.first))
    _ = try fixture.sessions.perform(.stop(.init(id: .init(), sessionID: fixture.id, authoredAt: Date())))
    // A native callback can arrive before the application receives its refresh notification.
    let result = await history.undo()
    XCTAssertEqual(result, .rejected)
    XCTAssertEqual(try fixture.base.placement(), fixture.base.first)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    _ = try fixture.sessions.perform(.resume(.init(id: .init(), sessionID: fixture.id, authoredAt: Date())))
    await history.close()
    let reopened = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await reopened.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    XCTAssertFalse(try XCTUnwrap(reopened.session).status.canUndo)
    await reopened.close()
  }

  func testProgressUndoRestoresSkippedAndRedoAppendsFreshFacts() async throws {
    let fixture = try HistoryFixture(draft: RecipeDraft(title: "Soup", ingredientLines: ["Water"],
      instructionLines: ["Simmer"]))
    defer { fixture.removeFiles() }
    let repository = SwiftDataCookingSessionRepository(modelContainer: fixture.container)
    let sessions = CookingSessions(kitchenID: fixture.kitchenID, recipeRepository: fixture.recipes,
      sessionRepository: repository)
    let recipe = try XCTUnwrap(fixture.recipes.recipe(id: fixture.recipeID))
    let id = CookingSession.ID()
    guard case let .accepted(started) = try sessions.start(StartCookingSessionIntention(sessionID: id,
      recipeID: fixture.recipeID, recipeRevisionID: recipe.revision.id, startedAt: Date())) else {
      XCTFail("Expected an Active Session")
      return
    }
    let target = SessionProgressTarget.instruction(started.snapshot.instructionSections[0].steps[0].id)
    _ = try sessions.perform(.progress(SessionFactIntention(id: .init(), sessionID: id, authoredAt: Date()),
      SessionProgress(target: target, state: .instruction(.skipped))))
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(try await history.progress(id,
      to: SessionProgress(target: target, state: .instruction(.completed))))
    assertOrganizationHistoryAccepted(await history.undo())
    guard case let .session(undone) = try repository.session(id: id) else {
      XCTFail("Expected a readable Session")
      return
    }
    XCTAssertEqual(undone.progress.first(where: { $0.target == target })?.state, .instruction(.skipped))
    assertOrganizationHistoryAccepted(await history.redo())
    guard case let .session(redone) = try repository.session(id: id) else {
      XCTFail("Expected a readable Session")
      return
    }
    XCTAssertEqual(redone.progress.first(where: { $0.target == target })?.state, .instruction(.completed))
    XCTAssertEqual(try repository.evidence(id: id)?.facts.count, 4)
    await history.close()
  }
}

@MainActor
struct ProgressHistoryFixture {
  let base: HistoryFixture
  let repository: SwiftDataCookingSessionRepository
  let sessions: CookingSessions
  let id: CookingSession.ID
  let completed: SessionProgress

  func progress() throws -> SessionProgressState? {
    guard case let .session(session) = try repository.session(id: id) else { return nil }
    return session.progress.first { $0.target == completed.target }?.state
  }

  init() throws {
    base = try HistoryFixture(draft: RecipeDraft(title: "Soup", ingredientLines: ["Water"],
      instructionLines: ["Simmer"]))
    repository = SwiftDataCookingSessionRepository(modelContainer: base.container)
    sessions = CookingSessions(kitchenID: base.kitchenID, recipeRepository: base.recipes, sessionRepository: repository)
    let recipe = try XCTUnwrap(base.recipes.recipe(id: base.recipeID))
    id = CookingSession.ID()
    guard case let .accepted(started) = try sessions.start(StartCookingSessionIntention(sessionID: id,
      recipeID: base.recipeID, recipeRevisionID: recipe.revision.id, startedAt: Date())) else {
      throw NSError(domain: "ProgressHistoryFixture", code: 1)
    }
    completed = SessionProgress(target: .instruction(started.snapshot.instructionSections[0].steps[0].id),
      state: .instruction(.completed))
  }
}
