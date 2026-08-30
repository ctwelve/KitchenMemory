// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenKit
import Foundation
import XCTest

// swiftlint:disable file_length
// swiftlint:disable type_body_length
final class CookingSessionClosureTests: XCTestCase {
    func testClosureFinishesObservedFrontierWithoutErasingLateEvidence() throws {
        let fixture = try FactFixture()
        let stop = try fixture.fact(
            id: id(71),
            kind: .stop,
            heads: [fixture.sessionID.rawValue],
            payload: .empty
        )
        let lateResume = try fixture.fact(
            id: id(72),
            kind: .resume,
            heads: [fixture.sessionID.rawValue],
            payload: .empty
        )
        let stopped = try fixture.project(facts: [stop])
        let closure = try makeClosure(
            fixture: fixture,
            heads: [stop.id.rawValue],
            projection: stopped
        )

        let result = fixture.result(facts: [lateResume, stop], closures: [closure])

        guard case let .session(session) = result else {
            XCTFail("Expected Finished Session, received \(result)")
            return
        }
        XCTAssertEqual(session.lifecycle, .finished)
        XCTAssertEqual(session.lifecycleBeforeFinish, .stopped)
        XCTAssertEqual(session.selectedClosureID, closure.id)
        XCTAssertEqual(session.lateEvidence, [lateResume.id])
    }

    func testInconsistentClosureProjectionRequiresRecovery() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        var closure = try makeClosure(
            fixture: fixture,
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        closure = closure.replacing(projectionDigest: Data(repeating: 9, count: 32))

        guard case let .recovery(recovery) = fixture.result(facts: [], closures: [closure]) else {
            XCTFail("Expected Recovery")
            return
        }
        XCTAssertEqual(recovery.reasons, [.inconsistentClosure])
    }

    func testCompetingClosuresRequireRecoveryInsteadOfTimestampSelection() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let first = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(73)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let second = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(74)),
            heads: [fixture.sessionID.rawValue],
            projection: active,
            finishedAt: Date(timeIntervalSince1970: 999)
        )

        guard case let .recovery(recovery) = fixture.result(
            facts: [], closures: [second, first]
        ) else {
            XCTFail("Expected Recovery")
            return
        }
        XCTAssertEqual(recovery.reasons, [.competingClosures])
        XCTAssertEqual(recovery.evidence.closures, [second, first])
    }

    func testResolutionFactSelectsFromCompleteCompetingClosureSet() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let first = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(73)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let second = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(74)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let resolution = try fixture.fact(
            id: id(75),
            kind: .conflictResolution,
            heads: [first.id.rawValue, second.id.rawValue],
            payload: .closureResolution(
                ClosureSelection(
                    selectedClosureID: first.id,
                    observedClosureIDs: [second.id, first.id]
                )
            )
        )

        guard case let .session(session) = fixture.result(
            facts: [resolution], closures: [second, first]
        ) else {
            XCTFail("Expected explicitly resolved Finished Session")
            return
        }
        XCTAssertEqual(session.lifecycle, .finished)
        XCTAssertEqual(session.selectedClosureID, first.id)
        XCTAssertTrue(session.lateEvidence.isEmpty)
    }

    func testWellFormedUnknownFactAfterClosureIsRetainedWithoutMutatingFinished() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let closure = try makeClosure(
            fixture: fixture,
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let encodedHeads = CausalHeadsCodec.encode([closure.id.rawValue])
        let payload = Data("future-payload".utf8)
        let unknown = SessionFactEvidence(
            id: SessionFact.ID(rawValue: id(76)),
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            kind: "future-kind",
            targetSnapshotElementID: nil,
            authoredAt: Date(timeIntervalSince1970: 400),
            causalHeadsFormatVersion: encodedHeads.formatVersion,
            causalHeadsData: encodedHeads.data,
            payloadFormatVersion: 42,
            payloadData: payload,
            payloadDigest: SessionDigest.sha256(payload)
        )
        let concurrentHeads = CausalHeadsCodec.encode([fixture.sessionID.rawValue])
        let concurrentUnknown = SessionFactEvidence(
            id: SessionFact.ID(rawValue: id(77)),
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            kind: "another-future-kind",
            targetSnapshotElementID: nil,
            authoredAt: Date(timeIntervalSince1970: 401),
            causalHeadsFormatVersion: concurrentHeads.formatVersion,
            causalHeadsData: concurrentHeads.data,
            payloadFormatVersion: 43,
            payloadData: payload,
            payloadDigest: SessionDigest.sha256(payload)
        )

        guard case let .session(session) = fixture.result(
            facts: [concurrentUnknown, unknown], closures: [closure]
        ) else {
            XCTFail("Expected the valid Closure to remain authoritative")
            return
        }
        XCTAssertEqual(session.lifecycle, .finished)
        XCTAssertEqual(session.lifecycleBeforeFinish, .active)
        XCTAssertEqual(session.lateEvidence, [unknown.id, concurrentUnknown.id])
    }

    func testUnknownFactAfterResolvedCompetingClosuresRemainsLateEvidence() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let first = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(73)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let second = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(74)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let resolution = try fixture.fact(
            id: id(75),
            kind: .conflictResolution,
            heads: [first.id.rawValue, second.id.rawValue],
            payload: .closureResolution(
                ClosureSelection(
                    selectedClosureID: first.id,
                    observedClosureIDs: [first.id, second.id]
                )
            )
        )
        let encodedHeads = CausalHeadsCodec.encode([resolution.id.rawValue])
        let payload = Data("future-payload".utf8)
        let unknown = SessionFactEvidence(
            id: SessionFact.ID(rawValue: id(76)),
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            kind: "future-kind",
            targetSnapshotElementID: nil,
            authoredAt: Date(timeIntervalSince1970: 400),
            causalHeadsFormatVersion: encodedHeads.formatVersion,
            causalHeadsData: encodedHeads.data,
            payloadFormatVersion: 42,
            payloadData: payload,
            payloadDigest: SessionDigest.sha256(payload)
        )

        guard case let .session(session) = fixture.result(
            facts: [unknown, resolution], closures: [second, first]
        ) else {
            XCTFail("Expected the resolved Finished Session to remain authoritative")
            return
        }
        XCTAssertEqual(session.selectedClosureID, first.id)
        XCTAssertEqual(session.lateEvidence, [unknown.id])
    }

    // An old complete selection remains retained evidence, while the newest
    // selection must explicitly cover the newly observed Closure set.
    func testExpandedClosureSetCanBeExplicitlyResolvedAgain() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let first = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(73)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let second = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(74)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let oldResolution = try fixture.fact(
            id: id(75),
            kind: .conflictResolution,
            heads: [first.id.rawValue, second.id.rawValue],
            payload: .closureResolution(
                ClosureSelection(
                    selectedClosureID: first.id,
                    observedClosureIDs: [first.id, second.id]
                )
            )
        )
        let third = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(78)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let newResolution = try fixture.fact(
            id: id(79),
            kind: .conflictResolution,
            heads: [first.id.rawValue, second.id.rawValue, third.id.rawValue],
            payload: .closureResolution(
                ClosureSelection(
                    selectedClosureID: third.id,
                    observedClosureIDs: [third.id, second.id, first.id]
                )
            )
        )

        guard case let .session(session) = fixture.result(
            facts: [newResolution, oldResolution],
            closures: [third, second, first]
        ) else {
            XCTFail("Expected the expanded Closure set to be resolved")
            return
        }
        XCTAssertEqual(session.selectedClosureID, third.id)
    }

    func testClosureResolutionCycleRequiresRecovery() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let firstID = SessionClosure.ID(rawValue: id(73))
        let secondID = SessionClosure.ID(rawValue: id(74))
        let resolution = try fixture.fact(
            id: id(75),
            kind: .conflictResolution,
            heads: [firstID.rawValue, secondID.rawValue],
            payload: .closureResolution(
                ClosureSelection(
                    selectedClosureID: firstID,
                    observedClosureIDs: [firstID, secondID]
                )
            )
        )
        let first = try makeClosure(
            fixture: fixture,
            id: firstID,
            heads: [resolution.id.rawValue],
            projection: active
        )
        let second = try makeClosure(
            fixture: fixture,
            id: secondID,
            heads: [fixture.sessionID.rawValue],
            projection: active
        )

        guard case let .recovery(recovery) = fixture.result(
            facts: [resolution], closures: [first, second]
        ) else {
            XCTFail("Expected Closure/Fact cycle recovery")
            return
        }
        XCTAssertEqual(recovery.reasons, [.cycle])
    }

    func testClosureCannotDescendAPriorClosureResolution() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let first = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(73)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let second = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(74)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let resolution = try fixture.fact(
            id: id(75),
            kind: .conflictResolution,
            heads: [first.id.rawValue, second.id.rawValue],
            payload: .closureResolution(
                ClosureSelection(
                    selectedClosureID: first.id,
                    observedClosureIDs: [first.id, second.id]
                )
            )
        )
        let refinish = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(76)),
            heads: [resolution.id.rawValue],
            projection: active
        )
        let secondResolution = try fixture.fact(
            id: id(77),
            kind: .conflictResolution,
            heads: [first.id.rawValue, second.id.rawValue, refinish.id.rawValue],
            payload: .closureResolution(
                ClosureSelection(
                    selectedClosureID: refinish.id,
                    observedClosureIDs: [first.id, second.id, refinish.id]
                )
            )
        )

        guard case let .recovery(recovery) = fixture.result(
            facts: [secondResolution, resolution],
            closures: [refinish, second, first]
        ) else {
            XCTFail("Expected re-finishing Recovery")
            return
        }
        XCTAssertEqual(recovery.reasons, [.inconsistentClosure])
    }

    func testKnownFactAfterClosureAndIncompleteResolutionRequireRecovery() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let first = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(73)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let second = try makeClosure(
            fixture: fixture,
            id: SessionClosure.ID(rawValue: id(74)),
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let lateStop = try fixture.fact(
            id: id(80), kind: .stop, heads: [first.id.rawValue], payload: .empty
        )
        guard case let .recovery(lateRecovery) = fixture.result(
            facts: [lateStop], closures: [first]
        ) else {
            XCTFail("Expected known post-Closure Fact recovery")
            return
        }
        XCTAssertEqual(lateRecovery.reasons, [.invalidFact])

        let incomplete = try fixture.fact(
            id: id(81),
            kind: .conflictResolution,
            heads: [first.id.rawValue],
            payload: .closureResolution(
                ClosureSelection(
                    selectedClosureID: first.id,
                    observedClosureIDs: [first.id]
                )
            )
        )
        guard case let .recovery(resolutionRecovery) = fixture.result(
            facts: [incomplete], closures: [first, second]
        ) else {
            XCTFail("Expected incomplete selection recovery")
            return
        }
        XCTAssertEqual(resolutionRecovery.reasons, [.invalidFact])
    }

    func testUnknownLateDigestMismatchRequiresRecovery() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let closure = try makeClosure(
            fixture: fixture,
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let heads = CausalHeadsCodec.encode([fixture.sessionID.rawValue])
        let unknown = SessionFactEvidence(
            id: SessionFact.ID(rawValue: id(82)),
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            kind: "future-kind",
            targetSnapshotElementID: nil,
            authoredAt: Date(timeIntervalSince1970: 500),
            causalHeadsFormatVersion: heads.formatVersion,
            causalHeadsData: heads.data,
            payloadFormatVersion: 99,
            payloadData: Data("future".utf8),
            payloadDigest: Data(repeating: 0, count: 32)
        )

        guard case let .recovery(recovery) = fixture.result(
            facts: [unknown], closures: [closure]
        ) else {
            XCTFail("Expected digest mismatch Recovery")
            return
        }
        XCTAssertEqual(recovery.reasons, [.digestMismatch])
    }

    func testUnknownLateFactStillRequiresCompleteCausalPredecessors() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let closure = try makeClosure(
            fixture: fixture,
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let missingID = id(999)
        let heads = CausalHeadsCodec.encode([missingID])
        let payload = Data("future".utf8)
        let unknown = SessionFactEvidence(
            id: SessionFact.ID(rawValue: id(83)),
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            kind: "future-kind",
            targetSnapshotElementID: nil,
            authoredAt: Date(timeIntervalSince1970: 500),
            causalHeadsFormatVersion: heads.formatVersion,
            causalHeadsData: heads.data,
            payloadFormatVersion: 99,
            payloadData: payload,
            payloadDigest: SessionDigest.sha256(payload)
        )

        guard case let .unavailable(unavailable) = fixture.result(
            facts: [unknown], closures: [closure]
        ) else {
            XCTFail("Expected missing predecessor Unavailable")
            return
        }
        XCTAssertEqual(unavailable.reasons, [.missingPredecessor(missingID)])
    }

    func testSupportedLateFactMayDescendFromPresentUnknownLateFact() throws {
        let fixture = try FactFixture()
        let active = try fixture.project(facts: [])
        let closure = try makeClosure(
            fixture: fixture,
            heads: [fixture.sessionID.rawValue],
            projection: active
        )
        let unknownID = SessionFact.ID(rawValue: id(84))
        let unknownHeads = CausalHeadsCodec.encode([fixture.sessionID.rawValue])
        let payload = Data("future".utf8)
        let unknown = SessionFactEvidence(
            id: unknownID,
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            kind: "future-kind",
            targetSnapshotElementID: nil,
            authoredAt: Date(timeIntervalSince1970: 500),
            causalHeadsFormatVersion: unknownHeads.formatVersion,
            causalHeadsData: unknownHeads.data,
            payloadFormatVersion: 99,
            payloadData: payload,
            payloadDigest: SessionDigest.sha256(payload)
        )
        let stop = try fixture.fact(
            id: id(85), kind: .stop, heads: [unknownID.rawValue], payload: .empty
        )

        guard case let .session(session) = fixture.result(
            facts: [stop, unknown], closures: [closure]
        ) else {
            XCTFail("Expected the complete late branch to remain retained")
            return
        }
        XCTAssertEqual(session.lifecycle, .finished)
        XCTAssertEqual(session.lifecycleBeforeFinish, .active)
        XCTAssertEqual(session.lateEvidence, [unknown.id, stop.id])
    }

    private func makeClosure(
        fixture: FactFixture,
        id: SessionClosure.ID = SessionClosure.ID(rawValue: id(73)),
        heads: [UUID],
        projection: CookingSessionProjection,
        finishedAt: Date = Date(timeIntervalSince1970: 300)
    ) throws -> SessionClosureEvidence {
        let encodedHeads = CausalHeadsCodec.encode(heads)
        let encodedProjection = try ClosedSessionProjectionCodec.encode(
            ClosedSessionProjection(projection)
        )
        return SessionClosureEvidence(
            id: id,
            sessionID: fixture.sessionID,
            kitchenID: fixture.kitchenID,
            finishedAt: finishedAt,
            causalHeadsFormatVersion: encodedHeads.formatVersion,
            causalHeadsData: encodedHeads.data,
            snapshotFormatVersion: fixture.root.snapshotFormatVersion,
            snapshotDigest: fixture.root.snapshotDigest,
            projectionFormatVersion: encodedProjection.formatVersion,
            projectionDigest: encodedProjection.digest,
            outcomeFormatVersion: nil,
            outcomeData: nil
        )
    }
}
// swiftlint:enable type_body_length

private extension SessionClosureEvidence {
    func replacing(projectionDigest: Data) -> Self {
        Self(
            id: id,
            sessionID: sessionID,
            kitchenID: kitchenID,
            finishedAt: finishedAt,
            causalHeadsFormatVersion: causalHeadsFormatVersion,
            causalHeadsData: causalHeadsData,
            snapshotFormatVersion: snapshotFormatVersion,
            snapshotDigest: snapshotDigest,
            projectionFormatVersion: projectionFormatVersion,
            projectionDigest: projectionDigest,
            outcomeFormatVersion: outcomeFormatVersion,
            outcomeData: outcomeData
        )
    }
}
