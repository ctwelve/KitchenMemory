// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

@MainActor
final class PartialClosureRecoveryTests: XCTestCase {
  func testRelaunchedSelectionRetiresWhenNewClosureIsIncomplete() throws {
    let sessionID = CookingSession.ID()
    let first = closure(sessionID: sessionID, finishedAt: 10)
    let second = closure(sessionID: sessionID, finishedAt: 20)
    let incomplete = closure(sessionID: sessionID, finishedAt: 30)
    let partialArrival = UnavailableSession(
      evidence: SessionEvidence(sessionID: sessionID, closures: [first, second, incomplete]),
      reasons: [.missingPredecessor(UUID())]
    )
    let completeArrival = SessionRecovery(
      evidence: partialArrival.evidence,
      reasons: [.competingClosures]
    )
    let service = PartialClosureSessionService(
      results: [.unavailable(partialArrival)],
      commandResults: [
        .attention(.unavailable(partialArrival)),
        .accepted(projection(id: sessionID)),
      ]
    )
    let store = VolatileCookingSessionPresentationStore()
    store.pendingCommands = [
      .resolveClosure(
        factID: SessionFact.ID(),
        sessionID: sessionID,
        authoredAt: Date(timeIntervalSince1970: 100),
        selectedClosureID: first.id,
        observedClosureIDs: [first.id, second.id],
      ),
    ]
    let relaunched = CookingSessionPresentationModel(sessions: service, store: store)

    relaunched.loadIfNeeded()

    XCTAssertTrue(store.pendingCommands.isEmpty)
    XCTAssertEqual(relaunched.waitingSessions, [partialArrival])
    XCTAssertTrue(relaunched.recoverySessions.isEmpty)

    service.results = [.recovery(completeArrival)]
    relaunched.reload()

    let visibleRecovery = try XCTUnwrap(relaunched.recoverySessions.first)
    XCTAssertTrue(relaunched.selectClosure(incomplete.id, for: visibleRecovery))
    XCTAssertEqual(service.observedCandidateSets.count, 2)
    XCTAssertEqual(Set(service.observedCandidateSets[0]), Set([first.id, second.id]))
    XCTAssertEqual(
      Set(service.observedCandidateSets[1]),
      Set([first.id, second.id, incomplete.id]),
    )
    XCTAssertTrue(store.pendingCommands.isEmpty)
  }

  private func closure(
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

  private func projection(id: CookingSession.ID) -> CookingSessionProjection {
    CookingSessionProjection(
      id: id,
      snapshot: ExecutionSnapshot(title: "Soup"),
      disposition: .ordinary
    )
  }
}

@MainActor
private final class PartialClosureSessionService: CookingSessionServing {
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
