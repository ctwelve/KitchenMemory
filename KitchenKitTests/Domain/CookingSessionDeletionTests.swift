// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenKit
import Foundation
import XCTest

final class CookingSessionDeletionTests: XCTestCase {
    func testDeleteHidesWithoutChangingLifecycleAndRestoreRevealsIt() throws {
        let fixture = try FactFixture()
        let deletion = makeDeletion(fixture: fixture, id: id(81), dispositionHeads: [])

        guard case let .session(deleted) = fixture.result(
            facts: [], deletions: [deletion]
        ) else {
            XCTFail("Expected a complete deleted Session")
            return
        }
        XCTAssertEqual(deleted.lifecycle, .active)
        XCTAssertEqual(deleted.disposition, .deleted(needsAttention: false))

        let restoration = makeRestoration(
            fixture: fixture,
            id: id(82),
            deletion: deletion,
            dispositionHeads: [deletion.id.rawValue]
        )
        guard case let .session(restored) = fixture.result(
            facts: [], deletions: [deletion], restorations: [restoration]
        ) else {
            XCTFail("Expected a restored Session")
            return
        }
        XCTAssertEqual(restored.disposition, .ordinary)
    }

    func testConcurrentDeleteAndRestoreStayDeletedWithNeedsAttention() throws {
        let fixture = try FactFixture()
        let firstDelete = makeDeletion(fixture: fixture, id: id(81), dispositionHeads: [])
        let restoration = makeRestoration(
            fixture: fixture,
            id: id(82),
            deletion: firstDelete,
            dispositionHeads: [firstDelete.id.rawValue]
        )
        let concurrentDelete = makeDeletion(fixture: fixture, id: id(83), dispositionHeads: [])

        guard case let .session(session) = fixture.result(
            facts: [],
            deletions: [concurrentDelete, firstDelete],
            restorations: [restoration]
        ) else {
            XCTFail("Expected a complete deleted Session")
            return
        }
        XCTAssertEqual(session.disposition, .deleted(needsAttention: true))
    }

    func testMissingDispositionPredecessorWithholdsOrdinaryPresentation() throws {
        let fixture = try FactFixture()
        let missingID = id(99)
        let deletion = makeDeletion(
            fixture: fixture,
            id: id(81),
            dispositionHeads: [missingID]
        )

        guard case let .unavailable(unavailable) = fixture.result(
            facts: [], deletions: [deletion]
        ) else {
            XCTFail("Expected Unavailable")
            return
        }
        XCTAssertEqual(unavailable.reasons, [.incompleteDeletionDisposition(missingID)])
    }

    private func makeDeletion(
        fixture: FactFixture,
        id: UUID,
        dispositionHeads: [UUID]
    ) -> SessionDeletionEvidence {
        let sessionHeads = CausalHeadsCodec.encode([fixture.sessionID.rawValue])
        let disposition = CausalHeadsCodec.encode(dispositionHeads)
        return SessionDeletionEvidence(
            id: SessionDeletion.ID(rawValue: id),
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            deletedAt: Date(timeIntervalSince1970: 400),
            sessionHeadsFormatVersion: sessionHeads.formatVersion,
            sessionHeadsData: sessionHeads.data,
            dispositionHeadsFormatVersion: disposition.formatVersion,
            dispositionHeadsData: disposition.data
        )
    }

    private func makeRestoration(
        fixture: FactFixture,
        id: UUID,
        deletion: SessionDeletionEvidence,
        dispositionHeads: [UUID]
    ) -> SessionDeletionResolutionEvidence {
        let disposition = CausalHeadsCodec.encode(dispositionHeads)
        return SessionDeletionResolutionEvidence(
            id: SessionDeletionResolution.ID(rawValue: id),
            deletionID: deletion.id,
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            restoredAt: Date(timeIntervalSince1970: 500),
            dispositionHeadsFormatVersion: disposition.formatVersion,
            dispositionHeadsData: disposition.data
        )
    }
}
