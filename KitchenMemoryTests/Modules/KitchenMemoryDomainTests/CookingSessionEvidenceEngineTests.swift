// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import XCTest

// Continuation fixtures retain their complete paired provenance beside the
// malformed variants they classify.
// swiftlint:disable file_length
// swiftlint:disable type_body_length
final class CookingSessionEvidenceEngineTests: XCTestCase {
    func testCompleteRootProjectsAnActiveSession() throws {
        let snapshot = ExecutionSnapshot(
            title: "Midnight tacos",
            contentLanguage: RecipeContentLanguage(rawValue: "en-US")
        )
        let encoded = try ExecutionSnapshotCodec.encode(snapshot)
        let root = CookingSessionRootEvidence(
            id: sessionID,
            kitchenID: kitchenID,
            recipeID: recipeID,
            recipeRevisionID: revisionID,
            startedAt: Date(timeIntervalSince1970: 100),
            snapshotFormatVersion: encoded.formatVersion,
            snapshotData: encoded.data,
            snapshotDigest: encoded.digest
        )

        let result = SessionEvidenceProjector.project(
            SessionEvidence(sessionID: sessionID, roots: [root])
        )

        guard case let .session(session) = result else {
            XCTFail("Expected a complete Session, received \(result)")
            return
        }
        XCTAssertEqual(session.id, sessionID)
        XCTAssertEqual(session.snapshot, snapshot)
        XCTAssertEqual(session.lifecycle, .active)
        XCTAssertEqual(session.disposition, .ordinary)
        XCTAssertTrue(session.progress.isEmpty)
        XCTAssertTrue(session.entries.isEmpty)
        XCTAssertNil(session.outcome)
    }

    func testMissingRootAndUnsupportedSnapshotAreUnavailable() throws {
        assertUnavailable(SessionEvidence(sessionID: sessionID), reason: .missingRoot)

        var evidence = try makeEvidence()
        evidence.roots[0] = evidence.roots[0].replacing(snapshotFormatVersion: 99)
        assertUnavailable(evidence, reason: .unsupportedSnapshotFormat(99))
    }

    func testMalformedSnapshotAndDigestMismatchRequireRecovery() throws {
        var malformed = try makeEvidence()
        malformed.roots[0] = malformed.roots[0].replacing(
            snapshotData: Data("not json".utf8),
            snapshotDigest: SessionDigest.sha256(Data("not json".utf8))
        )
        assertRecovery(malformed, reason: .malformedSnapshot)

        var mismatched = try makeEvidence()
        mismatched.roots[0] = mismatched.roots[0].replacing(snapshotDigest: Data(repeating: 7, count: 32))
        assertRecovery(mismatched, reason: .digestMismatch)
    }

    func testExactDuplicateRootCoalescesButCollisionRequiresRecovery() throws {
        var duplicate = try makeEvidence()
        duplicate.roots.append(duplicate.roots[0])
        guard case .session = SessionEvidenceProjector.project(duplicate) else {
            XCTFail("An identical physical duplicate must coalesce")
            return
        }

        var collision = duplicate
        collision.roots[1] = collision.roots[1].replacing(
            startedAt: Date(timeIntervalSince1970: 101)
        )
        assertRecovery(collision, reason: .rootCollision)
    }

    func testCrossSessionRootRequiresRecovery() throws {
        var evidence = try makeEvidence()
        evidence.roots[0] = evidence.roots[0].replacing(
            id: CookingSession.ID(
                rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
            )
        )
        assertRecovery(evidence, reason: .crossSessionReference)
    }

    // swiftlint:disable:next function_body_length
    func testSnapshotInitialScaleMustReferenceValidUniqueIngredients() throws {
        let ingredientID = SessionIngredient.ID(rawValue: id(101))
        let quantity = SessionIngredientQuantity(
            ingredientID: ingredientID,
            quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: 1)
            )
        )
        let snapshot = ExecutionSnapshot(
            title: "Tacos",
            initialWorkingScale: SessionWorkingScale(quantities: [quantity, quantity]),
            ingredientSections: [
                SessionIngredientSection(
                    title: nil,
                    ingredients: [
                        SessionIngredient(
                            id: ingredientID,
                            sourceIngredientID: nil,
                            value: RecipeIngredient(originalText: "1 shell")
                        ),
                    ]
                ),
            ]
        )
        assertRecovery(
            try makeEvidence(snapshot: snapshot),
            reason: .malformedSnapshot
        )

        let nonpositive = ExecutionSnapshot(
            title: "Tacos",
            initialWorkingScale: SessionWorkingScale(
                exactScale: RationalQuantity(numerator: 0)
            )
        )
        assertRecovery(
            try makeEvidence(snapshot: nonpositive),
            reason: .malformedSnapshot
        )

        let missingIngredient = ExecutionSnapshot(
            title: "Tacos",
            initialWorkingScale: SessionWorkingScale(
                quantities: [
                    SessionIngredientQuantity(
                        ingredientID: SessionIngredient.ID(rawValue: id(102)),
                        quantity: quantity.quantity
                    ),
                ]
            )
        )
        assertRecovery(
            try makeEvidence(snapshot: missingIngredient),
            reason: .malformedSnapshot
        )
    }

    func testSnapshotRequiresTitleAndUniqueSessionElementIdentities() throws {
        assertRecovery(
            try makeEvidence(snapshot: ExecutionSnapshot(title: "   ")),
            reason: .malformedSnapshot
        )

        let sharedID = SessionIngredient.ID(rawValue: id(103))
        let ingredient = SessionIngredient(
            id: sharedID,
            sourceIngredientID: nil,
            value: RecipeIngredient(originalText: "1 shell")
        )
        let duplicateTargets = ExecutionSnapshot(
            title: "Tacos",
            ingredientSections: [
                SessionIngredientSection(title: nil, ingredients: [ingredient, ingredient]),
            ]
        )
        assertRecovery(
            try makeEvidence(snapshot: duplicateTargets),
            reason: .malformedSnapshot
        )
    }

    func testContinuationTargetsMustMatchSnapshotIdentityKinds() throws {
        let sharedUUID = id(120)
        let ingredientID = SessionIngredient.ID(rawValue: sharedUUID)
        let snapshot = ExecutionSnapshot(
            title: "Typed continuation",
            ingredientSections: [
                SessionIngredientSection(
                    title: nil,
                    ingredients: [
                        SessionIngredient(
                            id: ingredientID,
                            sourceIngredientID: nil,
                            value: RecipeIngredient(originalText: "1 shell")
                        ),
                    ]
                ),
            ],
            continuationBaseline: SessionContinuationBaseline(
                progress: [
                    SessionProgress(
                        target: .instruction(SessionInstruction.ID(rawValue: sharedUUID)),
                        state: .instruction(.completed)
                    ),
                ]
            )
        )
        var evidence = try makeEvidence(snapshot: snapshot)
        evidence.roots[0] = evidence.roots[0].replacing(
            sourceSessionID: sourceSessionID,
            sourceClosureID: SessionClosure.ID(rawValue: id(121))
        )

        assertRecovery(evidence, reason: .invalidContinuation)
    }

    // This single scenario shows the invalid provenance variants beside the
    // complete inherited baseline they contrast with.
    // swiftlint:disable:next function_body_length
    func testContinuationProvenanceMustBePairedWithInheritedBaseline() throws {
        var unpaired = try makeEvidence()
        unpaired.roots[0] = unpaired.roots[0].replacing(sourceSessionID: sourceSessionID)
        assertRecovery(unpaired, reason: .invalidContinuation)

        var missingBaseline = try makeEvidence()
        missingBaseline.roots[0] = missingBaseline.roots[0].replacing(
            sourceSessionID: sourceSessionID,
            sourceClosureID: SessionClosure.ID(
                rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000090")!
            )
        )
        assertRecovery(missingBaseline, reason: .invalidContinuation)

        let ingredientID = SessionIngredient.ID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000091")!
        )
        let entryID = SessionEntry.ID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000092")!
        )
        let sourceEntryID = SessionEntry.ID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000093")!
        )
        let untargetedEntryID = SessionEntry.ID(
            rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000095")!
        )
        let inheritedEntry = SessionEntry(
            id: entryID,
            target: .ingredient(ingredientID),
            text: "Use more lime"
        )
        let snapshot = ExecutionSnapshot(
            title: "Continued tacos",
            ingredientSections: [
                SessionIngredientSection(
                    title: nil,
                    ingredients: [
                        SessionIngredient(
                            id: ingredientID,
                            sourceIngredientID: nil,
                            value: RecipeIngredient(originalText: "1 lime")
                        ),
                    ]
                ),
            ],
            continuationBaseline: SessionContinuationBaseline(
                workingScale: SessionWorkingScale(
                    exactScale: RationalQuantity(numerator: 2),
                    quantities: [
                        SessionIngredientQuantity(
                            ingredientID: ingredientID,
                            quantity: QuantityExpression(
                                kind: .exact,
                                lowerBound: RationalQuantity(numerator: 2)
                            )
                        ),
                    ]
                ),
                progress: [
                    SessionProgress(
                        target: .ingredient(ingredientID),
                        state: .ingredient(.accounted)
                    ),
                ],
                entries: [
                    SessionContinuationEntry(
                        entry: inheritedEntry,
                        sourceEntryID: sourceEntryID
                    ),
                    SessionContinuationEntry(
                        entry: SessionEntry(
                            id: untargetedEntryID,
                            target: nil,
                            text: "Untargeted inheritance"
                        ),
                        sourceEntryID: nil
                    ),
                ],
                targetMappings: [
                    SessionContinuationTargetMapping(
                        target: .ingredient(ingredientID),
                        sourceTarget: .ingredient(
                            SessionIngredient.ID(
                                rawValue: UUID(
                                    uuidString: "00000000-0000-0000-0000-000000000094"
                                )!
                            )
                        )
                    ),
                ]
            )
        )
        let encoded = try ExecutionSnapshotCodec.encode(snapshot)
        var complete = try makeEvidence()
        complete.roots[0] = complete.roots[0].replacing(
            snapshotData: encoded.data,
            snapshotDigest: encoded.digest,
            sourceSessionID: sourceSessionID,
            sourceClosureID: SessionClosure.ID(
                rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000090")!
            )
        )
        guard case let .session(session) = SessionEvidenceProjector.project(complete) else {
            XCTFail("Expected a complete continuation")
            return
        }
        XCTAssertEqual(session.lifecycle, .active)
        XCTAssertEqual(session.snapshot, snapshot)
        XCTAssertEqual(session.workingScale, snapshot.continuationBaseline?.workingScale)
        XCTAssertEqual(session.progress, snapshot.continuationBaseline?.progress)
        XCTAssertEqual(
            session.entries,
            [
                inheritedEntry,
                SessionEntry(
                    id: untargetedEntryID,
                    target: nil,
                    text: "Untargeted inheritance"
                ),
            ]
        )
        XCTAssertNil(session.outcome)

        var missingMappingSnapshot = snapshot
        missingMappingSnapshot.continuationBaseline?.targetMappings = []
        let missingMappingEncoded = try ExecutionSnapshotCodec.encode(missingMappingSnapshot)
        var missingMapping = complete
        missingMapping.roots[0] = missingMapping.roots[0].replacing(
            snapshotData: missingMappingEncoded.data,
            snapshotDigest: missingMappingEncoded.digest
        )
        assertRecovery(missingMapping, reason: .invalidContinuation)

        let emptyContinuation = ExecutionSnapshot(
            title: "Empty continuation",
            continuationBaseline: SessionContinuationBaseline()
        )
        let emptyEncoded = try ExecutionSnapshotCodec.encode(emptyContinuation)
        var emptyEvidence = try makeEvidence()
        emptyEvidence.roots[0] = emptyEvidence.roots[0].replacing(
            snapshotData: emptyEncoded.data,
            snapshotDigest: emptyEncoded.digest,
            sourceSessionID: sourceSessionID,
            sourceClosureID: SessionClosure.ID(rawValue: id(96))
        )
        guard case .session = SessionEvidenceProjector.project(emptyEvidence) else {
            XCTFail("Expected an empty but explicitly paired continuation baseline")
            return
        }
        emptyEvidence.roots[0] = emptyEvidence.roots[0].replacing(sourceSessionID: sessionID)
        assertRecovery(emptyEvidence, reason: .invalidContinuation)
    }

    private func makeEvidence(
        snapshot: ExecutionSnapshot = ExecutionSnapshot(title: "Tacos")
    ) throws -> SessionEvidence {
        let encoded = try ExecutionSnapshotCodec.encode(snapshot)
        return SessionEvidence(
            sessionID: sessionID,
            roots: [
                CookingSessionRootEvidence(
                    id: sessionID,
                    kitchenID: kitchenID,
                    recipeID: recipeID,
                    recipeRevisionID: revisionID,
                    startedAt: Date(timeIntervalSince1970: 100),
                    snapshotFormatVersion: encoded.formatVersion,
                    snapshotData: encoded.data,
                    snapshotDigest: encoded.digest
                ),
            ]
        )
    }

    private func assertUnavailable(
        _ evidence: SessionEvidence,
        reason: UnavailableSession.Reason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .unavailable(unavailable) = SessionEvidenceProjector.project(evidence) else {
            XCTFail("Expected Unavailable", file: file, line: line)
            return
        }
        XCTAssertEqual(unavailable.reasons, [reason], file: file, line: line)
        XCTAssertEqual(unavailable.evidence, evidence, file: file, line: line)
    }

    private func assertRecovery(
        _ evidence: SessionEvidence,
        reason: SessionRecovery.Reason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .recovery(recovery) = SessionEvidenceProjector.project(evidence) else {
            XCTFail("Expected Recovery", file: file, line: line)
            return
        }
        XCTAssertEqual(recovery.reasons, [reason], file: file, line: line)
        XCTAssertEqual(recovery.evidence, evidence, file: file, line: line)
    }
}
// swiftlint:enable type_body_length

private let sessionID = CookingSession.ID(
    rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
)
private let sourceSessionID = CookingSession.ID(
    rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!
)
private let kitchenID = Kitchen.ID(
    rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
)
private let recipeID = Recipe.ID(
    rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!
)
private let revisionID = RecipeRevision.ID(
    rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!
)
// swiftlint:enable file_length
