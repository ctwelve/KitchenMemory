// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit

func recoveryClosureEvidence(
  sessionID: CookingSession.ID,
  finishedAt: TimeInterval
) -> SessionClosureEvidence {
  SessionClosureEvidence(
    id: SessionClosure.ID(),
    sessionID: sessionID,
    kitchenID: Kitchen.ID(),
    finishedAt: Date(timeIntervalSince1970: finishedAt),
    causalHeadsFormatVersion: 1,
    causalHeadsData: Data(),
    snapshotFormatVersion: 1,
    snapshotDigest: Data(),
    projectionFormatVersion: 1,
    projectionDigest: Data(),
    outcomeFormatVersion: nil,
    outcomeData: nil
  )
}

@MainActor
final class ClosureInterruptionSessionService: CookingSessionServing {
  var results: [SessionProjectionResult]
  var commandResults: [CookingSessionCommandResult]
  var observedCandidateSets: [[SessionClosure.ID]] = []

  init(
    results: [SessionProjectionResult],
    commandResults: [CookingSessionCommandResult]
  ) {
    self.results = results
    self.commandResults = commandResults
  }

  func sessions() throws -> [SessionProjectionResult] { results }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    _ = intention
    throw CookingSessionLogicError.invalidIntention
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    guard case let .resolveClosure(selection) = intention, !commandResults.isEmpty else {
      throw CookingSessionLogicError.invalidIntention
    }
    observedCandidateSets.append(selection.observedClosureIDs)
    return commandResults.removeFirst()
  }
}
