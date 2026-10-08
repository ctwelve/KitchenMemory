// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class CookingSessionHistoryRefreshTests: XCTestCase {
  func testFailedRefreshPreservesPriorHistoryAndRetryReplacesIt() {
    let service = HistoryReadProbe()
    let model = CookingSessionPresentationModel(
      sessions: service, store: VolatileCookingSessionPresentationStore()
    )
    model.loadIfNeeded()
    XCTAssertTrue(model.showRecipeSessionHistory(for: service.recipeID))
    service.includesSession = false
    service.failsHistoryRead = true
    model.reloadAfterExternalStoreChange()

    XCTAssertEqual(model.displayedHistorySessions.map(\.id), [service.session.id])
    XCTAssertEqual(model.sidebarSessions(for: service.recipeID).map(\.id), [service.session.id])
    XCTAssertEqual(model.issue, .read)

    service.failsHistoryRead = false
    model.retryCurrentIssue()
    XCTAssertTrue(model.displayedHistorySessions.isEmpty)
    XCTAssertTrue(model.sidebarSessions(for: service.recipeID).isEmpty)
    XCTAssertNil(model.issue)
    XCTAssertEqual(service.historyReads, 3)
  }

  func testOneRefreshSuppliesRecipeHistoryAndAnyNumberOfSidebarAssociations() throws {
    let service = HistoryReadProbe()
    let model = CookingSessionPresentationModel(
      sessions: service, store: VolatileCookingSessionPresentationStore()
    )
    model.reload()
    let recipes = [service.recipeID] + (0..<20).map { _ in Recipe.ID() }
    model.refreshSidebarAssociations(for: recipes)
    XCTAssertTrue(model.showRecipeSessionHistory(for: service.recipeID))
    model.refreshSidebarAssociations(for: Array(recipes.reversed()))

    XCTAssertEqual(model.displayedHistorySessions.map(\.id), [service.session.id])
    XCTAssertEqual(model.sidebarSessions(for: service.recipeID).map(\.id), [service.session.id])
    XCTAssertEqual(service.historyReads, 1)
    XCTAssertEqual(service.allReads, 0)
    XCTAssertEqual(service.finishedReads, 0)
    XCTAssertEqual(service.recipeReads, 0)
  }
}

@MainActor
private final class HistoryReadProbe: CookingSessionServing {
  let recipeID = Recipe.ID()
  let session = CookingSessionProjection(id: CookingSession.ID(), snapshot: ExecutionSnapshot(title: "Soup"))
  var historyReads = 0
  var allReads = 0
  var finishedReads = 0
  var recipeReads = 0
  var includesSession = true
  var failsHistoryRead = false

  func history() throws -> CookingSessionHistoryRead {
    historyReads += 1
    if failsHistoryRead { throw CookingSessionLogicError.sessionReadFailed }
    return CookingSessionHistoryRead(
      sessions: includesSession ? [.session(session)] : [], finishedSessions: [],
      sessionIDsByRecipe: includesSession ? [recipeID: [session.id]] : [:]
    )
  }

  func sessions() throws -> [SessionProjectionResult] {
    allReads += 1
    return [.session(session)]
  }

  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    recipeReads += 1
    return recipeID == self.recipeID ? [.session(session)] : []
  }

  func finishedSessions(limit: Int) throws -> [SessionProjectionResult] {
    finishedReads += 1
    return []
  }

  func unresolvedDeletionIDs(for sessionID: CookingSession.ID) throws -> [SessionDeletion.ID] {
    throw CookingSessionLogicError.invalidIntention
  }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }
}
