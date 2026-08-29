// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import XCTest

final class CookingSessionEvidencePropertyTests: XCTestCase {
    func testEvidenceUnionIsAssociativeCommutativeAndIdempotent() throws {
        let fixture = try FactFixture()
        let facts = try makeIndependentFacts(fixture: fixture)
        var generator = try generator()

        for _ in 0..<64 {
            let first = shuffled(facts, using: &generator)
            let second = shuffled(facts + facts, using: &generator)
            let partition = generator.int(in: 0...facts.count)
            let left = Array(first[..<partition])
            let right = Array(first[partition...])

            XCTAssertEqual(fixture.result(facts: first), fixture.result(facts: second))
            XCTAssertEqual(fixture.result(facts: left + right), fixture.result(facts: right + left))
            XCTAssertEqual(
                fixture.result(facts: (left + right) + facts),
                fixture.result(facts: left + (right + facts))
            )
        }
    }

    func testStableRetriesAndOmissionsClassifyDeterministically() throws {
        let fixture = try FactFixture()
        let stop = try fixture.fact(
            id: id(81),
            kind: .stop,
            heads: [fixture.sessionID.rawValue],
            payload: .empty
        )
        let resume = try fixture.fact(
            id: id(82),
            kind: .resume,
            heads: [stop.id.rawValue],
            payload: .empty
        )
        let missing = fixture.result(facts: [resume])

        XCTAssertEqual(missing, fixture.result(facts: [resume]))
        guard case let .unavailable(value) = missing else {
            XCTFail("Omitted predecessor must be unavailable")
            return
        }
        XCTAssertEqual(value.reasons, [.missingPredecessor(stop.id.rawValue)])
        XCTAssertEqual(fixture.result(facts: [stop, resume]), fixture.result(facts: [resume, stop]))
    }

    // Generates a bounded complete envelope spanning every Slice 11 evidence
    // family, then perturbs physical delivery without changing logical union.
    // swiftlint:disable:next function_body_length
    func testSeededBoundedEvidenceEnvelopeConvergesAcrossDeliveryShapes() throws {
        let fixture = try FactFixture()
        var generator = try generator()
        let stop = try fixture.fact(
            id: generator.uuid(),
            kind: .stop,
            heads: [fixture.sessionID.rawValue],
            payload: .empty
        )
        let stopped = try fixture.project(facts: [stop])
        let closureID = SessionClosure.ID(rawValue: generator.uuid())
        let encodedProjection = try ClosedSessionProjectionCodec.encode(
            ClosedSessionProjection(stopped)
        )
        let closureHeads = CausalHeadsCodec.encode([stop.id.rawValue])
        let closure = SessionClosureEvidence(
            id: closureID,
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            finishedAt: Date(timeIntervalSince1970: 300),
            causalHeadsFormatVersion: closureHeads.formatVersion,
            causalHeadsData: closureHeads.data,
            snapshotFormatVersion: fixture.root.snapshotFormatVersion,
            snapshotDigest: fixture.root.snapshotDigest,
            projectionFormatVersion: encodedProjection.formatVersion,
            projectionDigest: encodedProjection.digest,
            outcomeFormatVersion: nil,
            outcomeData: nil
        )
        let deletionID = SessionDeletion.ID(rawValue: generator.uuid())
        let deletion = SessionDeletionEvidence(
            id: deletionID,
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            deletedAt: Date(timeIntervalSince1970: 400),
            sessionHeadsFormatVersion: CausalHeadsCodec.formatVersion,
            sessionHeadsData: CausalHeadsCodec.encode([closureID.rawValue]).data,
            dispositionHeadsFormatVersion: CausalHeadsCodec.formatVersion,
            dispositionHeadsData: Data()
        )
        let restoration = SessionDeletionResolutionEvidence(
            id: SessionDeletionResolution.ID(rawValue: generator.uuid()),
            deletionID: deletionID,
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            restoredAt: Date(timeIntervalSince1970: 500),
            dispositionHeadsFormatVersion: CausalHeadsCodec.formatVersion,
            dispositionHeadsData: CausalHeadsCodec.encode([deletionID.rawValue]).data
        )
        let complete = SessionEvidence(
            sessionID: fixture.sessionID,
            roots: [fixture.root],
            facts: [stop],
            closures: [closure],
            deletions: [deletion],
            restorations: [restoration]
        )
        let expected = SessionEvidenceProjector.project(complete)

        for _ in 0..<64 {
            let delivered = SessionEvidence(
                sessionID: fixture.sessionID,
                roots: shuffled(retried(complete.roots, using: &generator), using: &generator),
                facts: shuffled(retried(complete.facts, using: &generator), using: &generator),
                closures: shuffled(retried(complete.closures, using: &generator), using: &generator),
                deletions: shuffled(retried(complete.deletions, using: &generator), using: &generator),
                restorations: shuffled(
                    retried(complete.restorations, using: &generator),
                    using: &generator
                )
            )
            XCTAssertEqual(SessionEvidenceProjector.project(delivered), expected)
        }

        guard case .unavailable = SessionEvidenceProjector.project(
            SessionEvidence(
                sessionID: fixture.sessionID,
                roots: [fixture.root],
                facts: [stop],
                closures: [closure],
                restorations: [restoration]
            )
        ) else {
            XCTFail("Omitted deletion predecessor must be unavailable")
            return
        }
    }

    private func makeIndependentFacts(fixture: FactFixture) throws -> [SessionFactEvidence] {
        let stop = try fixture.fact(
            id: id(71), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        let resume = try fixture.fact(
            id: id(72), kind: .resume, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        let outcome = try fixture.fact(
            id: id(73),
            kind: .sessionOutcome,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionOutcome(.set(.coarse(.okay)))
        )
        return [stop, resume, outcome]
    }

    private func generator() throws -> SeededGenerator {
        let seed = try PropertyTestSeeds.bundled().seed(named: .domainSessionEvidence)
        return SeededGenerator(seed: seed.value)
    }

    private func shuffled<Value>(
        _ values: [Value],
        using generator: inout SeededGenerator
    ) -> [Value] {
        var result = values
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            result.swapAt(index, generator.int(in: 0...index))
        }
        return result
    }

    private func retried<Value>(
        _ values: [Value],
        using generator: inout SeededGenerator
    ) -> [Value] {
        generator.bool() ? values + values : values
    }
}
