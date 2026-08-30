// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit

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
