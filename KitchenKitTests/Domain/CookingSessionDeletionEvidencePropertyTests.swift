// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

final class SessionDeletionPropertyTests: XCTestCase {
    // Gate B attacks deletion with duplication, reordering, partial arrival,
    // orphaning, and identity collision. The oracle is retained evidence plus
    // deterministic, nonordinary failure rather than a preferred UI state.
    // swiftlint:disable:next function_body_length
    func testGateBFuzzNeverLosesEvidenceOrSilentlyResurrects() throws {
        let fixture = try FactFixture()
        var generator = try generator()
        let firstDelete = deletion(fixture: fixture, id: id(201), dispositionHeads: [])
        let restore = restoration(
            fixture: fixture,
            id: id(202),
            deletion: firstDelete,
            dispositionHeads: [firstDelete.id.rawValue]
        )
        let laterDelete = deletion(
            fixture: fixture,
            id: id(203),
            dispositionHeads: [restore.id.rawValue]
        )
        let complete = SessionEvidence(
            sessionID: fixture.sessionID,
            roots: [fixture.root],
            deletions: [firstDelete, laterDelete],
            restorations: [restore]
        )
        let expected = SessionEvidenceProjector.project(complete)
        guard case let .session(deleted) = expected else {
            XCTFail("Expected complete retained evidence to remain deleted")
            return
        }
        XCTAssertEqual(deleted.disposition, .deleted(needsAttention: false))

        for _ in 0..<128 {
            let delivered = SessionEvidence(
                sessionID: fixture.sessionID,
                roots: shuffled(retried(complete.roots, using: &generator), using: &generator),
                deletions: shuffled(
                    retried(complete.deletions, using: &generator),
                    using: &generator
                ),
                restorations: shuffled(
                    retried(complete.restorations, using: &generator),
                    using: &generator
                )
            )
            XCTAssertEqual(SessionEvidenceProjector.project(delivered), expected)
            XCTAssertEqual(SessionEvidenceProjector.project(delivered), expected)
        }

        let concurrentDelete = deletion(fixture: fixture, id: id(204), dispositionHeads: [])
        guard case let .session(attention) = fixture.result(
            facts: [],
            deletions: [firstDelete, concurrentDelete],
            restorations: [restore]
        ) else {
            XCTFail("Concurrent Delete and Restore must remain reconstructable")
            return
        }
        XCTAssertEqual(attention.disposition, SessionDisposition.deleted(needsAttention: true))

        let orphan = SessionEvidence(
            sessionID: fixture.sessionID,
            roots: [fixture.root],
            restorations: [restore]
        )
        guard case let .unavailable(unavailable) = SessionEvidenceProjector.project(orphan) else {
            XCTFail("Orphaned Restore must wait for its Delete")
            return
        }
        XCTAssertEqual(unavailable.evidence, orphan)

        let collision = SessionDeletionEvidence(
            id: firstDelete.id,
            sessionID: firstDelete.sessionID,
            kitchenID: firstDelete.kitchenID,
            deletedAt: firstDelete.deletedAt.addingTimeInterval(1),
            sessionHeadsFormatVersion: firstDelete.sessionHeadsFormatVersion,
            sessionHeadsData: firstDelete.sessionHeadsData,
            dispositionHeadsFormatVersion: firstDelete.dispositionHeadsFormatVersion,
            dispositionHeadsData: firstDelete.dispositionHeadsData
        )
        let collided = SessionEvidence(
            sessionID: fixture.sessionID,
            roots: [fixture.root],
            deletions: [firstDelete, collision]
        )
        guard case let .recovery(recovery) = SessionEvidenceProjector.project(collided) else {
            XCTFail("Logical identity collision must enter Recovery")
            return
        }
        XCTAssertEqual(recovery.evidence, collided)

        let rootMissing = SessionEvidence(
            sessionID: fixture.sessionID,
            deletions: [firstDelete]
        )
        guard case let .unavailable(waiting) = SessionEvidenceProjector.project(rootMissing) else {
            XCTFail("A Delete arriving before its root must stay retained and unavailable")
            return
        }
        XCTAssertEqual(waiting.evidence, rootMissing)
    }

    private func deletion(
        fixture: FactFixture,
        id: UUID,
        dispositionHeads: [UUID]
    ) -> SessionDeletionEvidence {
        SessionDeletionEvidence(
            id: SessionDeletion.ID(rawValue: id),
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            deletedAt: Date(timeIntervalSince1970: 400),
            sessionHeadsFormatVersion: CausalHeadsCodec.formatVersion,
            sessionHeadsData: CausalHeadsCodec.encode([fixture.sessionID.rawValue]).data,
            dispositionHeadsFormatVersion: CausalHeadsCodec.formatVersion,
            dispositionHeadsData: CausalHeadsCodec.encode(dispositionHeads).data
        )
    }

    private func restoration(
        fixture: FactFixture,
        id: UUID,
        deletion: SessionDeletionEvidence,
        dispositionHeads: [UUID]
    ) -> SessionDeletionResolutionEvidence {
        SessionDeletionResolutionEvidence(
            id: SessionDeletionResolution.ID(rawValue: id),
            deletionID: deletion.id,
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            restoredAt: Date(timeIntervalSince1970: 500),
            dispositionHeadsFormatVersion: CausalHeadsCodec.formatVersion,
            dispositionHeadsData: CausalHeadsCodec.encode(dispositionHeads).data
        )
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
