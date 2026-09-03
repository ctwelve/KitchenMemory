// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
final class CookingSessionCommandGraphTests: XCTestCase {
  func testFactCommandEncodesCanonicalMaximalSessionHeads() throws {
    let factFixture = try SessionLogicFixture(seed: 1_000)
    let factRoot = try XCTUnwrap(factFixture.repository.evidence(
      id: factFixture.sessionID
    )?.roots.first)
    try factFixture.repository.append(.start(factRoot))
    let first = try rawFact(6, heads: [factRoot.id.rawValue], fixture: factFixture)
    let second = try rawFact(7, heads: [factRoot.id.rawValue], fixture: factFixture)
    try factFixture.repository.append(.activity(second))
    try factFixture.repository.append(.activity(first))
    try factFixture.repository.append(.activity(first))

    let resumed = factFixture.fact(8, at: 120)
    _ = try factFixture.logic.perform(.resume(resumed))
    _ = try factFixture.logic.perform(.resume(resumed))

    let retainedFact = try XCTUnwrap(factFixture.repository.evidence(
      id: factFixture.sessionID
    )?.facts.first { $0.id == resumed.id })
    XCTAssertEqual(try decodedHeads(retainedFact), [first.id.rawValue, second.id.rawValue])
  }

  func testClosureCommandEncodesCanonicalMaximalSessionHeads() throws {
    let closureFixture = try SessionLogicFixture(seed: 2_000)
    let closureRoot = try XCTUnwrap(closureFixture.repository.evidence(
      id: closureFixture.sessionID
    )?.roots.first)
    let closureFirst = try rawFact(6, heads: [closureRoot.id.rawValue], fixture: closureFixture)
    let closureSecond = try rawFact(7, heads: [closureRoot.id.rawValue], fixture: closureFixture)
    try closureFixture.repository.append(.activity(closureSecond))
    try closureFixture.repository.append(.activity(closureFirst))
    let closureID = try closureFixture.finish(id: 8, at: 120)

    let closure = try XCTUnwrap(closureFixture.repository.evidence(
      id: closureFixture.sessionID
    )?.closures.first { $0.id == closureID })
    try closureFixture.repository.append(.finish(closure))
    XCTAssertEqual(
      try CausalHeadsCodec.decode(
        formatVersion: closure.causalHeadsFormatVersion,
        data: closure.causalHeadsData
      ),
      [closureFirst.id.rawValue, closureSecond.id.rawValue]
    )
    let deletionID = SessionDeletion.ID(rawValue: closureFixture.id(9))
    let deletion = DeleteCookingSessionIntention(
      deletionID: deletionID,
      sessionID: closureFixture.sessionID,
      deletedAt: closureFixture.date(130)
    )
    _ = try closureFixture.logic.perform(.delete(deletion))
    _ = try closureFixture.logic.perform(.delete(deletion))
    let retainedDeletion = try XCTUnwrap(closureFixture.repository.evidence(
      id: closureFixture.sessionID
    )?.deletions.first { $0.id == deletionID })
    XCTAssertEqual(
      try CausalHeadsCodec.decode(
        formatVersion: retainedDeletion.sessionHeadsFormatVersion,
        data: retainedDeletion.sessionHeadsData
      ),
      [closure.id.rawValue]
    )
  }

  func testRestoreAndDeleteCommandsEncodeCanonicalMaximalDispositionHeads() throws {
    let fixture = try SessionLogicFixture(seed: 3_000)
    let root = try XCTUnwrap(fixture.repository.evidence(id: fixture.sessionID)?.roots.first)
    let first = try deletion(6, sessionHead: root.id.rawValue, fixture: fixture)
    let second = try deletion(7, sessionHead: root.id.rawValue, fixture: fixture)
    try fixture.repository.append(.delete(second))
    try fixture.repository.append(.delete(first))
    try fixture.repository.append(.delete(first))
    let intention = RestoreCookingSessionIntention(
      id: .init(rawValue: fixture.id(8)),
      sessionID: fixture.sessionID,
      restoredAt: fixture.date(130),
      observedDeletionIDs: [first.id, second.id]
    )

    _ = try fixture.logic.perform(.restore(intention))
    _ = try fixture.logic.perform(.restore(intention))

    let restored = try XCTUnwrap(fixture.repository.evidence(id: fixture.sessionID))
    XCTAssertEqual(restored.restorations.count, 2)
    for resolution in restored.restorations {
      XCTAssertEqual(
        try CausalHeadsCodec.decode(
          formatVersion: resolution.dispositionHeadsFormatVersion,
          data: resolution.dispositionHeadsData
        ),
        [first.id.rawValue, second.id.rawValue]
      )
    }
    try fixture.repository.append(.restore([try XCTUnwrap(restored.restorations.first)]))

    let deletionID = SessionDeletion.ID(rawValue: fixture.id(9))
    _ = try fixture.logic.perform(.delete(DeleteCookingSessionIntention(
      deletionID: deletionID,
      sessionID: fixture.sessionID,
      deletedAt: fixture.date(140)
    )))
    let retainedDeletion = try XCTUnwrap(fixture.repository.evidence(
      id: fixture.sessionID
    )?.deletions.first { $0.id == deletionID })
    XCTAssertEqual(
      try CausalHeadsCodec.decode(
        formatVersion: retainedDeletion.dispositionHeadsFormatVersion,
        data: retainedDeletion.dispositionHeadsData
      ),
      restored.restorations.map(\.id.rawValue).sorted(by: uuidOrder)
    )
  }

  func testSharedGraphMatchesLegacyCommandHeadsAcrossTopologyMatrix() {
    let identifiers = (1...260).map(id)
    let root = identifiers[0]
    let first = identifiers[1]
    let second = identifiers[2]
    let merge = identifiers[3]
    var deep = [root: [UUID]()]
    for index in 1..<256 {
      deep[identifiers[index]] = [identifiers[index - 1]]
    }
    let cases: [[UUID: [UUID]]] = [
      [:],
      [root: []],
      [root: [], first: [root], second: [first]],
      [root: [], first: [root], second: [root]],
      [root: [], first: [root], second: [root], merge: [first, second]],
      [root: [], first: [root, root]],
      [first: [second], second: [first]],
      deep,
    ]

    for parents in cases {
      let legacy = DirectedGraph(parentsByNode: parents).maximalNodes.sorted(by: uuidOrder)
      let migrated = CausalGraph(
        parentsByNode: parents,
        orderedBy: uuidOrder
      ).maximalNodes
      XCTAssertEqual(migrated, legacy)
    }
  }

  func testCommandCreationTraversesDeepEvidenceIteratively() throws {
    let fixture = try SessionLogicFixture(seed: 4_000)
    var head = fixture.sessionID.rawValue
    for value in 1...256 {
      let fact = try rawEntryFact(value + 10, heads: [head], fixture: fixture)
      try fixture.repository.append(.activity(fact))
      head = fact.id.rawValue
    }
    let intention = fixture.fact(1_000, at: 200)

    _ = try fixture.logic.perform(.submitEntry(intention, text: "latest", target: nil))

    let retained = try XCTUnwrap(fixture.repository.evidence(
      id: fixture.sessionID
    )?.facts.first { $0.id == intention.id })
    XCTAssertEqual(try decodedHeads(retained), [head])
  }

  func testMalformedAndCyclicEvidenceRemainAttentionWithoutAppending() throws {
    let malformed = try SessionLogicFixture(seed: 5_000)
    let malformedFact = try rawFact(6, heads: [], fixture: malformed)
    try malformed.repository.append(.activity(SessionFactEvidence(
      id: malformedFact.id,
      sessionID: malformedFact.sessionID,
      kitchenID: malformedFact.kitchenID,
      kind: malformedFact.kind,
      targetSnapshotElementID: malformedFact.targetSnapshotElementID,
      authoredAt: malformedFact.authoredAt,
      causalHeadsFormatVersion: malformedFact.causalHeadsFormatVersion,
      causalHeadsData: Data([0]),
      payloadFormatVersion: malformedFact.payloadFormatVersion,
      payloadData: malformedFact.payloadData,
      payloadDigest: malformedFact.payloadDigest
    )))
    guard case .attention(.recovery) = try malformed.logic.perform(.stop(
      malformed.fact(7, at: 120)
    )) else {
      XCTFail("Expected malformed evidence Recovery attention")
      return
    }
    XCTAssertEqual(try malformed.repository.evidence(id: malformed.sessionID)?.facts.count, 1)

    let cyclic = try SessionLogicFixture(seed: 6_000)
    let firstID = cyclic.id(6)
    let secondID = cyclic.id(7)
    try cyclic.repository.append(.activity(try rawFact(6, heads: [secondID], fixture: cyclic)))
    try cyclic.repository.append(.activity(try rawFact(7, heads: [firstID], fixture: cyclic)))
    guard case .attention(.recovery) = try cyclic.logic.perform(.stop(
      cyclic.fact(8, at: 120)
    )) else {
      XCTFail("Expected cyclic evidence Recovery attention")
      return
    }
    XCTAssertEqual(try cyclic.repository.evidence(id: cyclic.sessionID)?.facts.count, 2)
  }
}

private extension CookingSessionCommandGraphTests {
  func rawFact(
    _ value: Int,
    heads: [UUID],
    fixture: SessionLogicFixture
  ) throws -> SessionFactEvidence {
    let encodedHeads = CausalHeadsCodec.encode(heads)
    let payload = try SessionFactPayloadCodec.encode(.empty)
    return SessionFactEvidence(
      id: .init(rawValue: fixture.id(value)),
      sessionID: fixture.sessionID,
      kitchenID: try kitchenID(fixture),
      kind: SessionFact.Kind.stop.rawValue,
      targetSnapshotElementID: nil,
      authoredAt: fixture.date(TimeInterval(100 + value)),
      causalHeadsFormatVersion: encodedHeads.formatVersion,
      causalHeadsData: encodedHeads.data,
      payloadFormatVersion: payload.formatVersion,
      payloadData: payload.data,
      payloadDigest: payload.digest
    )
  }

  func rawEntryFact(
    _ value: Int,
    heads: [UUID],
    fixture: SessionLogicFixture
  ) throws -> SessionFactEvidence {
    let encodedHeads = CausalHeadsCodec.encode(heads)
    let identifier = fixture.id(value)
    let payload = try SessionFactPayloadCodec.encode(.sessionEntry(.submit(
      entryID: .init(rawValue: identifier),
      text: "entry \(value)"
    )))
    return SessionFactEvidence(
      id: .init(rawValue: identifier),
      sessionID: fixture.sessionID,
      kitchenID: try kitchenID(fixture),
      kind: SessionFact.Kind.sessionEntry.rawValue,
      targetSnapshotElementID: nil,
      authoredAt: fixture.date(TimeInterval(100 + value)),
      causalHeadsFormatVersion: encodedHeads.formatVersion,
      causalHeadsData: encodedHeads.data,
      payloadFormatVersion: payload.formatVersion,
      payloadData: payload.data,
      payloadDigest: payload.digest
    )
  }

  func deletion(
    _ value: Int,
    sessionHead: UUID,
    fixture: SessionLogicFixture
  ) throws -> SessionDeletionEvidence {
    let sessionHeads = CausalHeadsCodec.encode([sessionHead])
    let dispositionHeads = CausalHeadsCodec.encode([])
    return SessionDeletionEvidence(
      id: .init(rawValue: fixture.id(value)),
      sessionID: fixture.sessionID,
      kitchenID: try kitchenID(fixture),
      deletedAt: fixture.date(TimeInterval(100 + value)),
      sessionHeadsFormatVersion: sessionHeads.formatVersion,
      sessionHeadsData: sessionHeads.data,
      dispositionHeadsFormatVersion: dispositionHeads.formatVersion,
      dispositionHeadsData: dispositionHeads.data
    )
  }

  func decodedHeads(_ fact: SessionFactEvidence) throws -> [UUID] {
    try CausalHeadsCodec.decode(
      formatVersion: fact.causalHeadsFormatVersion,
      data: fact.causalHeadsData
    )
  }

  func kitchenID(_ fixture: SessionLogicFixture) throws -> Kitchen.ID {
    try XCTUnwrap(fixture.repository.evidence(id: fixture.sessionID)?.roots.first?.kitchenID)
  }

  func uuidOrder(_ lhs: UUID, _ rhs: UUID) -> Bool {
    lhs.uuidString < rhs.uuidString
  }

  func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0007-%012d", value))!
  }
}
