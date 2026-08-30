// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

@MainActor
final class CookingSessionRecoveryPresentationTests: XCTestCase {
  func testDeleteAndRestorePreserveEachSessionLifecycle() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)

    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let activeID = try XCTUnwrap(preparedApp.sessionModel.currentSessionID)
    XCTAssertTrue(preparedApp.sessionModel.deleteSession(activeID))
    XCTAssertEqual(preparedApp.sessionModel.deletedSessions.first?.lifecycle, .active)
    XCTAssertNil(preparedApp.sessionModel.currentSession)
    XCTAssertTrue(preparedApp.sessionModel.restoreSession(activeID))
    XCTAssertEqual(preparedApp.sessionModel.sessions.first?.lifecycle, .active)

    XCTAssertTrue(preparedApp.sessionModel.selectSession(activeID))
    XCTAssertTrue(preparedApp.sessionModel.stopCurrentSession())
    XCTAssertTrue(preparedApp.sessionModel.deleteSession(activeID))
    XCTAssertEqual(preparedApp.sessionModel.deletedSessions.first?.lifecycle, .stopped)
    XCTAssertTrue(preparedApp.sessionModel.restoreSession(activeID))

    XCTAssertTrue(preparedApp.sessionModel.selectSession(activeID))
    XCTAssertTrue(preparedApp.sessionModel.finishCurrentSession())
    XCTAssertTrue(preparedApp.sessionModel.deleteSession(activeID))
    XCTAssertEqual(preparedApp.sessionModel.deletedSessions.first?.lifecycle, .finished)
    XCTAssertTrue(preparedApp.sessionModel.restoreSession(activeID))
    XCTAssertEqual(preparedApp.sessionModel.finishedSessions.first?.lifecycle, .finished)
  }

  func testDeletingFinishedSourceDoesNotCascadeIntoContinuation() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)

    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let sourceID = try XCTUnwrap(preparedApp.sessionModel.currentSessionID)
    XCTAssertTrue(preparedApp.sessionModel.finishCurrentSession())
    XCTAssertTrue(preparedApp.sessionModel.continueSession(sourceID))
    let continuationID = try XCTUnwrap(preparedApp.sessionModel.currentSessionID)

    XCTAssertEqual(preparedApp.sessionModel.knownDescendantCount(of: sourceID), 1)
    XCTAssertTrue(preparedApp.sessionModel.deleteSession(sourceID))

    XCTAssertEqual(preparedApp.sessionModel.currentSessionID, continuationID)
    XCTAssertEqual(preparedApp.sessionModel.currentSession?.sourceSessionID, sourceID)
    XCTAssertEqual(preparedApp.sessionModel.deletedSessions.map(\.id), [sourceID])
  }

  func testClassificationKeepsDeletedWaitingAndRecoverySeparate() {
    let deletedID = CookingSession.ID()
    let deletion = SessionDeletionEvidence(
      id: SessionDeletion.ID(),
      sessionID: deletedID,
      kitchenID: Kitchen.ID(),
      deletedAt: Date(timeIntervalSince1970: 10),
      sessionHeadsFormatVersion: 1,
      sessionHeadsData: Data(),
      dispositionHeadsFormatVersion: 1,
      dispositionHeadsData: Data()
    )
    let waitingDeleted = UnavailableSession(
      evidence: SessionEvidence(sessionID: deletedID, deletions: [deletion]),
      reasons: [.missingRoot]
    )
    let waiting = UnavailableSession(
      evidence: SessionEvidence(sessionID: CookingSession.ID()),
      reasons: [.missingRoot]
    )
    let recovery = SessionRecovery(
      evidence: SessionEvidence(sessionID: CookingSession.ID()),
      reasons: [.rootCollision]
    )
    let service = RecoverySessionService(results: [
      .unavailable(waitingDeleted), .unavailable(waiting), .recovery(recovery),
    ])
    let model = CookingSessionPresentationModel(
      sessions: service,
      store: VolatileCookingSessionPresentationStore()
    )

    model.loadIfNeeded()

    XCTAssertEqual(model.waitingDeletedSessions, [waitingDeleted])
    XCTAssertEqual(model.waitingSessions, [waiting])
    XCTAssertEqual(model.recoverySessions, [recovery])
    XCTAssertEqual(model.deletedItemCount, 1)
    XCTAssertEqual(model.recoveryItemCount, 2)
  }

  func testClosureChoicesRequireCompetingClosuresAndCoalesceExactRetries() {
    let model = CookingSessionPresentationModel(
      sessions: RecoverySessionService(results: []),
      store: VolatileCookingSessionPresentationStore()
    )
    let sessionID = CookingSession.ID()
    let first = closure(sessionID: sessionID, finishedAt: 20)
    let second = closure(sessionID: sessionID, finishedAt: 10)
    let evidence = SessionEvidence(
      sessionID: sessionID,
      closures: [first, second, first]
    )
    let competing = SessionRecovery(evidence: evidence, reasons: [.competingClosures])
    let malformed = SessionRecovery(evidence: evidence, reasons: [.malformedSnapshot])

    XCTAssertEqual(model.closureCandidates(for: competing).map(\.id), [second.id, first.id])
    XCTAssertTrue(model.closureCandidates(for: malformed).isEmpty)
  }

  func testRelaunchedRestoreRetiresStaleFrontierAndRequiresFreshConfirmation() throws {
    let sessionID = CookingSession.ID()
    let originalDeletionID = SessionDeletion.ID()
    let concurrentDeletionID = SessionDeletion.ID()
    let service = RestoreInterruptionSessionService(
      results: [
        .session(projection(
          id: sessionID,
          disposition: .deleted(needsAttention: true),
        )),
      ],
      unresolvedDeletionIDs: [originalDeletionID, concurrentDeletionID],
      commandResults: [
        .attention(.competingDeletions([originalDeletionID, concurrentDeletionID])),
        .accepted(projection(id: sessionID, disposition: .ordinary)),
      ]
    )
    let store = VolatileCookingSessionPresentationStore()
    store.pendingCommands = [
      .restore(
        commandID: RestoreCookingSessionIntention.ID(),
        sessionID: sessionID,
        restoredAt: Date(timeIntervalSince1970: 100),
        observedDeletionIDs: [originalDeletionID],
      ),
    ]
    let relaunched = CookingSessionPresentationModel(sessions: service, store: store)

    relaunched.loadIfNeeded()

    XCTAssertTrue(store.pendingCommands.isEmpty)
    XCTAssertEqual(relaunched.deletedSessions.map(\.id), [sessionID])
    XCTAssertEqual(
      relaunched.deletedSessions.first?.disposition,
      .deleted(needsAttention: true),
    )
    XCTAssertTrue(relaunched.restoreSession(sessionID))
    XCTAssertEqual(service.restoreFrontiers.count, 2)
    XCTAssertEqual(service.restoreFrontiers[0], [originalDeletionID])
    XCTAssertEqual(
      Set(service.restoreFrontiers[1]),
      Set([originalDeletionID, concurrentDeletionID]),
    )
    XCTAssertTrue(store.pendingCommands.isEmpty)
  }

  func testRelaunchedRestoreRetiresWhenAnotherReplicaAlreadyRestored() {
    let sessionID = CookingSession.ID()
    let deletionID = SessionDeletion.ID()
    let service = RestoreInterruptionSessionService(
      results: [.session(projection(id: sessionID, disposition: .ordinary))],
      unresolvedDeletionIDs: [],
      commandResults: [.attention(.restoreNotNeeded)]
    )
    let store = VolatileCookingSessionPresentationStore()
    store.pendingCommands = [
      .restore(
        commandID: RestoreCookingSessionIntention.ID(),
        sessionID: sessionID,
        restoredAt: Date(timeIntervalSince1970: 100),
        observedDeletionIDs: [deletionID],
      ),
    ]
    let relaunched = CookingSessionPresentationModel(sessions: service, store: store)

    relaunched.loadIfNeeded()

    XCTAssertTrue(store.pendingCommands.isEmpty)
    XCTAssertNil(relaunched.issue)
    XCTAssertEqual(relaunched.sessions.map(\.id), [sessionID])
    XCTAssertTrue(relaunched.deletedSessions.isEmpty)
  }

  func testRelaunchedClosureSelectionRetiresStaleCandidatesAndRequiresFreshChoice() throws {
    let sessionID = CookingSession.ID()
    let first = closure(sessionID: sessionID, finishedAt: 10)
    let second = closure(sessionID: sessionID, finishedAt: 20)
    let third = closure(sessionID: sessionID, finishedAt: 30)
    let updatedRecovery = SessionRecovery(
      evidence: SessionEvidence(sessionID: sessionID, closures: [first, second, third]),
      reasons: [.competingClosures]
    )
    let service = ClosureInterruptionSessionService(
      results: [.recovery(updatedRecovery)],
      commandResults: [
        .attention(.recovery(updatedRecovery)),
        .accepted(projection(id: sessionID, disposition: .ordinary)),
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
    let visibleRecovery = try XCTUnwrap(relaunched.recoverySessions.first)
    XCTAssertEqual(visibleRecovery.evidence.closures, [first, second, third])
    XCTAssertTrue(relaunched.selectClosure(third.id, for: visibleRecovery))
    XCTAssertEqual(service.observedCandidateSets.count, 2)
    XCTAssertEqual(service.observedCandidateSets[0], [first.id, second.id])
    XCTAssertEqual(
      Set(service.observedCandidateSets[1]),
      Set([first.id, second.id, third.id]),
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

  private func projection(
    id: CookingSession.ID,
    disposition: SessionDisposition
  ) -> CookingSessionProjection {
    CookingSessionProjection(
      id: id,
      snapshot: ExecutionSnapshot(title: "Soup"),
      disposition: disposition
    )
  }
}

@MainActor
private final class RecoverySessionService: CookingSessionServing {
  let results: [SessionProjectionResult]

  init(results: [SessionProjectionResult]) {
    self.results = results
  }

  func sessions() throws -> [SessionProjectionResult] { results }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    _ = intention
    throw CookingSessionLogicError.invalidIntention
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    _ = intention
    throw CookingSessionLogicError.invalidIntention
  }
}

@MainActor
private final class RestoreInterruptionSessionService: CookingSessionServing {
  let results: [SessionProjectionResult]
  let unresolved: [SessionDeletion.ID]
  var commandResults: [CookingSessionCommandResult]
  var restoreFrontiers: [[SessionDeletion.ID]] = []

  init(
    results: [SessionProjectionResult],
    unresolvedDeletionIDs: [SessionDeletion.ID],
    commandResults: [CookingSessionCommandResult]
  ) {
    self.results = results
    unresolved = unresolvedDeletionIDs
    self.commandResults = commandResults
  }

  func sessions() throws -> [SessionProjectionResult] { results }

  func unresolvedDeletionIDs(
    for sessionID: CookingSession.ID
  ) throws -> [SessionDeletion.ID] {
    _ = sessionID
    return unresolved
  }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    _ = intention
    throw CookingSessionLogicError.invalidIntention
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    guard case let .restore(restore) = intention, !commandResults.isEmpty else {
      throw CookingSessionLogicError.invalidIntention
    }
    restoreFrontiers.append(restore.observedDeletionIDs)
    return commandResults.removeFirst()
  }
}

@MainActor
private final class ClosureInterruptionSessionService: CookingSessionServing {
  let results: [SessionProjectionResult]
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
