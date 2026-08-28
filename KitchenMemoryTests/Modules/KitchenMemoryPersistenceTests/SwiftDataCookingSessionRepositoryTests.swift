// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryPersistence
import Foundation
import KitchenMemoryDomain
import SwiftData
import XCTest

// The durable transaction matrix keeps its reusable evidence constructors next
// to the assertions so each stored field remains independently reviewable.
// swiftlint:disable file_length

@MainActor
// swiftlint:disable:next type_body_length
final class SwiftDataCookingSessionRepositoryTests: XCTestCase {
  func testStartAndActivityRemainClassifiedAfterLocalReopen() throws {
    let store = try TemporarySessionStore()
    defer { store.remove() }
    let root = try makeRoot()
    let stop = try makeFact(root: root, kind: .stop)

    do {
      let repository = SwiftDataCookingSessionRepository(modelContainer: try store.container())
      try repository.append(.start(root))
      try repository.append(.activity(stop))
    }

    let reopened = SwiftDataCookingSessionRepository(modelContainer: try store.container())
    guard case let .session(session) = try XCTUnwrap(reopened.session(id: root.id)) else {
      XCTFail("Expected a durable ordinary Session")
      return
    }
    XCTAssertEqual(session.lifecycle, .stopped)
    XCTAssertEqual(try reopened.sessions(in: root.kitchenID).count, 1)
    XCTAssertEqual(try reopened.sessions(for: root.recipeID).count, 1)
  }

  func testPhysicalDuplicateAndCollisionRowsRemainVisibleToClassification() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataCookingSessionRepository(modelContainer: container)
    let root = try makeRoot()
    try repository.append(.start(root))
    try repository.append(.start(root))

    guard case .session = try repository.session(id: root.id) else {
      XCTFail("Identical physical rows should coalesce")
      return
    }

    let collision = CookingSessionRootEvidence(
      id: root.id,
      kitchenID: root.kitchenID,
      recipeID: root.recipeID,
      recipeRevisionID: root.recipeRevisionID,
      startedAt: Date(timeIntervalSince1970: 201),
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotData: root.snapshotData,
      snapshotDigest: root.snapshotDigest
    )
    try repository.append(.start(collision))

    guard case let .recovery(recovery) = try repository.session(id: root.id) else {
      XCTFail("Expected root collision Recovery")
      return
    }
    XCTAssertEqual(recovery.reasons, [.rootCollision])
    XCTAssertEqual(recovery.evidence.roots.count, 3)
  }

  func testRootAuthorityExcludesForeignAggregateWithLocalChildren() throws {
    let repository = SwiftDataCookingSessionRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let localKitchenID = Kitchen.ID(rawValue: id(110))
    let foreign = try makeRoot(
      id: CookingSession.ID(rawValue: id(111)),
      kitchenID: Kitchen.ID(rawValue: id(112))
    )
    try repository.append(.start(foreign))
    try repository.append(.activity(try makeFact(
      root: foreign,
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

  func testFinishDeleteAndRestoreUseCompleteTransactionsAndQueries() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataCookingSessionRepository(modelContainer: container)
    let root = try makeRoot()
    let closure = try makeClosure(root: root)
    let deletion = makeDeletion(root: root, closure: closure)
    let restoration = makeRestoration(root: root, deletion: deletion)

    try repository.append(.start(root))
    try repository.append(.finishAndDelete(closure, deletion))
    XCTAssertEqual(try repository.deletions(id: deletion.id), [deletion])
    XCTAssertEqual(try repository.deletions(in: root.kitchenID), [deletion])
    XCTAssertEqual(try repository.deletions(for: root.id), [deletion])
    XCTAssertEqual(try repository.finishedSessions(in: root.kitchenID, limit: 1).count, 1)

    try repository.append(.restore([restoration]))
    XCTAssertEqual(try repository.restorations(for: deletion.id), [restoration])
    XCTAssertEqual(try repository.sessions(in: root.kitchenID).count, 1)
    guard case let .session(session) = try repository.session(id: root.id) else {
      XCTFail("Expected restored Finished Session")
      return
    }
    XCTAssertEqual(session.lifecycle, .finished)
    XCTAssertEqual(session.disposition, .ordinary)
  }

  // The five-family placeholder matrix proves state and evidence-query behavior together.
  // swiftlint:disable:next function_body_length
  func testPlaceholderBearingImportedRowCannotBecomeOrdinaryState() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let context = ModelContext(container)
    let placeholder = CookingSessionRecord(
      id: zero,
      kitchenID: zero,
      recipeID: zero,
      recipeRevisionID: zero,
      startedAt: .distantPast,
      snapshotFormatVersion: -1,
      snapshotData: Data(),
      snapshotDigest: Data(),
      sourceSessionID: nil,
      sourceClosureID: nil
    )
    let deletionID = id(118)
    let placeholderDeletion = SessionDeletionRecord(
      id: deletionID,
      sessionID: zero,
      kitchenID: zero,
      deletedAt: .distantPast,
      sessionHeadsFormatVersion: -1,
      sessionHeadsData: Data(),
      dispositionHeadsFormatVersion: -1,
      dispositionHeadsData: Data()
    )
    let placeholderRestoration = SessionDeletionResolutionRecord(
      id: id(119),
      deletionID: deletionID,
      sessionID: zero,
      kitchenID: zero,
      restoredAt: .distantPast,
      dispositionHeadsFormatVersion: -1,
      dispositionHeadsData: Data()
    )
    context.insert(placeholder)
    context.insert(placeholderDeletion)
    context.insert(placeholderRestoration)
    try context.save()

    let repository = SwiftDataCookingSessionRepository(modelContainer: container)
    guard case let .recovery(recovery) = try repository.session(
      id: CookingSession.ID(rawValue: zero)
    ) else {
      XCTFail("Expected placeholder Recovery")
      return
    }
    XCTAssertEqual(recovery.reasons, [.placeholderBearingRecord])
    XCTAssertEqual(recovery.evidence.roots.count, 1)
    XCTAssertEqual(recovery.evidence.deletions.count, 1)
    XCTAssertEqual(recovery.evidence.restorations.count, 1)
    XCTAssertThrowsError(
      try repository.deletions(id: SessionDeletion.ID(rawValue: deletionID))
    ) { error in
      XCTAssertEqual(error as? CookingSessionRepositoryError, .placeholderBearingEvidence)
    }
    XCTAssertThrowsError(
      try repository.restorations(for: SessionDeletion.ID(rawValue: deletionID))
    ) { error in
      XCTAssertEqual(error as? CookingSessionRepositoryError, .placeholderBearingEvidence)
    }
  }

  func testFinishResolutionDeleteAndContinueEachAppendTheirCompleteEvidence() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataCookingSessionRepository(modelContainer: container)
    let root = try makeRoot()
    let firstClosure = try makeClosure(root: root)
    let secondClosure = try makeClosure(
      root: root,
      id: SessionClosure.ID(rawValue: id(108)),
      finishedAt: Date(timeIntervalSince1970: 221)
    )
    try repository.append(.start(root))
    try repository.append(.finish(firstClosure))
    try repository.append(.finish(secondClosure))
    guard case let .recovery(recovery) = try repository.session(id: root.id) else {
      XCTFail("Expected competing Closures before selection")
      return
    }
    XCTAssertEqual(recovery.reasons, [.competingClosures])

    try repository.append(.resolveClosure(
      try makeClosureResolution(
        root: root,
        selected: firstClosure.id,
        observed: [firstClosure.id, secondClosure.id]
      )
    ))
    guard case let .session(finished) = try repository.session(id: root.id) else {
      XCTFail("Expected selected Finished Session")
      return
    }
    XCTAssertEqual(finished.selectedClosureID, firstClosure.id)

    let continuation = try makeContinuationRoot(source: root, closure: firstClosure)
    try repository.append(.continueSession(continuation))
    guard case let .session(active) = try repository.session(id: continuation.id) else {
      XCTFail("Expected complete Active continuation")
      return
    }
    XCTAssertEqual(active.lifecycle, .active)

    let deletion = makeDeletion(root: continuation, sessionHead: continuation.id.rawValue)
    try repository.append(.delete(deletion))
    guard case let .session(deleted) = try repository.session(id: continuation.id) else {
      XCTFail("Expected deleted continuation")
      return
    }
    XCTAssertEqual(deleted.disposition, .deleted(needsAttention: false))
  }

  func testFailedAtomicFinishAndDeleteLeavesNoDurableOrPendingEvidence() throws {
    let store = try TemporarySessionStore()
    defer { store.remove() }
    let root = try makeRoot()
    let closure = try makeClosure(root: root)
    let deletion = makeDeletion(root: root, closure: closure)
    try SwiftDataCookingSessionRepository(modelContainer: try store.container())
      .append(.start(root))

    let readOnly = SwiftDataCookingSessionRepository(modelContainer: try store.readOnlyContainer())
    XCTAssertThrowsError(try readOnly.append(.finishAndDelete(closure, deletion)))
    guard case let .session(stillActive) = try readOnly.session(id: root.id) else {
      XCTFail("Expected unchanged readable Session after failed save")
      return
    }
    XCTAssertEqual(stillActive.lifecycle, .active)
    XCTAssertTrue(try readOnly.deletions(for: root.id).isEmpty)

    let reopened = SwiftDataCookingSessionRepository(modelContainer: try store.container())
    assertActive(try reopened.session(id: root.id))
    XCTAssertTrue(try reopened.deletions(for: root.id).isEmpty)
  }

  func testAppendRejectsPlaceholderEvidenceBeforeWriting() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataCookingSessionRepository(modelContainer: container)
    let root = try makeRoot()
    let placeholder = CookingSessionRootEvidence(
      id: CookingSession.ID(rawValue: zero),
      kitchenID: root.kitchenID,
      recipeID: root.recipeID,
      recipeRevisionID: root.recipeRevisionID,
      startedAt: root.startedAt,
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotData: root.snapshotData,
      snapshotDigest: root.snapshotDigest
    )

    XCTAssertThrowsError(try repository.append(.start(placeholder))) { error in
      XCTAssertEqual(
        error as? CookingSessionRepositoryError,
        .placeholderBearingEvidence
      )
    }
    XCTAssertNil(try repository.session(id: placeholder.id))

    try repository.append(.start(root))
    let closure = try makeClosure(root: root)
    let outcome = try SessionOutcomeCodec.encode(.coarse(.okay))
    let outcomeClosure = SessionClosureEvidence(
      id: closure.id,
      sessionID: closure.sessionID,
      kitchenID: closure.kitchenID,
      finishedAt: closure.finishedAt,
      causalHeadsFormatVersion: closure.causalHeadsFormatVersion,
      causalHeadsData: closure.causalHeadsData,
      snapshotFormatVersion: closure.snapshotFormatVersion,
      snapshotDigest: closure.snapshotDigest,
      projectionFormatVersion: closure.projectionFormatVersion,
      projectionDigest: closure.projectionDigest,
      outcomeFormatVersion: outcome.formatVersion,
      outcomeData: outcome.data
    )
    try repository.append(.finish(outcomeClosure))
    guard case .recovery = try repository.session(id: root.id) else {
      XCTFail("Outcome bytes without a matching closed projection must stay in Recovery")
      return
    }
  }

  func testFixedSeedReconstructionPermutationsRetainOneStableResult() throws {
    let root = try makeRoot()
    let closure = try makeClosure(root: root)
    let deletion = makeDeletion(root: root, closure: closure)
    let restoration = makeRestoration(root: root, deletion: deletion)
    let transactions: [CookingSessionTransaction] = [
      .start(root),
      .finish(closure),
      .delete(deletion),
      .restore([restoration]),
    ]

    for seed in 1 ... 16 {
      let repository = SwiftDataCookingSessionRepository(
        modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
      )
      for transaction in shuffled(transactions, seed: UInt64(seed)) {
        try repository.append(transaction)
        try repository.append(transaction)
      }

      guard case let .session(session) = try repository.session(id: root.id) else {
        XCTFail("Seed \(seed) did not reconstruct an ordinary Session")
        continue
      }
      XCTAssertEqual(session.lifecycle, .finished, "seed \(seed)")
      XCTAssertEqual(session.disposition, .ordinary, "seed \(seed)")
    }
  }

  // swiftlint:disable:next function_body_length
  func testBoundedFinishedAndDispositionQueriesAreDeterministicallyOrdered() throws {
    let repository = SwiftDataCookingSessionRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let first = try makeRoot()
    let second = try makeRoot(id: CookingSession.ID(rawValue: id(120)))
    let third = try makeRoot(id: CookingSession.ID(rawValue: id(121)))
    let firstClosure = try makeClosure(
      root: first,
      id: SessionClosure.ID(rawValue: id(122)),
      finishedAt: Date(timeIntervalSince1970: 300)
    )
    let secondClosure = try makeClosure(
      root: second,
      id: SessionClosure.ID(rawValue: id(123)),
      finishedAt: Date(timeIntervalSince1970: 310)
    )
    let thirdClosure = try makeClosure(
      root: third,
      id: SessionClosure.ID(rawValue: id(124)),
      finishedAt: Date(timeIntervalSince1970: 310)
    )
    for (root, closure) in [
      (first, firstClosure),
      (second, secondClosure),
      (third, thirdClosure),
    ] {
      try repository.append(.start(root))
      try repository.append(.finish(closure))
    }
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
      sessionHead: firstClosure.id.rawValue,
      id: SessionDeletion.ID(rawValue: id(125)),
      deletedAt: Date(timeIntervalSince1970: 320)
    )
    let later = makeDeletion(
      root: first,
      sessionHead: firstClosure.id.rawValue,
      id: SessionDeletion.ID(rawValue: id(126)),
      deletedAt: Date(timeIntervalSince1970: 330)
    )
    let tied = makeDeletion(
      root: first,
      sessionHead: firstClosure.id.rawValue,
      id: SessionDeletion.ID(rawValue: id(127)),
      deletedAt: Date(timeIntervalSince1970: 330)
    )
    try repository.append(.delete(earlier))
    try repository.append(.delete(later))
    try repository.append(.delete(tied))
    XCTAssertEqual(try repository.deletions(for: first.id), [later, tied, earlier])

    let firstRestore = makeRestoration(root: first, deletion: earlier, id: id(128))
    let secondRestore = makeRestoration(root: first, deletion: earlier, id: id(129))
    try repository.append(.restore([secondRestore, firstRestore]))
    XCTAssertEqual(
      try repository.restorations(for: earlier.id),
      [firstRestore, secondRestore]
    )
  }

  private func makeRoot(
    id: CookingSession.ID? = nil,
    kitchenID: Kitchen.ID? = nil
  ) throws -> CookingSessionRootEvidence {
    let snapshot = try ExecutionSnapshotCodec.encode(ExecutionSnapshot(title: "Soup"))
    return CookingSessionRootEvidence(
      id: id ?? CookingSession.ID(rawValue: self.id(100)),
      kitchenID: kitchenID ?? Kitchen.ID(rawValue: self.id(101)),
      recipeID: Recipe.ID(rawValue: self.id(102)),
      recipeRevisionID: RecipeRevision.ID(rawValue: self.id(103)),
      startedAt: Date(timeIntervalSince1970: 200),
      snapshotFormatVersion: snapshot.formatVersion,
      snapshotData: snapshot.data,
      snapshotDigest: snapshot.digest
    )
  }

  private func makeFact(
    root: CookingSessionRootEvidence,
    kitchenID: Kitchen.ID? = nil,
    kind: SessionFact.Kind
  ) throws -> SessionFactEvidence {
    let heads = CausalHeadsCodec.encode([root.id.rawValue])
    let payload = try SessionFactPayloadCodec.encode(.empty)
    return SessionFactEvidence(
      id: SessionFact.ID(rawValue: id(104)),
      sessionID: root.id,
      kitchenID: kitchenID ?? root.kitchenID,
      kind: kind.rawValue,
      targetSnapshotElementID: nil,
      authoredAt: Date(timeIntervalSince1970: 210),
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
    finishedAt: Date = Date(timeIntervalSince1970: 220),
    kitchenID: Kitchen.ID? = nil
  ) throws -> SessionClosureEvidence {
    let snapshot = try ExecutionSnapshotCodec.decode(
      formatVersion: root.snapshotFormatVersion,
      data: root.snapshotData
    )
    let closed = try ClosedSessionProjectionCodec.encode(
      ClosedSessionProjection(CookingSessionProjection(id: root.id, snapshot: snapshot))
    )
    let heads = CausalHeadsCodec.encode([root.id.rawValue])
    return SessionClosureEvidence(
      id: id ?? SessionClosure.ID(rawValue: self.id(105)),
      sessionID: root.id,
      kitchenID: kitchenID ?? root.kitchenID,
      finishedAt: finishedAt,
      causalHeadsFormatVersion: heads.formatVersion,
      causalHeadsData: heads.data,
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotDigest: root.snapshotDigest,
      projectionFormatVersion: closed.formatVersion,
      projectionDigest: closed.digest,
      outcomeFormatVersion: nil,
      outcomeData: nil
    )
  }

  private func makeDeletion(
    root: CookingSessionRootEvidence,
    closure: SessionClosureEvidence
  ) -> SessionDeletionEvidence {
    makeDeletion(root: root, sessionHead: closure.id.rawValue)
  }

  private func makeDeletion(
    root: CookingSessionRootEvidence,
    sessionHead: UUID,
    id: SessionDeletion.ID? = nil,
    deletedAt: Date = Date(timeIntervalSince1970: 230)
  ) -> SessionDeletionEvidence {
    let sessionHeads = CausalHeadsCodec.encode([sessionHead])
    let dispositionHeads = CausalHeadsCodec.encode([])
    return SessionDeletionEvidence(
      id: id ?? SessionDeletion.ID(rawValue: self.id(106)),
      sessionID: root.id,
      kitchenID: root.kitchenID,
      deletedAt: deletedAt,
      sessionHeadsFormatVersion: sessionHeads.formatVersion,
      sessionHeadsData: sessionHeads.data,
      dispositionHeadsFormatVersion: dispositionHeads.formatVersion,
      dispositionHeadsData: dispositionHeads.data
    )
  }

  private func makeClosureResolution(
    root: CookingSessionRootEvidence,
    selected: SessionClosure.ID,
    observed: [SessionClosure.ID]
  ) throws -> SessionFactEvidence {
    let heads = CausalHeadsCodec.encode(observed.map(\.rawValue))
    let payload = try SessionFactPayloadCodec.encode(
      .closureResolution(
        ClosureSelection(selectedClosureID: selected, observedClosureIDs: observed)
      )
    )
    return SessionFactEvidence(
      id: SessionFact.ID(rawValue: id(109)),
      sessionID: root.id,
      kitchenID: root.kitchenID,
      kind: SessionFact.Kind.conflictResolution.rawValue,
      targetSnapshotElementID: nil,
      authoredAt: Date(timeIntervalSince1970: 222),
      causalHeadsFormatVersion: heads.formatVersion,
      causalHeadsData: heads.data,
      payloadFormatVersion: payload.formatVersion,
      payloadData: payload.data,
      payloadDigest: payload.digest
    )
  }

  private func makeContinuationRoot(
    source: CookingSessionRootEvidence,
    closure: SessionClosureEvidence
  ) throws -> CookingSessionRootEvidence {
    let snapshot = try ExecutionSnapshotCodec.encode(
      ExecutionSnapshot(
        title: "Soup, continued",
        continuationBaseline: SessionContinuationBaseline()
      )
    )
    return CookingSessionRootEvidence(
      id: CookingSession.ID(rawValue: id(110)),
      kitchenID: source.kitchenID,
      recipeID: source.recipeID,
      recipeRevisionID: source.recipeRevisionID,
      startedAt: Date(timeIntervalSince1970: 250),
      snapshotFormatVersion: snapshot.formatVersion,
      snapshotData: snapshot.data,
      snapshotDigest: snapshot.digest,
      sourceSessionID: source.id,
      sourceClosureID: closure.id
    )
  }

  private func makeRestoration(
    root: CookingSessionRootEvidence,
    deletion: SessionDeletionEvidence,
    id: UUID? = nil
  ) -> SessionDeletionResolutionEvidence {
    let heads = CausalHeadsCodec.encode([deletion.id.rawValue])
    return SessionDeletionResolutionEvidence(
      id: SessionDeletionResolution.ID(rawValue: id ?? self.id(107)),
      deletionID: deletion.id,
      sessionID: root.id,
      kitchenID: root.kitchenID,
      restoredAt: Date(timeIntervalSince1970: 240),
      dispositionHeadsFormatVersion: heads.formatVersion,
      dispositionHeadsData: heads.data
    )
  }

  private var zero: UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
  }

  private func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
  }

  private func shuffled<Value>(_ values: [Value], seed: UInt64) -> [Value] {
    var result = values
    var state = seed
    for index in stride(from: result.count - 1, through: 1, by: -1) {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      result.swapAt(index, Int(state % UInt64(index + 1)))
    }
    return result
  }

  private func assertActive(
    _ result: SessionProjectionResult?,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard case let .session(session) = result else {
      XCTFail("Expected ordinary Session", file: file, line: line)
      return
    }
    XCTAssertEqual(session.lifecycle, .active, file: file, line: line)
  }
}

@MainActor
private final class TemporarySessionStore {
  private let directory: URL
  private let storeURL: URL

  init() throws {
    directory = FileManager.default.temporaryDirectory
      .appending(path: "KitchenMemorySessionRepositoryTests")
      .appending(path: UUID().uuidString)
    storeURL = directory.appending(path: "KitchenMemory.store")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  func container() throws -> ModelContainer {
    try KitchenMemorySchema.makeContainer(storeURL: storeURL)
  }

  func readOnlyContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: KitchenMemorySchemaV3.self)
    let configuration = ModelConfiguration(
      "KitchenMemoryReadOnly",
      schema: schema,
      url: storeURL,
      allowsSave: false,
      cloudKitDatabase: .none
    )
    return try ModelContainer(
      for: schema,
      migrationPlan: KitchenMemoryMigrationPlan.self,
      configurations: [configuration]
    )
  }

  func remove() {
    try? FileManager.default.removeItem(at: directory)
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

// swiftlint:enable file_length
