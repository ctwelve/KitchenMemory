// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

enum CookingSessionTestSupportError: Error {
  case unsupportedRead(String)
}

func fixtureHistoryRead(
  sessions: [SessionProjectionResult],
  sessionIDsByRecipe: [Recipe.ID: Set<CookingSession.ID>]
) -> CookingSessionHistoryRead {
  let finishedSessions = sessions.filter { result in
    guard case let .session(session) = result else { return false }
    return session.lifecycle == .finished
  }
  return CookingSessionHistoryRead(
    sessions: sessions,
    finishedSessions: finishedSessions,
    sessionIDsByRecipe: sessionIDsByRecipe
  )
}
