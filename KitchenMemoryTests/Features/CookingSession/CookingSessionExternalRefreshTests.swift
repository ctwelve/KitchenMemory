// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

@MainActor
final class CookingSessionExternalRefreshTests: XCTestCase {
  func testPreparedAppRefreshesImportedEvidenceThroughTheCompositionRoot() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    let snapshot = try ExecutionSnapshotCodec.encode(
      ExecutionSnapshot(title: "Imported Session")
    )
    let root = CookingSessionRootEvidence(
      id: CookingSession.ID(),
      kitchenID: KitchenBootstrapService.personalKitchenID,
      recipeID: recipe.recipe.id,
      recipeRevisionID: recipe.revision.id,
      startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
      snapshotFormatVersion: snapshot.formatVersion,
      snapshotData: snapshot.data,
      snapshotDigest: snapshot.digest
    )
    let externalWriter = SwiftDataCookingSessionRepository(
      modelContainer: preparedApp.modelContainer
    )
    try externalWriter.append(.start(root))

    XCTAssertTrue(preparedApp.sessionModel.sessions.isEmpty)
    preparedApp.reloadAfterExternalStoreChange()

    XCTAssertEqual(preparedApp.sessionModel.sessions.map(\.id), [root.id])
  }

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
