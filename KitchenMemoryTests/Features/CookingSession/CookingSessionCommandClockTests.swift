// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class CookingSessionCommandClockTests: XCTestCase {
  func testStartingSessionUsesInjectedClockForIntentionTimestamp() throws {
    let instant = Date(timeIntervalSince1970: 1_800_000_000)
    let service = CommandClockProbe()
    let model = CookingSessionPresentationModel(
      sessions: service,
      store: VolatileCookingSessionPresentationStore(),
      now: { instant }
    )
    let recipeID = Recipe.ID()
    let revisionID = RecipeRevision.ID()
    let recipe = StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: Kitchen.ID(), currentRevisionID: revisionID),
      revision: RecipeRevision(
        id: revisionID,
        recipeID: recipeID,
        revisionNumber: 1,
        title: "Soup"
      )
    )

    XCTAssertTrue(model.start(from: recipe))
    XCTAssertEqual(service.startedAt, instant)
  }

  func testPendingOutcomeRetryAfterRelaunchKeepsOriginalTimestamp() throws {
    let firstInstant = Date(timeIntervalSince1970: 1_800_000_000)
    let outcomeInstant = Date(timeIntervalSince1970: 1_800_000_100)
    var clock = firstInstant
    let service = CommandClockProbe()
    let store = VolatileCookingSessionPresentationStore()
    let model = CookingSessionPresentationModel(sessions: service, store: store, now: { clock })
    let recipeID = Recipe.ID()
    let revisionID = RecipeRevision.ID()
    let recipe = StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: Kitchen.ID(), currentRevisionID: revisionID),
      revision: RecipeRevision(
        id: revisionID,
        recipeID: recipeID,
        revisionNumber: 1,
        title: "Soup"
      )
    )
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: recipe))

    clock = outcomeInstant
    service.interruptNextOutcome = true
    XCTAssertFalse(model.setOutcome(.coarse(.great)))
    XCTAssertEqual(service.outcomeTimestamps, [outcomeInstant])

    clock = Date(timeIntervalSince1970: 1_800_000_200)
    let relaunched = CookingSessionPresentationModel(sessions: service, store: store, now: { clock })
    relaunched.loadIfNeeded()

    XCTAssertEqual(service.outcomeTimestamps, [outcomeInstant, outcomeInstant])
    XCTAssertTrue(relaunched.pendingCommands.isEmpty)
  }
}

@MainActor
private final class CommandClockProbe: CookingSessionServing {
  private(set) var startedAt: Date?
  private(set) var outcomeTimestamps: [Date] = []
  private(set) var projection: CookingSessionProjection?
  private(set) var recipeIDBySessionID: [CookingSession.ID: Recipe.ID] = [:]
  var interruptNextOutcome = false

  func history() throws -> CookingSessionHistoryRead {
    var sessionIDsByRecipe: [Recipe.ID: Set<CookingSession.ID>] = [:]
    for (sessionID, recipeID) in recipeIDBySessionID {
      sessionIDsByRecipe[recipeID, default: []].insert(sessionID)
    }
    return fixtureHistoryRead(
      sessions: try sessions(),
      sessionIDsByRecipe: sessionIDsByRecipe
    )
  }

  func sessions() throws -> [SessionProjectionResult] {
    projection.map { [.session($0)] } ?? []
  }

  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    guard let projection, recipeIDBySessionID[projection.id] == recipeID else { return [] }
    return [.session(projection)]
  }

  func unresolvedDeletionIDs(for sessionID: CookingSession.ID) throws -> [SessionDeletion.ID] {
    _ = sessionID
    return []
  }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    startedAt = intention.startedAt
    let started = CookingSessionProjection(
      id: intention.sessionID,
      snapshot: ExecutionSnapshot(title: "Soup")
    )
    projection = started
    recipeIDBySessionID[intention.sessionID] = intention.recipeID
    return .accepted(started)
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    if case let .setOutcome(fact, _) = intention {
      outcomeTimestamps.append(fact.authoredAt)
      if interruptNextOutcome {
        interruptNextOutcome = false
        throw CookingSessionLogicError.sessionWriteFailed
      }
      return .accepted(try XCTUnwrap(projection))
    }
    XCTFail("Unexpected command: \(intention)")
    throw CookingSessionLogicError.invalidIntention
  }
}
