// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
@testable import KitchenMemory

@MainActor
final class NavigationRetryService: CookingSessionServing {
  let base: any CookingSessionServing
  var refusesStart = false
  var refusesFinish = false
  var refusesContinuation = false
  init(base: any CookingSessionServing) { self.base = base }
  func history() throws -> CookingSessionHistoryRead { try base.history() }
  func sessions() throws -> [SessionProjectionResult] { try base.sessions() }
  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    try base.sessions(for: recipeID)
  }
  func finishedSessions(limit: Int) throws -> [SessionProjectionResult] {
    try base.finishedSessions(limit: limit)
  }
  func unresolvedDeletionIDs(for sessionID: CookingSession.ID) throws -> [SessionDeletion.ID] {
    try base.unresolvedDeletionIDs(for: sessionID)
  }
  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    if refusesStart { throw CookingSessionLogicError.sessionWriteFailed }
    return try base.start(intention)
  }
  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    if case .finish = intention, refusesFinish { throw CookingSessionLogicError.sessionWriteFailed }
    if case .continueSession = intention, refusesContinuation { throw CookingSessionLogicError.sessionWriteFailed }
    return try base.perform(intention)
  }
}
