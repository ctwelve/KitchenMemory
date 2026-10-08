// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

@MainActor
protocol CookingSessionServing {
  func sessions() throws -> [SessionProjectionResult]
  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult]
  func finishedSessions(limit: Int) throws -> [SessionProjectionResult]
  func unresolvedDeletionIDs(for sessionID: CookingSession.ID) throws -> [SessionDeletion.ID]
  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult
  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult
}

@MainActor
extension CookingSessions: CookingSessionServing {}

@MainActor
extension CookingSessionServing {
  func unresolvedDeletionIDs(for sessionID: CookingSession.ID) throws -> [SessionDeletion.ID] {
    _ = sessionID
    return []
  }
  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    _ = recipeID
    return []
  }

  func finishedSessions(limit: Int) throws -> [SessionProjectionResult] {
    guard limit > 0 else { return [] }
    return Array(try sessions().filter { result in
      guard case let .session(session) = result else { return false }
      return session.lifecycle == .finished
    }.prefix(limit))
  }
}
