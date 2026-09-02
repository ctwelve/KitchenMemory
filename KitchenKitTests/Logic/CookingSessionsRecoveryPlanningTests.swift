// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
final class CookingSessionsRecoveryPlanningTests: XCTestCase {
  func testClosureCandidatesRequireOnlyCompetingClosuresAndCoalesceExactRetries() {
    let sessionID = CookingSession.ID(rawValue: id(1))
    let first = closure(id: 2, sessionID: sessionID, finishedAt: 20)
    let second = closure(id: 3, sessionID: sessionID, finishedAt: 10)
    let third = closure(id: 4, sessionID: sessionID, finishedAt: 10)
    let evidence = SessionEvidence(
      sessionID: sessionID,
      closures: [first, second, first, third]
    )

    XCTAssertEqual(
      CookingSessions.closureCandidates(for: SessionRecovery(
        evidence: evidence,
        reasons: [.competingClosures]
      )).map(\.id),
      [second.id, third.id, first.id]
    )
    XCTAssertTrue(CookingSessions.closureCandidates(for: SessionRecovery(
      evidence: evidence,
      reasons: [.malformedSnapshot]
    )).isEmpty)
  }

  func testClosureCandidatesRejectLogicalIdentityCollision() {
    let sessionID = CookingSession.ID(rawValue: id(10))
    let first = closure(id: 11, sessionID: sessionID, finishedAt: 10)
    let collision = closure(id: 11, sessionID: sessionID, finishedAt: 11)
    let recovery = SessionRecovery(
      evidence: SessionEvidence(sessionID: sessionID, closures: [first, collision]),
      reasons: [.competingClosures]
    )

    XCTAssertTrue(CookingSessions.closureCandidates(for: recovery).isEmpty)
  }

  func testKnownDescendantsTraverseOrdinaryUnavailableAndRecoveryRoots() throws {
    let fixture = try FactFixture()
    let sourceID = fixture.sessionID
    let ordinaryID = CookingSession.ID(rawValue: id(21))
    let unavailableID = CookingSession.ID(rawValue: id(22))
    let recoveryID = CookingSession.ID(rawValue: id(23))
    let ordinary = CookingSessionProjection(
      id: ordinaryID,
      snapshot: ExecutionSnapshot(title: "Ordinary continuation"),
      sourceSessionID: sourceID,
      sourceClosureID: SessionClosure.ID()
    )
    let unrelatedOrdinary = CookingSessionProjection(
      id: CookingSession.ID(rawValue: id(25)),
      snapshot: ExecutionSnapshot(title: "Original")
    )
    let unavailable = UnavailableSession(
      evidence: SessionEvidence(
        sessionID: unavailableID,
        roots: [root(id: unavailableID, sourceID: ordinaryID, copying: fixture.root)]
      ),
      reasons: [.missingPredecessor(ordinaryID.rawValue)]
    )
    let recovery = SessionRecovery(
      evidence: SessionEvidence(
        sessionID: recoveryID,
        roots: [root(id: recoveryID, sourceID: unavailableID, copying: fixture.root)]
      ),
      reasons: [.rootCollision]
    )
    XCTAssertEqual(CookingSessions.knownDescendantCount(
      of: sourceID,
      among: [
        .session(ordinary),
        .session(unrelatedOrdinary),
        .unavailable(unavailable),
        .recovery(recovery),
      ]
    ), 3)
    XCTAssertEqual(
      CookingSessions.knownDescendantCount(of: recoveryID, among: [.session(ordinary)]),
      0,
    )
  }

  func testKnownDescendantsNeverCountTheSourceThroughRetainedLineageCycles() throws {
    let fixture = try FactFixture()
    let sourceID = fixture.sessionID
    let continuationID = CookingSession.ID(rawValue: id(26))
    let sourceRecovery = SessionRecovery(
      evidence: SessionEvidence(
        sessionID: sourceID,
        roots: [root(id: sourceID, sourceID: continuationID, copying: fixture.root)]
      ),
      reasons: [.rootCollision]
    )
    let continuationRecovery = SessionRecovery(
      evidence: SessionEvidence(
        sessionID: continuationID,
        roots: [root(id: continuationID, sourceID: sourceID, copying: fixture.root)]
      ),
      reasons: [.rootCollision]
    )

    XCTAssertEqual(CookingSessions.knownDescendantCount(
      of: sourceID,
      among: [.recovery(sourceRecovery), .recovery(continuationRecovery)]
    ), 1)
  }

  func testKnownDescendantsTraverseLargeBranchingLineageWithRepeatedEvidence() throws {
    let fixture = try FactFixture()
    let sourceID = fixture.sessionID
    var results: [SessionProjectionResult] = []
    var parentID = sourceID
    let lineageLength = 65_536

    for offset in 0..<lineageLength {
      let continuationID = CookingSession.ID(rawValue: id(1_000 + offset))
      results.append(.session(CookingSessionProjection(
        id: continuationID,
        snapshot: ExecutionSnapshot(title: "Continuation \(offset)"),
        sourceSessionID: parentID,
        sourceClosureID: SessionClosure.ID()
      )))
      if offset.isMultiple(of: 1_024) {
        let branchID = CookingSession.ID(rawValue: id(100_000 + offset))
        results.append(.session(CookingSessionProjection(
          id: branchID,
          snapshot: ExecutionSnapshot(title: "Branch \(offset)"),
          sourceSessionID: parentID,
          sourceClosureID: SessionClosure.ID()
        )))
      }
      parentID = continuationID
    }

    let unavailableID = CookingSession.ID(rawValue: id(200_000))
    let unavailableRoot = root(id: unavailableID, sourceID: parentID, copying: fixture.root)
    results.append(.unavailable(UnavailableSession(
      evidence: SessionEvidence(
        sessionID: unavailableID,
        roots: [unavailableRoot, unavailableRoot]
      ),
      reasons: [.missingPredecessor(parentID.rawValue)]
    )))

    let recoveryID = CookingSession.ID(rawValue: id(200_001))
    let recoveryRoot = root(id: recoveryID, sourceID: unavailableID, copying: fixture.root)
    results.append(.recovery(SessionRecovery(
      evidence: SessionEvidence(
        sessionID: recoveryID,
        roots: [recoveryRoot, recoveryRoot]
      ),
      reasons: [.rootCollision]
    )))

    XCTAssertEqual(
      CookingSessions.knownDescendantCount(of: sourceID, among: results),
      lineageLength + 64 + 2
    )
  }

  private func closure(
    id value: Int,
    sessionID: CookingSession.ID,
    finishedAt: TimeInterval
  ) -> SessionClosureEvidence {
    SessionClosureEvidence(
      id: SessionClosure.ID(rawValue: id(value)),
      sessionID: sessionID,
      kitchenID: Kitchen.ID(rawValue: id(99)),
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

  private func root(
    id: CookingSession.ID,
    sourceID: CookingSession.ID,
    copying source: CookingSessionRootEvidence
  ) -> CookingSessionRootEvidence {
    CookingSessionRootEvidence(
      id: id,
      kitchenID: source.kitchenID,
      recipeID: source.recipeID,
      recipeRevisionID: source.recipeRevisionID,
      startedAt: source.startedAt,
      snapshotFormatVersion: source.snapshotFormatVersion,
      snapshotData: source.snapshotData,
      snapshotDigest: source.snapshotDigest,
      sourceSessionID: sourceID,
      sourceClosureID: SessionClosure.ID(rawValue: self.id(98))
    )
  }

  private func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0018-%012d", value))!
  }
}
