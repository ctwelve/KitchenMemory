// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import XCTest

final class CookingSessionEvidenceValidationTests: XCTestCase {
    func testFactDuplicatesCoalesceAndIdentityCollisionRequiresRecovery() throws {
        let fixture = try FactFixture()
        let stop = try fixture.fact(
            id: id(91), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        XCTAssertEqual(fixture.result(facts: [stop]), fixture.result(facts: [stop, stop]))

        let collision = replacing(stop, authoredAt: Date(timeIntervalSince1970: 999))
        assertRecovery(fixture.result(facts: [stop, collision]), .factCollision)
    }

    func testUnknownKindsAndFormatsAreUnavailable() throws {
        let fixture = try FactFixture()
        let stop = try fixture.fact(
            id: id(92), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )

        assertUnavailable(
            fixture.result(facts: [replacing(stop, kind: "future-kind")]),
            .unsupportedFactKind("future-kind")
        )
        assertUnavailable(
            fixture.result(facts: [replacing(stop, payloadFormatVersion: 99)]),
            .unsupportedPayloadFormat(99)
        )
        assertUnavailable(
            fixture.result(facts: [replacing(stop, causalHeadsFormatVersion: 99)]),
            .unsupportedCausalHeadsFormat(99)
        )
    }

    func testMalformedFactsAndCausalCyclesRequireRecovery() throws {
        let fixture = try FactFixture()
        let malformed = try fixture.fact(
            id: id(93), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        assertRecovery(
            fixture.result(facts: [replacing(malformed, causalHeadsData: Data([1]))]),
            .malformedCausalHeads
        )
        assertRecovery(
            fixture.result(facts: [replacing(malformed, payloadDigest: Data(repeating: 0, count: 32))]),
            .digestMismatch
        )
        let badPayload = Data("{}".utf8)
        assertRecovery(
            fixture.result(facts: [
                replacing(
                    malformed,
                    payloadData: badPayload,
                    payloadDigest: SessionDigest.sha256(badPayload),
                ),
            ]),
            .malformedPayload
        )

        let first = try fixture.fact(id: id(94), kind: .stop, heads: [id(95)], payload: .empty)
        let second = try fixture.fact(id: id(95), kind: .resume, heads: [id(94)], payload: .empty)
        assertRecovery(fixture.result(facts: [first, second]), .cycle)
    }

    func testInvalidPayloadPairingAndEntryHistoryRequireRecovery() throws {
        let fixture = try FactFixture()
        let mismatched = try fixture.fact(
            id: id(98),
            kind: .stop,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionOutcome(.clear)
        )
        assertRecovery(fixture.result(facts: [mismatched]), .invalidFact)

        let entryID = SessionEntry.ID(rawValue: id(99))
        let orphanRevision = try fixture.fact(
            id: id(100),
            kind: .sessionEntry,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionEntry(.revise(entryID: entryID, text: "No submit"))
        )
        assertRecovery(fixture.result(facts: [orphanRevision]), .invalidFact)
    }

    func testDiamondCausalGraphProjectsWithoutMistakingRevisitForCycle() throws {
        let fixture = try FactFixture()
        let common = try fixture.fact(
            id: id(110), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        let left = try fixture.fact(
            id: id(111), kind: .resume, heads: [common.id.rawValue], payload: .empty
        )
        let right = try fixture.fact(
            id: id(112), kind: .stop, heads: [common.id.rawValue], payload: .empty
        )
        let joined = try fixture.fact(
            id: id(113),
            kind: .resume,
            heads: [left.id.rawValue, right.id.rawValue],
            payload: .empty
        )

        guard case let .session(session) = fixture.result(
            facts: [joined, right, left, common]
        ) else {
            XCTFail("Expected an acyclic diamond graph")
            return
        }
        XCTAssertEqual(session.lifecycle, .active)
    }

    func testOrdinaryFactMustDescendFromSessionRoot() throws {
        let fixture = try FactFixture()
        let disconnected = try fixture.fact(
            id: id(114), kind: .stop, heads: [], payload: .empty
        )

        assertRecovery(fixture.result(facts: [disconnected]), .invalidFact)
    }

    func testCausalHeadsMustBeAMaximalFrontier() throws {
        let fixture = try FactFixture()
        let ancestor = try fixture.fact(
            id: id(115), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        let descendant = try fixture.fact(
            id: id(116), kind: .resume, heads: [ancestor.id.rawValue], payload: .empty
        )
        let redundant = try fixture.fact(
            id: id(117),
            kind: .stop,
            heads: [ancestor.id.rawValue, descendant.id.rawValue],
            payload: .empty
        )

        assertRecovery(
            fixture.result(facts: [redundant, descendant, ancestor]),
            .invalidFact
        )
    }

    func testCrossKitchenAndInvalidTargetRequireRecovery() throws {
        let fixture = try FactFixture()
        let stop = try fixture.fact(
            id: id(96), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        assertRecovery(
            fixture.result(facts: [replacing(stop, kitchenID: Kitchen.ID(rawValue: id(999)))]),
            .crossSessionReference
        )
        let invalid = try fixture.fact(
            id: id(97),
            kind: .progress,
            heads: [fixture.sessionID.rawValue],
            target: id(998),
            payload: .progress(.ingredient(.accounted))
        )
        assertRecovery(fixture.result(facts: [invalid]), .invalidFact)
    }

    private func replacing(
        _ fact: SessionFactEvidence,
        kitchenID: Kitchen.ID? = nil,
        kind: String? = nil,
        authoredAt: Date? = nil,
        causalHeadsFormatVersion: Int? = nil,
        causalHeadsData: Data? = nil,
        payloadFormatVersion: Int? = nil,
        payloadData: Data? = nil,
        payloadDigest: Data? = nil
    ) -> SessionFactEvidence {
        SessionFactEvidence(
            id: fact.id,
            sessionID: fact.sessionID,
            kitchenID: kitchenID ?? fact.kitchenID,
            kind: kind ?? fact.kind,
            targetSnapshotElementID: fact.targetSnapshotElementID,
            authoredAt: authoredAt ?? fact.authoredAt,
            causalHeadsFormatVersion: causalHeadsFormatVersion ?? fact.causalHeadsFormatVersion,
            causalHeadsData: causalHeadsData ?? fact.causalHeadsData,
            payloadFormatVersion: payloadFormatVersion ?? fact.payloadFormatVersion,
            payloadData: payloadData ?? fact.payloadData,
            payloadDigest: payloadDigest ?? fact.payloadDigest
        )
    }

    private func assertUnavailable(
        _ result: SessionProjectionResult,
        _ reason: UnavailableSession.Reason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .unavailable(value) = result else {
            XCTFail("Expected Unavailable", file: file, line: line)
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
            XCTFail("Expected Recovery", file: file, line: line)
            return
        }
        XCTAssertEqual(value.reasons, [reason], file: file, line: line)
    }
}
