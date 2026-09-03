// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

// This matrix is intentionally kept together so classifications can be audited
// against one fixture instead of being scattered by storage record type.
// swiftlint:disable file_length
// swiftlint:disable type_body_length
final class CookingSessionRecoveryMatrixTests: XCTestCase {
    // The matrix intentionally keeps related corruptions together so every row
    // is visibly compared with the same known-good Closure.
    // swiftlint:disable:next function_body_length
    func testClosureValidationMatrix() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let base = try closure(fixture: fixture, projection: active)

        assertRecovery(
            fixture.result(closures: [closure(base, kitchenID: Kitchen.ID(rawValue: id(901)))]),
            .crossSessionReference
        )
        assertRecovery(
            fixture.result(closures: [closure(base, snapshotDigest: Data(repeating: 1, count: 32))]),
            .inconsistentClosure
        )
        assertUnavailable(
            fixture.result(closures: [closure(base, causalHeadsFormatVersion: 99)]),
            .unsupportedCausalHeadsFormat(99)
        )
        assertRecovery(
            fixture.result(closures: [closure(base, causalHeadsData: Data([1]))]),
            .malformedCausalHeads
        )
        assertUnavailable(
            fixture.result(closures: [closure(base, causalHeadsData: CausalHeadsCodec.encode([id(902)]).data)]),
            .missingPredecessor(id(902))
        )
        assertRecovery(
            fixture.result(closures: [closure(base, causalHeadsData: Data())]),
            .inconsistentClosure
        )
        assertUnavailable(
            fixture.result(closures: [closure(base, projectionFormatVersion: 99)]),
            .unsupportedProjectionFormat(99)
        )

        let collision = closure(base, finishedAt: Date(timeIntervalSince1970: 999))
        assertRecovery(fixture.result(closures: [base, collision]), .closureCollision)

        let unselected = try closure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(903)),
            projection: active
        )
        assertRecovery(
            fixture.result(closures: [base, closure(unselected, causalHeadsData: Data([1]))]),
            .malformedCausalHeads
        )
        assertRecovery(
            fixture.result(
                closures: [
                    base,
                    closure(unselected, projectionDigest: Data(repeating: 7, count: 32)),
                ]
            ),
            .inconsistentClosure
        )
        assertRecovery(
            fixture.result(
                closures: [base, closure(unselected, outcomeData: .some(Data("{}".utf8)))]
            ),
            .inconsistentClosure
        )
    }

    // swiftlint:disable:next function_body_length
    func testClosureOutcomeValidationMatrix() throws {
        let fixture = try FactFixture()
        let outcomeFact = try fixture.fact(
            id: id(910),
            kind: .sessionOutcome,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionOutcome(.set(.coarse(.great)))
        )
        let projected = try fixture.project(facts: [outcomeFact])
        let encodedOutcome = try SessionOutcomeCodec.encode(.coarse(.great))
        let base = try closure(
            fixture: fixture,
            heads: [outcomeFact.id.rawValue],
            projection: projected,
            outcomeFormatVersion: encodedOutcome.formatVersion,
            outcomeData: encodedOutcome.data
        )

        guard case let .session(session) = fixture.result(
            facts: [outcomeFact], closures: [base]
        ) else {
            XCTFail("Expected matching encoded outcome")
            return
        }
        XCTAssertEqual(session.outcome, .coarse(.great))
        assertUnavailable(
            fixture.result(
                facts: [outcomeFact],
                closures: [closure(base, outcomeFormatVersion: 99)]
            ),
            .unsupportedOutcomeFormat(99)
        )
        assertRecovery(
            fixture.result(
                facts: [outcomeFact],
                closures: [closure(base, outcomeData: Data("{}".utf8))]
            ),
            .inconsistentClosure
        )
        assertRecovery(
            fixture.result(
                facts: [outcomeFact],
                closures: [closure(base, outcomeData: .some(nil as Data?))]
            ),
            .inconsistentClosure
        )
        let mismatchedOutcome = try SessionOutcomeCodec.encode(.coarse(.okay))
        assertRecovery(
            fixture.result(
                facts: [outcomeFact],
                closures: [closure(base, outcomeData: mismatchedOutcome.data)]
            ),
            .inconsistentClosure
        )
    }

    func testClosureCannotCommitAnUnresolvedProjectionConflict() throws {
        let fixture = try FactFixture()
        let great = try fixture.fact(
            id: id(911),
            kind: .sessionOutcome,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionOutcome(.set(.coarse(.great)))
        )
        let okay = try fixture.fact(
            id: id(912),
            kind: .sessionOutcome,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionOutcome(.set(.coarse(.okay)))
        )
        let conflicted = try fixture.project(facts: [great, okay])
        let conflictedClosure = try closure(
            fixture: fixture,
            heads: [great.id.rawValue, okay.id.rawValue],
            projection: conflicted
        )

        assertRecovery(
            fixture.result(facts: [great, okay], closures: [conflictedClosure]),
            .inconsistentClosure
        )
    }

    func testClosureHeadsMustBeAMaximalFrontier() throws {
        let fixture = try FactFixture()
        let stop = try fixture.fact(
            id: id(915), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        let resume = try fixture.fact(
            id: id(916), kind: .resume, heads: [stop.id.rawValue], payload: .empty
        )
        let active = try fixture.project(facts: [stop, resume])
        let redundant = try closure(
            fixture: fixture,
            heads: [stop.id.rawValue, resume.id.rawValue],
            projection: active
        )

        assertRecovery(
            fixture.result(facts: [stop, resume], closures: [redundant]),
            .inconsistentClosure
        )
    }

    func testDeletionCanNameClosureSessionHead() throws {
        let fixture = try FactFixture()
        let stop = try fixture.fact(
            id: id(913), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        let stopped = try fixture.project(facts: [stop])
        let finished = try closure(
            fixture: fixture,
            heads: [stop.id.rawValue],
            projection: stopped
        )
        let sessionHeads = CausalHeadsCodec.encode([finished.id.rawValue])
        let deletion = SessionDeletionEvidence(
            id: SessionDeletion.ID(rawValue: id(914)),
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            deletedAt: Date(timeIntervalSince1970: 600),
            sessionHeadsFormatVersion: sessionHeads.formatVersion,
            sessionHeadsData: sessionHeads.data,
            dispositionHeadsFormatVersion: CausalHeadsCodec.formatVersion,
            dispositionHeadsData: Data()
        )

        guard case let .session(session) = fixture.result(
            facts: [stop], closures: [finished], deletions: [deletion]
        ) else {
            XCTFail("Expected a deleted Finished Session")
            return
        }
        XCTAssertEqual(session.lifecycle, .finished)
        XCTAssertEqual(session.disposition, .deleted(needsAttention: false))
    }

    func testDeletionSessionHeadsMustBeAMaximalFrontier() throws {
        let fixture = try FactFixture()
        let stop = try fixture.fact(
            id: id(917), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        let deletion = makeDeletion(fixture: fixture, id: id(918), dispositionHeads: [])
        let redundantHeads = CausalHeadsCodec.encode([
            fixture.sessionID.rawValue, stop.id.rawValue
        ])

        assertRecovery(
            fixture.result(
                facts: [stop],
                deletions: [replacingDeletion(deletion, sessionHeadsData: redundantHeads.data)]
            ),
            .invalidDeletionDisposition
        )
    }

    // swiftlint:disable:next function_body_length
    func testDeletionValidationMatrix() throws {
        let fixture = try FactFixture()
        let deletion = makeDeletion(fixture: fixture, id: id(920), dispositionHeads: [])
        XCTAssertEqual(
            fixture.result(deletions: [deletion]),
            fixture.result(deletions: [deletion, deletion])
        )
        assertRecovery(
            fixture.result(deletions: [
                deletion,
                makeDeletion(
                    fixture: fixture,
                    id: id(920),
                    dispositionHeads: [id(920)],
                ),
            ]),
            .deletionCollision
        )

        let wrongSession = SessionDeletionEvidence(
            id: deletion.id,
            sessionID: CookingSession.ID(rawValue: id(921)),
            kitchenID: deletion.kitchenID,
            deletedAt: deletion.deletedAt,
            sessionHeadsFormatVersion: deletion.sessionHeadsFormatVersion,
            sessionHeadsData: deletion.sessionHeadsData,
            dispositionHeadsFormatVersion: deletion.dispositionHeadsFormatVersion,
            dispositionHeadsData: deletion.dispositionHeadsData
        )
        assertRecovery(fixture.result(deletions: [wrongSession]), .crossSessionReference)
        let wrongKitchen = SessionDeletionEvidence(
            id: deletion.id,
            sessionID: deletion.sessionID,
            kitchenID: Kitchen.ID(rawValue: id(925)),
            deletedAt: deletion.deletedAt,
            sessionHeadsFormatVersion: deletion.sessionHeadsFormatVersion,
            sessionHeadsData: deletion.sessionHeadsData,
            dispositionHeadsFormatVersion: deletion.dispositionHeadsFormatVersion,
            dispositionHeadsData: deletion.dispositionHeadsData
        )
        assertRecovery(fixture.result(deletions: [wrongKitchen]), .crossSessionReference)
        let missingSessionHead = CausalHeadsCodec.encode([id(926)]).data
        assertUnavailable(
            fixture.result(deletions: [
                replacingDeletion(
                    deletion,
                    sessionHeadsData: missingSessionHead,
                ),
            ]),
            .incompleteDeletionDisposition(id(926))
        )
        assertUnavailable(
            fixture.result(deletions: [
                replacingDeletion(
                    deletion,
                    dispositionHeadsFormatVersion: 99,
                ),
            ]),
            .unsupportedCausalHeadsFormat(99)
        )
        assertRecovery(
            fixture.result(deletions: [
                replacingDeletion(
                    deletion,
                    dispositionHeadsData: Data([1]),
                ),
            ]),
            .invalidDeletionDisposition
        )
        let cycle = makeDeletion(fixture: fixture, id: id(922), dispositionHeads: [id(922)])
        assertRecovery(fixture.result(deletions: [cycle]), .invalidDeletionDisposition)
        let ancestorDeletion = makeDeletion(
            fixture: fixture, id: id(927), dispositionHeads: []
        )
        let descendantDeletion = makeDeletion(
            fixture: fixture,
            id: id(928),
            dispositionHeads: [ancestorDeletion.id.rawValue]
        )
        let redundantHeads = makeDeletion(
            fixture: fixture,
            id: id(929),
            dispositionHeads: [ancestorDeletion.id.rawValue, descendantDeletion.id.rawValue]
        )
        assertRecovery(
            fixture.result(
                deletions: [ancestorDeletion, descendantDeletion, redundantHeads]
            ),
            .invalidDeletionDisposition
        )

        let orphan = makeRestoration(
            fixture: fixture,
            id: id(923),
            deletionID: SessionDeletion.ID(rawValue: id(999)),
            dispositionHeads: [deletion.id.rawValue]
        )
        assertRecovery(
            fixture.result(deletions: [deletion], restorations: [orphan]),
            .invalidDeletionDisposition
        )
        let restorationCollision = makeRestoration(
            fixture: fixture,
            id: id(924),
            deletionID: deletion.id,
            dispositionHeads: [deletion.id.rawValue]
        )
        let changed = restoration(
            restorationCollision,
            restoredAt: Date(timeIntervalSince1970: 999)
        )
        assertRecovery(
            fixture.result(
                deletions: [deletion],
                restorations: [restorationCollision, changed]
            ),
            .restorationCollision
        )
    }

    func testMultipleMissingDispositionPredecessorsUseCanonicalReasonAcrossArrivalOrders() throws {
        let fixture = try FactFixture()
        let lowerMissingID = id(940)
        let higherMissingID = id(941)
        let first = makeDeletion(
            fixture: fixture,
            id: id(930),
            dispositionHeads: [higherMissingID]
        )
        let second = makeDeletion(
            fixture: fixture,
            id: id(931),
            dispositionHeads: [lowerMissingID]
        )

        assertUnavailable(
            fixture.result(deletions: [first, second]),
            .incompleteDeletionDisposition(lowerMissingID)
        )
        assertUnavailable(
            fixture.result(deletions: [second, first]),
            .incompleteDeletionDisposition(lowerMissingID)
        )
    }

    private func closure(
        fixture: FactFixture,
        id: SessionClosure.ID = SessionClosure.ID(rawValue: id(900)),
        heads: [UUID] = [],
        projection: CookingSessionProjection,
        outcomeFormatVersion: Int? = nil,
        outcomeData: Data? = nil
    ) throws -> SessionClosureEvidence {
        let encodedProjection = try ClosedSessionProjectionCodec.encode(
            ClosedSessionProjection(projection)
        )
        return SessionClosureEvidence(
            id: id,
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            finishedAt: Date(timeIntervalSince1970: 300),
            causalHeadsFormatVersion: CausalHeadsCodec.formatVersion,
            causalHeadsData: CausalHeadsCodec.encode(
                heads.isEmpty ? [fixture.sessionID.rawValue] : heads
            ).data,
            snapshotFormatVersion: fixture.root.snapshotFormatVersion,
            snapshotDigest: fixture.root.snapshotDigest,
            projectionFormatVersion: encodedProjection.formatVersion,
            projectionDigest: encodedProjection.digest,
            outcomeFormatVersion: outcomeFormatVersion,
            outcomeData: outcomeData
        )
    }

    // Optional override parameters deliberately use the base value when nil;
    // outcomeData is the exception because the matrix must create an unpaired nil.
    private func closure(
        _ base: SessionClosureEvidence,
        kitchenID: Kitchen.ID? = nil,
        finishedAt: Date? = nil,
        causalHeadsFormatVersion: Int? = nil,
        causalHeadsData: Data? = nil,
        snapshotDigest: Data? = nil,
        projectionFormatVersion: Int? = nil,
        projectionDigest: Data? = nil,
        outcomeFormatVersion: Int? = nil,
        outcomeData: Data?? = nil
    ) -> SessionClosureEvidence {
        SessionClosureEvidence(
            id: base.id,
            sessionID: base.sessionID,
            kitchenID: kitchenID ?? base.kitchenID,
            finishedAt: finishedAt ?? base.finishedAt,
            causalHeadsFormatVersion: causalHeadsFormatVersion ?? base.causalHeadsFormatVersion,
            causalHeadsData: causalHeadsData ?? base.causalHeadsData,
            snapshotFormatVersion: base.snapshotFormatVersion,
            snapshotDigest: snapshotDigest ?? base.snapshotDigest,
            projectionFormatVersion: projectionFormatVersion ?? base.projectionFormatVersion,
            projectionDigest: projectionDigest ?? base.projectionDigest,
            outcomeFormatVersion: outcomeFormatVersion ?? base.outcomeFormatVersion,
            outcomeData: outcomeData ?? base.outcomeData
        )
    }

    private func makeDeletion(
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

    private func replacingDeletion(
        _ base: SessionDeletionEvidence,
        sessionHeadsData: Data? = nil,
        dispositionHeadsFormatVersion: Int? = nil,
        dispositionHeadsData: Data? = nil
    ) -> SessionDeletionEvidence {
        SessionDeletionEvidence(
            id: base.id,
            sessionID: base.sessionID,
            kitchenID: base.kitchenID,
            deletedAt: base.deletedAt,
            sessionHeadsFormatVersion: base.sessionHeadsFormatVersion,
            sessionHeadsData: sessionHeadsData ?? base.sessionHeadsData,
            dispositionHeadsFormatVersion: dispositionHeadsFormatVersion
                ?? base.dispositionHeadsFormatVersion,
            dispositionHeadsData: dispositionHeadsData ?? base.dispositionHeadsData
        )
    }

    private func makeRestoration(
        fixture: FactFixture,
        id: UUID,
        deletionID: SessionDeletion.ID,
        dispositionHeads: [UUID]
    ) -> SessionDeletionResolutionEvidence {
        SessionDeletionResolutionEvidence(
            id: SessionDeletionResolution.ID(rawValue: id),
            deletionID: deletionID,
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            restoredAt: Date(timeIntervalSince1970: 500),
            dispositionHeadsFormatVersion: CausalHeadsCodec.formatVersion,
            dispositionHeadsData: CausalHeadsCodec.encode(dispositionHeads).data
        )
    }

    private func restoration(
        _ base: SessionDeletionResolutionEvidence,
        restoredAt: Date
    ) -> SessionDeletionResolutionEvidence {
        SessionDeletionResolutionEvidence(
            id: base.id,
            deletionID: base.deletionID,
            sessionID: base.sessionID,
            kitchenID: base.kitchenID,
            restoredAt: restoredAt,
            dispositionHeadsFormatVersion: base.dispositionHeadsFormatVersion,
            dispositionHeadsData: base.dispositionHeadsData
        )
    }

    private func assertUnavailable(
        _ result: SessionProjectionResult,
        _ reason: UnavailableSession.Reason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .unavailable(value) = result else {
            XCTFail("Expected Unavailable, received \(result)", file: file, line: line)
            return
        }
        XCTAssertEqual(value.reasons, [reason], file: file, line: line)
    }

    private func assertRecovery(
        _ result: SessionProjectionResult,
        _ reason: SessionRecovery.Reason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .recovery(value) = result else {
            XCTFail("Expected Recovery, received \(result)", file: file, line: line)
            return
        }
        XCTAssertEqual(value.reasons, [reason], file: file, line: line)
    }
}
// swiftlint:enable type_body_length

private extension FactFixture {
    func result(
        closures: [SessionClosureEvidence] = [],
        deletions: [SessionDeletionEvidence] = [],
        restorations: [SessionDeletionResolutionEvidence] = []
    ) -> SessionProjectionResult {
        result(facts: [], closures: closures, deletions: deletions, restorations: restorations)
    }
}
// swiftlint:enable file_length
