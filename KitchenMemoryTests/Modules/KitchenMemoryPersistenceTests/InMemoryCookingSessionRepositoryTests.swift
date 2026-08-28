// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import KitchenMemoryPersistence
import XCTest

@MainActor
// The adapter matrix intentionally keeps every transaction case in one suite.
// swiftlint:disable:next type_body_length
final class InMemoryCookingSessionRepositoryTests: XCTestCase {
  func testStartAndActivityProjectThroughTheRepositorySeam() throws {
    let repository = InMemoryCookingSessionRepository()
    let root = try makeRoot()
    let stop = try makeFact(sessionID: root.id, kitchenID: root.kitchenID, kind: .stop)

    try repository.append(.start(root))
    assertLifecycle(try repository.session(id: root.id), equals: .active)

    try repository.append(.activity(stop))
    assertLifecycle(try repository.session(id: root.id), equals: .stopped)
    XCTAssertEqual(try repository.sessions(in: root.kitchenID).count, 1)
  }

  func testRetryCoalescesAndLogicalCollisionRemainsRecoveryEvidence() throws {
    let repository = InMemoryCookingSessionRepository()
    let root = try makeRoot()

    try repository.append(.start(root))
    try repository.append(.start(root))
    assertLifecycle(try repository.session(id: root.id), equals: .active)

    let collision = CookingSessionRootEvidence(
      id: root.id,
      kitchenID: root.kitchenID,
      recipeID: root.recipeID,
      recipeRevisionID: root.recipeRevisionID,
      startedAt: Date(timeIntervalSince1970: 101),
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotData: root.snapshotData,
      snapshotDigest: root.snapshotDigest
    )
    try repository.append(.start(collision))

    guard case let .recovery(recovery) = try XCTUnwrap(repository.session(id: root.id)) else {
      XCTFail("Expected retained root collision")
      return
    }
    XCTAssertEqual(recovery.reasons, [.rootCollision])
    XCTAssertEqual(recovery.evidence.roots.count, 3)
  }

  func testKitchenAndRecipeQueriesDoNotCrossOwnership() throws {
    let repository = InMemoryCookingSessionRepository()
    let first = try makeRoot()
    let second = try makeRoot(
      sessionID: CookingSession.ID(rawValue: id(20)),
      kitchenID: Kitchen.ID(rawValue: id(21)),
      recipeID: Recipe.ID(rawValue: id(22)),
      revisionID: RecipeRevision.ID(rawValue: id(23))
    )
    try repository.append(.start(first))
    try repository.append(.start(second))

    XCTAssertEqual(try repository.sessions(in: first.kitchenID).map(\.sessionID), [first.id])
    XCTAssertEqual(try repository.sessions(for: second.recipeID).map(\.sessionID), [second.id])
  }

  func testRootAuthorityExcludesForeignAggregateWithLocalChildren() throws {
    let repository = InMemoryCookingSessionRepository()
    let localKitchenID = Kitchen.ID(rawValue: id(24))
    let foreign = try makeRoot(
      sessionID: CookingSession.ID(rawValue: id(25)),
      kitchenID: Kitchen.ID(rawValue: id(26))
    )
    try repository.append(.start(foreign))
    try repository.append(.activity(try makeFact(
      sessionID: foreign.id,
      kitchenID: localKitchenID,
      kind: .stop
    )))
    try repository.append(.finish(try makeClosure(
      root: foreign,
      kitchenID: localKitchenID
    )))

    XCTAssertTrue(try repository.sessions(in: localKitchenID).isEmpty)
    XCTAssertTrue(try repository.finishedSessions(in: localKitchenID, limit: 1).isEmpty)
    XCTAssertEqual(try repository.sessions(in: foreign.kitchenID).map(\.sessionID), [foreign.id])
  }

  func testFinishedAndDispositionQueriesExposeRetainedDomainEvidence() throws {
    let repository = InMemoryCookingSessionRepository()
    let root = try makeRoot()
    let closure = try makeClosure(root: root)
    let deletion = makeDeletion(root: root, closure: closure)
    let restoration = makeRestoration(root: root, deletion: deletion)

    XCTAssertNil(try repository.session(id: root.id))
    try repository.append(.start(root))
    try repository.append(.finish(closure))
    try repository.append(.delete(deletion))
    try repository.append(.restore([restoration]))

    XCTAssertTrue(try repository.finishedSessions(in: root.kitchenID, limit: 0).isEmpty)
    XCTAssertEqual(try repository.finishedSessions(in: root.kitchenID, limit: 1).count, 1)
    XCTAssertEqual(try repository.deletions(in: root.kitchenID), [deletion])
    XCTAssertEqual(try repository.deletions(for: root.id), [deletion])
    XCTAssertTrue(
      try repository.deletions(for: CookingSession.ID(rawValue: id(99))).isEmpty
    )
    XCTAssertEqual(try repository.deletions(id: deletion.id), [deletion])
    XCTAssertEqual(try repository.restorations(for: deletion.id), [restoration])
  }

  func testIncompleteTransactionShapesAreRejectedBeforeAnyEvidenceIsAppended() throws {
    let repository = InMemoryCookingSessionRepository()
    let root = try makeRoot()
    let sourcedRoot = CookingSessionRootEvidence(
      id: root.id,
      kitchenID: root.kitchenID,
      recipeID: root.recipeID,
      recipeRevisionID: root.recipeRevisionID,
      startedAt: root.startedAt,
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotData: root.snapshotData,
      snapshotDigest: root.snapshotDigest,
      sourceSessionID: CookingSession.ID(rawValue: id(31)),
      sourceClosureID: SessionClosure.ID(rawValue: id(32))
    )
    let stop = try makeFact(sessionID: root.id, kitchenID: root.kitchenID, kind: .stop)
    let deletion = makeDeletion(root: root, closure: try makeClosure(root: root))
    let otherRoot = try makeRoot(sessionID: CookingSession.ID(rawValue: id(33)))
    let otherDeletion = makeDeletion(root: otherRoot, closure: try makeClosure(root: otherRoot))

    XCTAssertThrowsError(try repository.append(.start(sourcedRoot)))
    XCTAssertThrowsError(try repository.append(.continueSession(root)))
    XCTAssertThrowsError(try repository.append(.resolveClosure(stop)))
    XCTAssertThrowsError(try repository.append(.finishAndDelete(try makeClosure(root: root), otherDeletion)))
    XCTAssertThrowsError(try repository.append(.restore([])))
    XCTAssertThrowsError(try repository.append(.restore([
      makeRestoration(root: root, deletion: deletion),
      makeRestoration(root: otherRoot, deletion: otherDeletion),
    ])))
    XCTAssertNil(try repository.session(id: root.id))
  }

  func testPlaceholderBearingTransactionIsRejectedBeforeEvidenceIsAppended() throws {
    let repository = InMemoryCookingSessionRepository()
    let root = try makeRoot(kitchenID: Kitchen.ID(rawValue: id(0)))

    XCTAssertThrowsError(try repository.append(.start(root))) { error in
      XCTAssertEqual(
        error as? CookingSessionRepositoryError,
        .placeholderBearingEvidence
      )
    }
    XCTAssertNil(try repository.session(id: root.id))
  }

  // swiftlint:disable:next function_body_length
  func testBoundedFinishedAndDispositionReadsHaveDeterministicOrdering() throws {
    let repository = InMemoryCookingSessionRepository()
    let first = try makeRoot()
    let second = try makeRoot(sessionID: CookingSession.ID(rawValue: id(50)))
    let third = try makeRoot(sessionID: CookingSession.ID(rawValue: id(58)))
    let firstClosure = try makeClosure(
      root: first,
      id: SessionClosure.ID(rawValue: id(51)),
      finishedAt: Date(timeIntervalSince1970: 150)
    )
    let secondClosure = try makeClosure(
      root: second,
      id: SessionClosure.ID(rawValue: id(52)),
      finishedAt: Date(timeIntervalSince1970: 160)
    )
    let thirdClosure = try makeClosure(
      root: third,
      id: SessionClosure.ID(rawValue: id(59)),
      finishedAt: Date(timeIntervalSince1970: 160)
    )
    try repository.append(.start(first))
    try repository.append(.start(second))
    try repository.append(.start(third))
    try repository.append(.finish(firstClosure))
    try repository.append(.finish(secondClosure))
    try repository.append(.finish(thirdClosure))

    XCTAssertEqual(
      try repository.sessions(in: first.kitchenID).map(\.sessionID),
      [first.id, second.id, third.id]
    )

    XCTAssertEqual(
      try repository.finishedSessions(in: first.kitchenID, limit: 3).map(\.sessionID),
      [second.id, third.id, first.id]
    )

    let earlier = makeDeletion(
      root: first,
      closure: firstClosure,
      id: SessionDeletion.ID(rawValue: id(53)),
      deletedAt: Date(timeIntervalSince1970: 170)
    )
    let later = makeDeletion(
      root: first,
      closure: firstClosure,
      id: SessionDeletion.ID(rawValue: id(54)),
      deletedAt: Date(timeIntervalSince1970: 180)
    )
    let tied = makeDeletion(
      root: first,
      closure: firstClosure,
      id: SessionDeletion.ID(rawValue: id(60)),
      deletedAt: Date(timeIntervalSince1970: 180)
    )
    try repository.append(.delete(earlier))
    try repository.append(.delete(later))
    try repository.append(.delete(tied))
    XCTAssertEqual(try repository.deletions(for: first.id), [later, tied, earlier])

    let firstRestore = makeRestoration(root: first, deletion: earlier, id: id(55))
    let secondRestore = makeRestoration(root: first, deletion: later, id: id(56))
    let repeatedRestore = makeRestoration(root: first, deletion: earlier, id: id(57))
    try repository.append(.restore([secondRestore, repeatedRestore, firstRestore]))
    XCTAssertEqual(
      try repository.restorations(for: earlier.id),
      [firstRestore, repeatedRestore]
    )
    XCTAssertEqual(try repository.restorations(for: later.id), [secondRestore])
  }

  private func makeRoot(
    sessionID: CookingSession.ID? = nil,
    kitchenID: Kitchen.ID? = nil,
    recipeID: Recipe.ID? = nil,
    revisionID: RecipeRevision.ID? = nil
  ) throws -> CookingSessionRootEvidence {
    let snapshot = try ExecutionSnapshotCodec.encode(ExecutionSnapshot(title: "Soup"))
    return CookingSessionRootEvidence(
      id: sessionID ?? CookingSession.ID(rawValue: id(10)),
      kitchenID: kitchenID ?? Kitchen.ID(rawValue: id(11)),
      recipeID: recipeID ?? Recipe.ID(rawValue: id(12)),
      recipeRevisionID: revisionID ?? RecipeRevision.ID(rawValue: id(13)),
      startedAt: Date(timeIntervalSince1970: 100),
      snapshotFormatVersion: snapshot.formatVersion,
      snapshotData: snapshot.data,
      snapshotDigest: snapshot.digest
    )
  }

  private func makeFact(
    sessionID: CookingSession.ID,
    kitchenID: Kitchen.ID,
    kind: SessionFact.Kind
  ) throws -> SessionFactEvidence {
    let payload = try SessionFactPayloadCodec.encode(.empty)
    let heads = CausalHeadsCodec.encode([sessionID.rawValue])
    return SessionFactEvidence(
      id: SessionFact.ID(rawValue: id(14)),
      sessionID: sessionID,
      kitchenID: kitchenID,
      kind: kind.rawValue,
      targetSnapshotElementID: nil,
      authoredAt: Date(timeIntervalSince1970: 110),
      causalHeadsFormatVersion: heads.formatVersion,
      causalHeadsData: heads.data,
      payloadFormatVersion: payload.formatVersion,
      payloadData: payload.data,
      payloadDigest: payload.digest
    )
  }

  private func makeClosure(
    root: CookingSessionRootEvidence,
    id: SessionClosure.ID? = nil,
    finishedAt: Date = Date(timeIntervalSince1970: 120),
    kitchenID: Kitchen.ID? = nil
  ) throws -> SessionClosureEvidence {
    let snapshot = try ExecutionSnapshotCodec.decode(
      formatVersion: root.snapshotFormatVersion,
      data: root.snapshotData
    )
    let projection = try ClosedSessionProjectionCodec.encode(
      ClosedSessionProjection(CookingSessionProjection(id: root.id, snapshot: snapshot))
    )
    let heads = CausalHeadsCodec.encode([root.id.rawValue])
    return SessionClosureEvidence(
      id: id ?? SessionClosure.ID(rawValue: self.id(40)),
      sessionID: root.id,
      kitchenID: kitchenID ?? root.kitchenID,
      finishedAt: finishedAt,
      causalHeadsFormatVersion: heads.formatVersion,
      causalHeadsData: heads.data,
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotDigest: root.snapshotDigest,
      projectionFormatVersion: projection.formatVersion,
      projectionDigest: projection.digest,
      outcomeFormatVersion: nil,
      outcomeData: nil
    )
  }

  private func makeDeletion(
    root: CookingSessionRootEvidence,
    closure: SessionClosureEvidence,
    id: SessionDeletion.ID? = nil,
    deletedAt: Date = Date(timeIntervalSince1970: 130)
  ) -> SessionDeletionEvidence {
    let sessionHeads = CausalHeadsCodec.encode([closure.id.rawValue])
    let dispositionHeads = CausalHeadsCodec.encode([])
    return SessionDeletionEvidence(
      id: id ?? SessionDeletion.ID(rawValue: self.id(41)),
      sessionID: root.id,
      kitchenID: root.kitchenID,
      deletedAt: deletedAt,
      sessionHeadsFormatVersion: sessionHeads.formatVersion,
      sessionHeadsData: sessionHeads.data,
      dispositionHeadsFormatVersion: dispositionHeads.formatVersion,
      dispositionHeadsData: dispositionHeads.data
    )
  }

  private func makeRestoration(
    root: CookingSessionRootEvidence,
    deletion: SessionDeletionEvidence,
    id: UUID = UUID()
  ) -> SessionDeletionResolutionEvidence {
    let heads = CausalHeadsCodec.encode([deletion.id.rawValue])
    return SessionDeletionResolutionEvidence(
      id: SessionDeletionResolution.ID(rawValue: id),
      deletionID: deletion.id,
      sessionID: root.id,
      kitchenID: root.kitchenID,
      restoredAt: Date(timeIntervalSince1970: 140),
      dispositionHeadsFormatVersion: heads.formatVersion,
      dispositionHeadsData: heads.data
    )
  }

  private func assertLifecycle(
    _ result: SessionProjectionResult?,
    equals expected: SessionLifecycle,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard case let .session(session) = result else {
      XCTFail("Expected ordinary Session", file: file, line: line)
      return
    }
    XCTAssertEqual(session.lifecycle, expected, file: file, line: line)
  }

  private func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
  }
}

private extension SessionProjectionResult {
  var sessionID: CookingSession.ID {
    switch self {
    case let .session(session): session.id
    case let .unavailable(unavailable): unavailable.evidence.sessionID
    case let .recovery(recovery): recovery.evidence.sessionID
    }
  }
}
