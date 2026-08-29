// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenKit
import Foundation
import XCTest

final class CookingSessionCodecTests: XCTestCase {
    func testSnapshotCodecIsCanonicalAndPreservesAuthoredUnicode() throws {
        let value = ExecutionSnapshot(
            title: "Crème brûlée 🍮 / クレーム",
            contentLanguage: RecipeContentLanguage(rawValue: "fr-CA")
        )

        let first = try ExecutionSnapshotCodec.encode(value)
        let second = try ExecutionSnapshotCodec.encode(value)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.digest, SessionDigest.sha256(first.data))
        XCTAssertEqual(
            try ExecutionSnapshotCodec.decode(
                formatVersion: first.formatVersion,
                data: first.data
            ),
            value
        )
    }

    func testCausalHeadCodecSortsUUIDBytesAndRoundTrips() throws {
        let later = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
        let earlier = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let encoded = CausalHeadsCodec.encode([later, earlier])

        XCTAssertEqual(encoded.formatVersion, 1)
        XCTAssertEqual(try CausalHeadsCodec.decode(formatVersion: 1, data: encoded.data), [earlier, later])
        XCTAssertEqual(encoded.data.count, 32)
    }

    func testCausalHeadCodecRejectsNoncanonicalAndMalformedBytes() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let duplicate = CausalHeadsCodec.encode([id, id]).data

        XCTAssertThrowsError(try CausalHeadsCodec.decode(formatVersion: 1, data: duplicate))
        XCTAssertThrowsError(try CausalHeadsCodec.decode(formatVersion: 1, data: Data([0])))
        XCTAssertThrowsError(try CausalHeadsCodec.decode(formatVersion: 99, data: Data()))
        XCTAssertThrowsError(
            try ExecutionSnapshotCodec.decode(formatVersion: 99, data: Data())
        )
        XCTAssertThrowsError(
            try SessionFactPayloadCodec.decode(formatVersion: 99, data: Data())
        )
        XCTAssertThrowsError(try SessionOutcomeCodec.decode(formatVersion: 99, data: Data()))
        XCTAssertThrowsError(
            try SessionContinuationBaselineCodec.decode(formatVersion: 99, data: Data())
        )
        XCTAssertThrowsError(
            try ClosedSessionProjectionCodec.decode(formatVersion: 99, data: Data())
        )
    }

    func testJSONCodecsRejectWellFormedButNoncanonicalAndMalformedData() throws {
        let snapshot = ExecutionSnapshot(title: "Tacos")
        let canonical = try ExecutionSnapshotCodec.encode(snapshot)
        let noncanonical = canonical.data + Data([0x0A])

        XCTAssertThrowsError(
            try ExecutionSnapshotCodec.decode(formatVersion: canonical.formatVersion, data: noncanonical)
        ) { error in
            XCTAssertEqual(error as? SessionCodecError, .noncanonicalData)
        }
        XCTAssertThrowsError(
            try ExecutionSnapshotCodec.decode(formatVersion: canonical.formatVersion, data: Data("{".utf8))
        ) { error in
            XCTAssertEqual(error as? SessionCodecError, .malformedData)
        }
    }

    // The permanent-codec contract is clearer when its related round trips use
    // one shared identity-rich fixture.
    // swiftlint:disable:next function_body_length
    func testPayloadOutcomeAndClosedProjectionCodecsRoundTrip() throws {
        let payload = SessionFactPayload.sessionOutcome(.set(.coarse(.great)))
        let encodedPayload = try SessionFactPayloadCodec.encode(payload)
        XCTAssertEqual(
            try SessionFactPayloadCodec.decode(
                formatVersion: encodedPayload.formatVersion,
                data: encodedPayload.data
            ),
            payload
        )

        let outcome = SessionOutcome.coarse(.okay)
        let encodedOutcome = try SessionOutcomeCodec.encode(outcome)
        XCTAssertEqual(
            try SessionOutcomeCodec.decode(
                formatVersion: encodedOutcome.formatVersion,
                data: encodedOutcome.data
            ),
            outcome
        )

        let ingredientID = SessionIngredient.ID(rawValue: id(7))
        let sourceIngredientID = SessionIngredient.ID(rawValue: id(8))
        let entryID = SessionEntry.ID(rawValue: id(9))
        let sourceEntryID = SessionEntry.ID(rawValue: id(10))
        let target = SessionProgressTarget.ingredient(ingredientID)
        let baselineScale = SessionWorkingScale(exactScale: RationalQuantity(numerator: 2))
        let baseline = SessionContinuationBaseline(
            workingScale: baselineScale,
            progress: [SessionProgress(target: target, state: .ingredient(.accounted))],
            entries: [
                SessionContinuationEntry(
                    entry: SessionEntry(id: entryID, target: target, text: "Inherited"),
                    sourceEntryID: sourceEntryID
                ),
            ],
            targetMappings: [
                SessionContinuationTargetMapping(
                    target: target,
                    sourceTarget: .ingredient(sourceIngredientID)
                ),
            ]
        )
        let encodedBaseline = try SessionContinuationBaselineCodec.encode(baseline)
        XCTAssertEqual(
            try SessionContinuationBaselineCodec.decode(
                formatVersion: encodedBaseline.formatVersion,
                data: encodedBaseline.data
            ),
            baseline
        )
        let emptyBaseline = SessionContinuationBaseline()
        let encodedEmptyBaseline = try SessionContinuationBaselineCodec.encode(emptyBaseline)
        XCTAssertEqual(
            try SessionContinuationBaselineCodec.decode(
                formatVersion: encodedEmptyBaseline.formatVersion,
                data: encodedEmptyBaseline.data
            ),
            emptyBaseline
        )

        let projection = CookingSessionProjection(
            id: CookingSession.ID(rawValue: id(1)),
            snapshot: ExecutionSnapshot(title: "Tacos"),
            lifecycle: .stopped,
            progress: baseline.progress,
            workingScale: baselineScale,
            entries: [baseline.entries[0].entry],
            outcome: outcome
        )
        let closed = ClosedSessionProjection(projection)
        let encodedClosed = try ClosedSessionProjectionCodec.encode(closed)
        XCTAssertEqual(
            try ClosedSessionProjectionCodec.decode(
                formatVersion: encodedClosed.formatVersion,
                data: encodedClosed.data
            ),
            closed
        )
        let emptyClosed = ClosedSessionProjection(
            CookingSessionProjection(
                id: CookingSession.ID(rawValue: id(11)),
                snapshot: ExecutionSnapshot(title: "Empty")
            )
        )
        let encodedEmptyClosed = try ClosedSessionProjectionCodec.encode(emptyClosed)
        XCTAssertEqual(
            try ClosedSessionProjectionCodec.decode(
                formatVersion: encodedEmptyClosed.formatVersion,
                data: encodedEmptyClosed.data
            ),
            emptyClosed
        )
    }

    func testSessionOwnedCollectionsCanonicalizeIdentityKeyedValues() throws {
        let firstIngredient = SessionIngredient.ID(rawValue: id(1))
        let secondIngredient = SessionIngredient.ID(rawValue: id(2))
        let firstEntry = SessionEntry.ID(rawValue: id(3))
        let secondEntry = SessionEntry.ID(rawValue: id(4))
        let firstTarget = SessionProgressTarget.ingredient(firstIngredient)
        let secondTarget = SessionProgressTarget.ingredient(secondIngredient)
        let quantity = QuantityExpression(
            kind: .exact,
            lowerBound: RationalQuantity(numerator: 1)
        )

        let scale = SessionWorkingScale(
            quantities: [
                SessionIngredientQuantity(ingredientID: secondIngredient, quantity: quantity),
                SessionIngredientQuantity(ingredientID: firstIngredient, quantity: quantity),
            ]
        )
        let baseline = SessionContinuationBaseline(
            progress: [
                SessionProgress(target: secondTarget, state: .ingredient(.open)),
                SessionProgress(target: firstTarget, state: .ingredient(.accounted)),
            ],
            entries: [
                SessionContinuationEntry(
                    entry: SessionEntry(id: secondEntry, target: nil, text: "Second"),
                    sourceEntryID: nil
                ),
                SessionContinuationEntry(
                    entry: SessionEntry(id: firstEntry, target: nil, text: "First"),
                    sourceEntryID: nil
                ),
            ],
            targetMappings: [
                SessionContinuationTargetMapping(target: secondTarget, sourceTarget: firstTarget),
                SessionContinuationTargetMapping(target: firstTarget, sourceTarget: secondTarget),
            ]
        )
        let media = SessionMediaReference(
            id: SessionMediaReference.ID(rawValue: id(5)),
            sourceMediaID: RecipeMedia.ID(rawValue: id(6)),
            role: .hero,
            accessibilityDescription: "Finished tacos"
        )

        XCTAssertEqual(scale.quantities.map(\.ingredientID), [firstIngredient, secondIngredient])
        XCTAssertEqual(baseline.progress.map(\.target), [firstTarget, secondTarget])
        XCTAssertEqual(baseline.entries.map(\.entry.id), [firstEntry, secondEntry])
        XCTAssertEqual(baseline.targetMappings.map(\.target), [firstTarget, secondTarget])
        XCTAssertEqual(media.role, .hero)
    }

    func testPayloadDecoderRejectsAlternateIdentityCollectionOrder() throws {
        let first = SessionIngredient.ID(rawValue: id(1))
        let second = SessionIngredient.ID(rawValue: id(2))
        let quantity = QuantityExpression(
            kind: .exact,
            lowerBound: RationalQuantity(numerator: 1)
        )
        let payload = SessionFactPayload.workingScale(
            SessionWorkingScale(
                quantities: [
                    SessionIngredientQuantity(ingredientID: second, quantity: quantity),
                    SessionIngredientQuantity(ingredientID: first, quantity: quantity),
                ]
            )
        )
        let encoded = try SessionFactPayloadCodec.encode(payload)
        var document = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded.data) as? [String: Any]
        )
        var workingScale = try XCTUnwrap(document["workingScale"] as? [String: Any])
        var value = try XCTUnwrap(workingScale["_0"] as? [String: Any])
        let quantities = try XCTUnwrap(value["quantities"] as? [Any])
        value["quantities"] = Array(quantities.reversed())
        workingScale["_0"] = value
        document["workingScale"] = workingScale
        let noncanonical = try JSONSerialization.data(
            withJSONObject: document,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )

        XCTAssertThrowsError(
            try SessionFactPayloadCodec.decode(
                formatVersion: encoded.formatVersion,
                data: noncanonical
            )
        ) { error in
            XCTAssertEqual(error as? SessionCodecError, .noncanonicalData)
        }
    }
}

extension CookingSessionRootEvidence {
    func replacing(
        id: CookingSession.ID? = nil,
        startedAt: Date? = nil,
        snapshotFormatVersion: Int? = nil,
        snapshotData: Data? = nil,
        snapshotDigest: Data? = nil,
        sourceSessionID: CookingSession.ID? = nil,
        sourceClosureID: SessionClosure.ID? = nil
    ) -> Self {
        Self(
            id: id ?? self.id,
            kitchenID: kitchenID,
            recipeID: recipeID,
            recipeRevisionID: recipeRevisionID,
            startedAt: startedAt ?? self.startedAt,
            snapshotFormatVersion: snapshotFormatVersion ?? self.snapshotFormatVersion,
            snapshotData: snapshotData ?? self.snapshotData,
            snapshotDigest: snapshotDigest ?? self.snapshotDigest,
            sourceSessionID: sourceSessionID ?? self.sourceSessionID,
            sourceClosureID: sourceClosureID ?? self.sourceClosureID
        )
    }
}
