// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

extension RecipeLibraryNavigationTests {
  func testDelayedDirectRecipeFinishRestoresItsRecipeAndListPosition() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.selectedRecipe)
    let otherRecipe = try XCTUnwrap(app.libraryModel.recipes.first { $0.id != recipe.id })
    let service = NavigationRetryService(base: app.cookingSessions)
    let model = CookingSessionPresentationModel(sessions: service,
      store: VolatileCookingSessionPresentationStore(), navigation: app.libraryModel.navigation)
    model.loadIfNeeded()
    model.navigation.recipeListAnchor = recipe.id
    XCTAssertTrue(model.start(from: recipe))
    service.refusesFinish = true
    XCTAssertFalse(model.finishCurrentSession())
    XCTAssertTrue(model.leaveCurrentSession())
    XCTAssertTrue(model.navigation.selectRecipe(otherRecipe.id))
    model.navigation.recipeListAnchor = otherRecipe.id
    service.refusesFinish = false
    model.retryPendingCommands()
    XCTAssertNotNil(model.observedFinishedSession)
    XCTAssertNil(model.historyScope)
    model.dismissObservedFinishedSession()
    XCTAssertEqual(model.navigation.selectedRecipeID, recipe.id)
    XCTAssertEqual(model.navigation.recipeListAnchor, recipe.id)
  }

  func testDelayedFinishAndContinuationRetainTheSubmittingHistoryAfterNavigation() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.selectedRecipe)
    let service = NavigationRetryService(base: app.cookingSessions)
    let model = CookingSessionPresentationModel(sessions: service,
      store: VolatileCookingSessionPresentationStore(), navigation: app.libraryModel.navigation)
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: recipe))
    let sourceID = try XCTUnwrap(model.currentSessionID)
    XCTAssertTrue(model.showRecipeSessionHistory(for: recipe.id))
    model.navigation.historyListAnchor = sourceID
    XCTAssertTrue(model.selectSessionFromHistory(sourceID))
    service.refusesFinish = true
    XCTAssertFalse(model.finishCurrentSession())
    XCTAssertTrue(model.leaveCurrentSession())
    model.showSessionHistory()
    service.refusesFinish = false
    model.retryPendingCommands()
    XCTAssertEqual(model.navigation.destination, .finished(sourceID, history: .recipe(recipe.id)))
    XCTAssertEqual(model.navigation.historyListAnchor, sourceID)
    service.refusesContinuation = true
    XCTAssertFalse(model.continueSession(sourceID))
    model.showSessionHistory()
    service.refusesContinuation = false
    model.retryPendingCommands()
    XCTAssertNotEqual(model.currentSessionID, sourceID)
    XCTAssertEqual(model.historyScope, .recipe(recipe.id))
    XCTAssertTrue(model.leaveCurrentSession())
    XCTAssertEqual(model.navigation.destination, .history(.recipe(recipe.id)))
    XCTAssertEqual(model.navigation.historyListAnchor, sourceID)
  }

  func testEachHistoryScopeRetainsItsOwnListPosition() {
    let navigation = RecipeLibraryNavigation()
    let recipeID = Recipe.ID(), allAnchor = CookingSession.ID(), recipeAnchor = CookingSession.ID()
    navigation.move(to: .history(.all))
    navigation.historyListAnchor = allAnchor
    navigation.move(to: .history(.recipe(recipeID)))
    XCTAssertNil(navigation.historyListAnchor)
    navigation.historyListAnchor = recipeAnchor
    navigation.move(to: .history(.all))
    XCTAssertEqual(navigation.historyListAnchor, allAnchor)
    navigation.rememberHistoryListAnchor(nil, for: .all)
    XCTAssertEqual(navigation.historyListAnchor, allAnchor)
    navigation.move(to: .history(.recipe(recipeID)))
    XCTAssertEqual(navigation.historyListAnchor, recipeAnchor)
  }

  func testDirectRecipeFinishAndContinuationReturnToTheRecipe() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    app.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.selectedRecipe)
    app.libraryModel.navigation.recipeListAnchor = recipe.id
    XCTAssertTrue(app.sessionModel.start(from: recipe))
    let id = try XCTUnwrap(app.sessionModel.currentSessionID)
    XCTAssertTrue(app.sessionModel.finishCurrentSession())
    XCTAssertNil(app.sessionModel.historyScope)
    app.sessionModel.dismissObservedFinishedSession()
    XCTAssertEqual(app.libraryModel.navigation.destination, .recipe)
    XCTAssertEqual(app.libraryModel.navigation.selectedRecipeID, recipe.id)
    XCTAssertEqual(app.libraryModel.navigation.recipeListAnchor, recipe.id)
    XCTAssertTrue(app.sessionModel.continueSession(id))
    XCTAssertTrue(app.sessionModel.leaveCurrentSession())
    XCTAssertEqual(app.libraryModel.navigation.destination, .recipe)
  }

  func testFinishContinueAndBackPreserveHistoryScopeAndPosition() throws {
    for recipeScoped in [false, true] {
      let app = try AppRuntime.testing()
      app.libraryModel.loadIfNeeded()
      let model = app.sessionModel
      model.loadIfNeeded()
      let recipe = try XCTUnwrap(app.libraryModel.selectedRecipe)
      XCTAssertTrue(model.start(from: recipe))
      let id = try XCTUnwrap(model.currentSessionID)
      let scope: CookingSessionHistoryScope = recipeScoped ? .recipe(recipe.id) : .all
      if recipeScoped {
        XCTAssertTrue(model.showRecipeSessionHistory(for: recipe.id))
      } else {
        model.showSessionHistory()
      }
      model.navigation.historyListAnchor = id
      XCTAssertTrue(model.selectSessionFromHistory(id))
      XCTAssertTrue(model.finishCurrentSession())
      XCTAssertEqual(model.navigation.destination, .finished(id, history: scope))
      XCTAssertEqual(model.navigation.historyListAnchor, id)
      XCTAssertTrue(model.continueSession(id))
      XCTAssertEqual(model.historyScope, scope)
      XCTAssertTrue(model.leaveCurrentSession())
      XCTAssertEqual(model.navigation.destination, .history(scope))
      XCTAssertEqual(model.navigation.historyListAnchor, id)
    }
  }

}

extension CookingSessionHistoryPresentationTests {
  func testDeletedSourceRecipeDoesNotGateHistoryReadingOrContinuation() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    app.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.selectedRecipe)
    XCTAssertTrue(app.sessionModel.start(from: recipe))
    let sourceID = try XCTUnwrap(app.sessionModel.currentSessionID)
    XCTAssertTrue(app.sessionModel.setOutcome(.coarse(.great)))
    XCTAssertTrue(app.sessionModel.finishCurrentSession())
    let source = try XCTUnwrap(app.sessionModel.observedFinishedSession)
    XCTAssertNotNil(source.startedAt)
    app.libraryModel.deleteRecipe(try app.libraryModel.library.prepareDeletion(of: recipe.id))
    XCTAssertFalse(app.libraryModel.recipes.contains { $0.id == recipe.id })
    XCTAssertTrue(app.sessionModel.showRecipeSessionHistory(for: recipe.id))
    XCTAssertEqual(app.sessionModel.displayedHistorySessions, [source])
    XCTAssertTrue(app.sessionModel.observeFinishedSession(sourceID))
    XCTAssertFalse(app.sessionModel.setOutcome(.coarse(.okay)))
    XCTAssertTrue(app.sessionModel.continueSession(sourceID))
    let continuation = try XCTUnwrap(app.sessionModel.currentSession)
    XCTAssertEqual(continuation.sourceSessionID, sourceID)
    XCTAssertEqual(continuation.snapshot.title, source.snapshot.title)
    XCTAssertEqual(app.sessionModel.retainedSession(sourceID), source)
    XCTAssertTrue(app.sessionModel.leaveCurrentSession())
    XCTAssertEqual(app.sessionModel.navigation.destination, .history(.recipe(recipe.id)))
    app.sessionModel.showSessionHistory()
    XCTAssertEqual(Set(app.sessionModel.displayedHistorySessions.map(\.id)), [sourceID, continuation.id])
  }

  func testCompleteHistoryGroupsEveryCookNewestFirstWithinItsLifecycle() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.selectedRecipe)
    var ids: [CookingSession.ID] = []
    for index in 0..<11 {
      let id = CookingSession.ID()
      ids.append(id)
      _ = try app.cookingSessions.start(StartCookingSessionIntention(
        sessionID: id, recipeID: recipe.id, recipeRevisionID: recipe.revision.id,
        startedAt: Date(timeIntervalSince1970: TimeInterval(100 + index))
      ))
      app.sessionModel.reload()
      XCTAssertTrue(app.sessionModel.selectSession(id))
      if index == 7 || index == 8 { XCTAssertTrue(app.sessionModel.stopCurrentSession()) }
      if index == 9 || index == 10 { XCTAssertTrue(app.sessionModel.finishCurrentSession()) }
    }
    app.sessionModel.showSessionHistory()
    XCTAssertEqual(app.sessionModel.displayedHistorySessions.first?.startedAt,
                   Date(timeIntervalSince1970: 106))
    XCTAssertEqual(app.sessionModel.displayedHistorySessions.map(\.id),
                   [ids[6], ids[5], ids[4], ids[3], ids[2], ids[1], ids[0], ids[8], ids[7], ids[10], ids[9]])
    XCTAssertTrue(app.sessionModel.showRecipeSessionHistory(for: recipe.id))
    XCTAssertEqual(app.sessionModel.displayedHistorySessions.map(\.id),
                   [ids[6], ids[5], ids[4], ids[3], ids[2], ids[1], ids[0], ids[8], ids[7], ids[10], ids[9]])
  }

}
