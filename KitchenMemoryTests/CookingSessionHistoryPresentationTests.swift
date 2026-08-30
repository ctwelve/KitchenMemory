// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

@MainActor
final class CookingSessionHistoryPresentationTests: XCTestCase {
  func testHistoryIncludesCurrentWorkAndFinishedObservation() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)

    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let activeID = try XCTUnwrap(preparedApp.sessionModel.currentSessionID)
    XCTAssertTrue(preparedApp.sessionModel.leaveCurrentSession())
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let finishedID = try XCTUnwrap(preparedApp.sessionModel.currentSessionID)
    XCTAssertTrue(preparedApp.sessionModel.finishCurrentSession())

    preparedApp.sessionModel.showSessionHistory()

    XCTAssertEqual(
      Set(preparedApp.sessionModel.displayedHistorySessions.map(\.id)),
      Set([activeID, finishedID])
    )
    XCTAssertTrue(preparedApp.sessionModel.observeFinishedSession(finishedID))
    XCTAssertEqual(preparedApp.sessionModel.observedFinishedSession?.id, finishedID)
    XCTAssertEqual(preparedApp.sessionModel.observedFinishedSession?.lifecycle, .finished)
  }

  func testRecipeContextHistoryUsesSessionProvenanceWithoutRecipeRuntimeDependency() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipes = preparedApp.libraryModel.recipes
    let first = try XCTUnwrap(recipes.first)
    let second = try XCTUnwrap(recipes.dropFirst().first)

    XCTAssertTrue(preparedApp.sessionModel.start(from: first))
    let firstID = try XCTUnwrap(preparedApp.sessionModel.currentSessionID)
    XCTAssertTrue(preparedApp.sessionModel.leaveCurrentSession())
    XCTAssertTrue(preparedApp.sessionModel.start(from: second))
    let secondID = try XCTUnwrap(preparedApp.sessionModel.currentSessionID)
    XCTAssertTrue(preparedApp.sessionModel.leaveCurrentSession())

    preparedApp.sessionModel.showRecipeSessionHistory(for: first.recipe.id)

    XCTAssertEqual(preparedApp.sessionModel.displayedHistorySessions.map(\.id), [firstID])
    XCTAssertFalse(preparedApp.sessionModel.displayedHistorySessions.contains { $0.id == secondID })
  }

  func testRecentHistoryIsVisitOrderedAndBounded() {
    let sessions = (0...6).map { index in
      CookingSessionProjection(
        id: CookingSession.ID(),
        snapshot: ExecutionSnapshot(title: "Session \(index)")
      )
    }
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let service = HistorySessionService(results: sessions.map(SessionProjectionResult.session))
    let store = VolatileCookingSessionPresentationStore()
    store.sessionVisits = sessions.enumerated().map { index, session in
      CookingSessionVisit(
        sessionID: session.id,
        lastVisitedAt: now.addingTimeInterval(TimeInterval(index)),
        dismissedStaleNudge: false
      )
    }
    let model = CookingSessionPresentationModel(sessions: service, store: store, now: { now })
    model.loadIfNeeded()

    let current = sessions[6]
    XCTAssertEqual(model.currentHistorySession?.id, current.id)
    XCTAssertEqual(
      model.recentHistorySessions(from: model.sessions, excluding: current.id).map(\.id),
      sessions[1...5].reversed().map(\.id)
    )
  }

  func testFinishedContinuationCreatesNewActiveRootAndLeavesSourceImmutable() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)

    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let sourceID = try XCTUnwrap(preparedApp.sessionModel.currentSessionID)
    let sourceIngredientID = try XCTUnwrap(
      preparedApp.sessionModel.currentSession?.snapshot.ingredientSections.first?.ingredients.first?.id
    )
    XCTAssertTrue(preparedApp.sessionModel.setIngredient(sourceIngredientID, to: .accounted))
    XCTAssertTrue(preparedApp.sessionModel.setOutcome(.coarse(.great)))
    XCTAssertTrue(preparedApp.sessionModel.finishCurrentSession())
    let source = try XCTUnwrap(preparedApp.sessionModel.observedFinishedSession)
    let sourceClosureID = try XCTUnwrap(source.selectedClosureID)

    XCTAssertTrue(preparedApp.sessionModel.continueSession(sourceID))

    let continuation = try XCTUnwrap(preparedApp.sessionModel.currentSession)
    XCTAssertNotEqual(continuation.id, sourceID)
    XCTAssertEqual(continuation.lifecycle, .active)
    XCTAssertEqual(continuation.sourceSessionID, sourceID)
    XCTAssertEqual(continuation.sourceClosureID, sourceClosureID)
    XCTAssertNil(continuation.outcome)
    XCTAssertEqual(continuation.progress.first?.state, .ingredient(.accounted))
    XCTAssertNotEqual(
      continuation.snapshot.ingredientSections.first?.ingredients.first?.id,
      sourceIngredientID
    )
    guard case let .session(reloadedSource)? = try preparedApp.cookingSessions.session(id: sourceID)
    else {
      XCTFail("Expected the immutable Finished source")
      return
    }
    XCTAssertEqual(reloadedSource, source)
  }

  func testStaleNudgeUsesOnlyDeviceLocalVisitAndDismissalState() {
    let now = Date(timeIntervalSince1970: 2_000_000_000)
    let session = CookingSessionProjection(
      id: CookingSession.ID(),
      snapshot: ExecutionSnapshot(title: "Soup")
    )
    let service = HistorySessionService(results: [.session(session)])
    let store = VolatileCookingSessionPresentationStore()
    store.currentSessionID = session.id
    store.sessionVisits = [
      CookingSessionVisit(
        sessionID: session.id,
        lastVisitedAt: now.addingTimeInterval(-CookingSessionPresentationModel.staleSessionInterval),
        dismissedStaleNudge: false
      ),
    ]
    let model = CookingSessionPresentationModel(sessions: service, store: store, now: { now })
    model.loadIfNeeded()

    XCTAssertTrue(model.currentSessionNeedsStaleNudge)
    XCTAssertEqual(model.currentSession?.lifecycle, .active)

    model.dismissStaleSessionNudge()

    XCTAssertFalse(model.currentSessionNeedsStaleNudge)
    XCTAssertEqual(store.sessionVisits.first?.dismissedStaleNudge, true)
    XCTAssertEqual(service.results, [.session(session)])
  }
}

@MainActor
private final class HistorySessionService: CookingSessionServing {
  var results: [SessionProjectionResult]

  init(results: [SessionProjectionResult]) {
    self.results = results
  }

  func sessions() throws -> [SessionProjectionResult] { results }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    _ = intention
    throw CookingSessionLogicError.invalidIntention
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    _ = intention
    throw CookingSessionLogicError.invalidIntention
  }
}
