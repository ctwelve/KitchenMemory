// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Both adapters assemble the same read semantics from already-classified evidence.
func cookingSessionHistoryRead(
  in kitchenID: Kitchen.ID,
  from entries: [(evidence: SessionEvidence, projection: SessionProjectionResult)]
) -> CookingSessionHistoryRead {
  let ordered = entries.sorted {
    $0.evidence.sessionID.rawValue.uuidString < $1.evidence.sessionID.rawValue.uuidString
  }
  var associations: [Recipe.ID: Set<CookingSession.ID>] = [:]
  var finished: [FinishedHistoryClassification] = []
  for entry in ordered {
    for root in entry.evidence.roots where root.kitchenID == kitchenID {
      associations[root.recipeID, default: []].insert(entry.evidence.sessionID)
    }
    if let date = entry.evidence.closures.map(\.finishedAt).max() {
      finished.append(FinishedHistoryClassification(
        id: entry.evidence.sessionID, date: date, projection: entry.projection
      ))
    }
  }
  finished.sort {
    if $0.date != $1.date { return $0.date > $1.date }
    return $0.id.rawValue.uuidString < $1.id.rawValue.uuidString
  }
  return CookingSessionHistoryRead(
    sessions: ordered.map(\.projection),
    finishedSessions: finished.map(\.projection),
    sessionIDsByRecipe: associations
  )
}

private struct FinishedHistoryClassification {
  let id: CookingSession.ID
  let date: Date
  let projection: SessionProjectionResult
}
