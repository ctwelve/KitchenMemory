// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class AmbiguousStartService: CookingSessionServing {
  let accepted: CookingSessionProjection
  private(set) var results: [SessionProjectionResult] = []
  private(set) var attemptedSessionIDs: [CookingSession.ID] = []
  private var recipeIDBySessionID: [CookingSession.ID: Recipe.ID] = [:]

  init(accepted: CookingSessionProjection) {
    self.accepted = accepted
  }

  func sessions() throws -> [SessionProjectionResult] { results }

  func history() throws -> CookingSessionHistoryRead {
    var associations: [Recipe.ID: Set<CookingSession.ID>] = [:]
    for (sessionID, recipeID) in recipeIDBySessionID {
      associations[recipeID, default: []].insert(sessionID)
    }
    return fixtureHistoryRead(sessions: results, sessionIDsByRecipe: associations)
  }

  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    let ids = Set(recipeIDBySessionID.compactMap { $0.value == recipeID ? $0.key : nil })
    return results.filter { result in
      guard case let .session(session) = result else { return false }
      return ids.contains(session.id)
    }
  }

  func unresolvedDeletionIDs(for sessionID: CookingSession.ID) throws -> [SessionDeletion.ID] {
    _ = sessionID
    throw CookingSessionTestSupportError.unsupportedRead("unresolvedDeletionIDs(for:)")
  }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    attemptedSessionIDs.append(intention.sessionID)
    guard attemptedSessionIDs.count > 1 else {
      throw CookingSessionLogicError.sessionWriteFailed
    }
    let session = CookingSessionProjection(
      id: intention.sessionID,
      snapshot: accepted.snapshot
    )
    results = [.session(session)]
    recipeIDBySessionID[intention.sessionID] = intention.recipeID
    return .accepted(session)
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    XCTFail("Unexpected non-Start intention: \(intention)")
    return .accepted(accepted)
  }
}

@MainActor
final class ClassifiedSessionService: CookingSessionServing {
  var results: [SessionProjectionResult]

  init(results: [SessionProjectionResult]) {
    self.results = results
  }

  func sessions() throws -> [SessionProjectionResult] { results }

  func history() throws -> CookingSessionHistoryRead {
    fixtureHistoryRead(sessions: results, sessionIDsByRecipe: [:])
  }

  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    _ = recipeID
    throw CookingSessionTestSupportError.unsupportedRead("sessions(for:)")
  }

  func unresolvedDeletionIDs(for sessionID: CookingSession.ID) throws -> [SessionDeletion.ID] {
    _ = sessionID
    throw CookingSessionTestSupportError.unsupportedRead("unresolvedDeletionIDs(for:)")
  }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }
}

@MainActor
final class AttentionStartService: CookingSessionServing {
  private(set) var attemptedSessionIDs: [CookingSession.ID] = []

  func sessions() throws -> [SessionProjectionResult] { [] }

  func history() throws -> CookingSessionHistoryRead {
    fixtureHistoryRead(sessions: [], sessionIDsByRecipe: [:])
  }

  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    _ = recipeID
    throw CookingSessionTestSupportError.unsupportedRead("sessions(for:)")
  }

  func unresolvedDeletionIDs(for sessionID: CookingSession.ID) throws -> [SessionDeletion.ID] {
    _ = sessionID
    throw CookingSessionTestSupportError.unsupportedRead("unresolvedDeletionIDs(for:)")
  }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    attemptedSessionIDs.append(intention.sessionID)
    return .attention(.commandNotAllowed(lifecycle: .active))
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }
}
