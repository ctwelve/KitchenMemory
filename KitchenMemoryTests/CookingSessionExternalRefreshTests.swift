// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class CookingSessionExternalRefreshTests: XCTestCase {
  func testRefreshReclassifiesOrdinaryDeletedWaitingAndRecoveryEvidence() {
    let ordinary = CookingSessionProjection(
      id: CookingSession.ID(),
      snapshot: ExecutionSnapshot(title: "Ordinary")
    )
    let deleted = CookingSessionProjection(
      id: CookingSession.ID(),
      snapshot: ExecutionSnapshot(title: "Deleted"),
      disposition: .deleted(needsAttention: false)
    )
    let waiting = UnavailableSession(
      evidence: SessionEvidence(sessionID: CookingSession.ID()),
      reasons: [.missingRoot]
    )
    let recovery = SessionRecovery(
      evidence: SessionEvidence(sessionID: CookingSession.ID()),
      reasons: [.rootCollision]
    )
    let service = ExternalRefreshSessionService()
    let model = CookingSessionPresentationModel(
      sessions: service,
      store: VolatileCookingSessionPresentationStore()
    )
    model.loadIfNeeded()
    service.results = [
      .session(ordinary), .session(deleted), .unavailable(waiting), .recovery(recovery),
    ]

    model.reloadAfterExternalStoreChange()

    XCTAssertEqual(model.sessions, [ordinary])
    XCTAssertEqual(model.deletedSessions, [deleted])
    XCTAssertEqual(model.waitingSessions, [waiting])
    XCTAssertEqual(model.recoverySessions, [recovery])
  }
}

@MainActor
private final class ExternalRefreshSessionService: CookingSessionServing {
  var results: [SessionProjectionResult] = []

  func sessions() throws -> [SessionProjectionResult] { results }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }
}
