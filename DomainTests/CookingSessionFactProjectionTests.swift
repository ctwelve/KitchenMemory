// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import XCTest

// The public projection seam is exercised as one behavioral catalog.
// swiftlint:disable file_length type_body_length
final class CookingSessionFactProjectionTests: XCTestCase {
    func testStopThenResumeReturnsToActive() throws {
        let fixture = try FactFixture()
        let stop = try fixture.fact(
            id: id(21), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        let resume = try fixture.fact(
            id: id(22), kind: .resume, heads: [stop.id.rawValue], payload: .empty
        )

        let projected = try fixture.project(facts: [resume, stop])

        XCTAssertEqual(projected.lifecycle, .active)
    }

    func testConcurrentStopAndResumeDerivesActiveIndependentOfDeliveryOrder() throws {
        let fixture = try FactFixture()
        let stop = try fixture.fact(
            id: id(21), kind: .stop, heads: [fixture.sessionID.rawValue], payload: .empty
        )
        let resume = try fixture.fact(
            id: id(22), kind: .resume, heads: [fixture.sessionID.rawValue], payload: .empty
        )

        XCTAssertEqual(try fixture.project(facts: [stop, resume]).lifecycle, .active)
        XCTAssertEqual(try fixture.project(facts: [resume, stop]).lifecycle, .active)
    }

    func testIndependentProgressSurvivesAndDifferingConcurrentProgressIsNonhiding() throws {
        let ingredientID = SessionIngredient.ID(rawValue: id(31))
        let stepID = SessionInstruction.ID(rawValue: id(32))
        let fixture = try FactFixture(ingredientID: ingredientID, stepID: stepID)
        let accounted = try fixture.fact(
            id: id(21),
            kind: .progress,
            heads: [fixture.sessionID.rawValue],
            target: ingredientID.rawValue,
            payload: .progress(.ingredient(.accounted))
        )
        let reopened = try fixture.fact(
            id: id(22),
            kind: .progress,
            heads: [fixture.sessionID.rawValue],
            target: ingredientID.rawValue,
            payload: .progress(.ingredient(.open))
        )
        let completed = try fixture.fact(
            id: id(23),
            kind: .progress,
            heads: [fixture.sessionID.rawValue],
            target: stepID.rawValue,
            payload: .progress(.instruction(.completed))
        )

        let projected = try fixture.project(facts: [completed, accounted, reopened])

        XCTAssertEqual(
            projected.progress,
            [
                SessionProgress(target: .ingredient(ingredientID), state: .ingredient(.open)),
                SessionProgress(target: .instruction(stepID), state: .instruction(.completed)),
            ]
        )
        XCTAssertEqual(projected.conflicts.count, 1)
        guard case let .progress(target, factIDs, states) = projected.conflicts[0] else {
            XCTFail("Expected a progress conflict")
            return
        }
        XCTAssertEqual(target, .ingredient(ingredientID))
        XCTAssertEqual(factIDs, [accounted.id, reopened.id])
        XCTAssertEqual(Set(states), [.ingredient(.accounted), .ingredient(.open)])
    }

    func testLaterProgressFactCausallySupersedesEarlierState() throws {
        let ingredientID = SessionIngredient.ID(rawValue: id(31))
        let fixture = try FactFixture(ingredientID: ingredientID)
        let accounted = try fixture.fact(
            id: id(21),
            kind: .progress,
            heads: [fixture.sessionID.rawValue],
            target: ingredientID.rawValue,
            payload: .progress(.ingredient(.accounted))
        )
        let reopened = try fixture.fact(
            id: id(22),
            kind: .progress,
            heads: [accounted.id.rawValue],
            target: ingredientID.rawValue,
            payload: .progress(.ingredient(.open))
        )

        let projected = try fixture.project(facts: [accounted, reopened])

        XCTAssertEqual(
            projected.progress,
            [SessionProgress(target: .ingredient(ingredientID), state: .ingredient(.open))]
        )
        XCTAssertTrue(projected.conflicts.isEmpty)
    }

    func testConcurrentWorkingScaleChangesRemainExplicit() throws {
        let fixture = try FactFixture()
        let firstScale = SessionWorkingScale(
            workingYield: RecipeYield(originalText: "2 servings"),
            exactScale: RationalQuantity(numerator: 1, denominator: 2)
        )
        let secondScale = SessionWorkingScale(
            workingYield: RecipeYield(originalText: "8 servings"),
            exactScale: RationalQuantity(numerator: 2)
        )
        let first = try fixture.fact(
            id: id(41),
            kind: .workingScale,
            heads: [fixture.sessionID.rawValue],
            payload: .workingScale(firstScale)
        )
        let second = try fixture.fact(
            id: id(42),
            kind: .workingScale,
            heads: [fixture.sessionID.rawValue],
            payload: .workingScale(secondScale)
        )

        let projected = try fixture.project(facts: [second, first])

        XCTAssertNil(projected.workingScale)
        XCTAssertEqual(
            projected.conflicts,
            [.workingScale(factIDs: [first.id, second.id], values: [firstScale, secondScale])]
        )
    }

    func testEquivalentConcurrentScaleChangesCoalesceSemantically() throws {
        let fixture = try FactFixture()
        let scale = SessionWorkingScale(exactScale: RationalQuantity(numerator: 2))
        let first = try fixture.fact(
            id: id(43),
            kind: .workingScale,
            heads: [fixture.sessionID.rawValue],
            payload: .workingScale(scale)
        )
        let second = try fixture.fact(
            id: id(44),
            kind: .workingScale,
            heads: [fixture.sessionID.rawValue],
            payload: .workingScale(scale)
        )

        let projected = try fixture.project(facts: [second, first])

        XCTAssertEqual(projected.workingScale, scale)
        XCTAssertTrue(projected.conflicts.isEmpty)
    }

    func testIndependentEntriesSurviveAndCausalRevisionReplacesTextExactly() throws {
        let fixture = try FactFixture()
        let firstEntryID = SessionEntry.ID(rawValue: id(51))
        let secondEntryID = SessionEntry.ID(rawValue: id(52))
        let submitted = try fixture.fact(
            id: firstEntryID.rawValue,
            kind: .sessionEntry,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionEntry(.submit(entryID: firstEntryID, text: "Too salty"))
        )
        let revised = try fixture.fact(
            id: id(53),
            kind: .sessionEntry,
            heads: [submitted.id.rawValue],
            payload: .sessionEntry(.revise(entryID: firstEntryID, text: "  Better with lime 🍋  "))
        )
        let independent = try fixture.fact(
            id: secondEntryID.rawValue,
            kind: .sessionEntry,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionEntry(.submit(entryID: secondEntryID, text: "Keep this"))
        )

        let projected = try fixture.project(facts: [independent, revised, submitted])

        XCTAssertEqual(
            projected.entries,
            [
                SessionEntry(id: firstEntryID, target: nil, text: "  Better with lime 🍋  "),
                SessionEntry(id: secondEntryID, target: nil, text: "Keep this"),
            ]
        )
        XCTAssertTrue(projected.conflicts.isEmpty)
    }

    func testEntryCanRetainSnapshotTarget() throws {
        let ingredientID = SessionIngredient.ID(rawValue: id(33))
        let fixture = try FactFixture(ingredientID: ingredientID)
        let entryID = SessionEntry.ID(rawValue: id(54))
        let submitted = try fixture.fact(
            id: entryID.rawValue,
            kind: .sessionEntry,
            heads: [fixture.sessionID.rawValue],
            target: ingredientID.rawValue,
            payload: .sessionEntry(.submit(entryID: entryID, text: "Toast longer"))
        )

        let projected = try fixture.project(facts: [submitted])

        XCTAssertEqual(
            projected.entries,
            [SessionEntry(id: entryID, target: .ingredient(ingredientID), text: "Toast longer")]
        )
    }

    func testConcurrentEntryRevisionAndWithdrawalRemainExplicit() throws {
        let fixture = try FactFixture()
        let entryID = SessionEntry.ID(rawValue: id(51))
        let submitted = try fixture.fact(
            id: entryID.rawValue,
            kind: .sessionEntry,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionEntry(.submit(entryID: entryID, text: "Original"))
        )
        let revised = try fixture.fact(
            id: id(52),
            kind: .sessionEntry,
            heads: [submitted.id.rawValue],
            payload: .sessionEntry(.revise(entryID: entryID, text: "Revised"))
        )
        let withdrawn = try fixture.fact(
            id: id(53),
            kind: .sessionEntry,
            heads: [submitted.id.rawValue],
            payload: .sessionEntry(.withdraw(entryID: entryID))
        )

        let projected = try fixture.project(facts: [withdrawn, revised, submitted])

        XCTAssertTrue(projected.entries.isEmpty)
        XCTAssertEqual(
            projected.conflicts,
            [
                .entry(
                    entryID: entryID,
                    factIDs: [revised.id, withdrawn.id],
                    values: [
                        .present(SessionEntry(id: entryID, target: nil, text: "Revised")),
                        .withdrawn,
                    ]
                ),
            ]
        )
    }

    func testConcurrentOutcomeSetAndClearRequireAttention() throws {
        let fixture = try FactFixture()
        let set = try fixture.fact(
            id: id(61),
            kind: .sessionOutcome,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionOutcome(.set(.coarse(.great)))
        )
        let clear = try fixture.fact(
            id: id(62),
            kind: .sessionOutcome,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionOutcome(.clear)
        )

        let projected = try fixture.project(facts: [clear, set])

        XCTAssertNil(projected.outcome)
        XCTAssertEqual(
            projected.conflicts,
            [.outcome(factIDs: [set.id, clear.id], values: [.value(.coarse(.great)), .cleared])]
        )
    }

    func testOutcomeClearWithoutCompetitionProducesNoOutcome() throws {
        let fixture = try FactFixture()
        let clear = try fixture.fact(
            id: id(63),
            kind: .sessionOutcome,
            heads: [fixture.sessionID.rawValue],
            payload: .sessionOutcome(.clear)
        )

        let projected = try fixture.project(facts: [clear])

        XCTAssertNil(projected.outcome)
        XCTAssertTrue(projected.conflicts.isEmpty)
    }
}
// swiftlint:enable type_body_length

struct FactFixture {
    let sessionID = CookingSession.ID(rawValue: id(11))
    let kitchenID = Kitchen.ID(rawValue: id(12))
    let root: CookingSessionRootEvidence

    init(
        ingredientID: SessionIngredient.ID? = nil,
        stepID: SessionInstruction.ID? = nil
    ) throws {
        let ingredientSections = ingredientID.map {
            [
                SessionIngredientSection(
                    title: nil,
                    ingredients: [
                        SessionIngredient(
                            id: $0,
                            sourceIngredientID: nil,
                            value: RecipeIngredient(originalText: "1 shell")
                        ),
                    ]
                ),
            ]
        } ?? []
        let instructionSections = stepID.map {
            [
                SessionInstructionSection(
                    title: nil,
                    steps: [
                        SessionInstruction(
                            id: $0,
                            sourceInstructionID: nil,
                            value: InstructionStep(text: "Eat")
                        ),
                    ]
                ),
            ]
        } ?? []
        let snapshot = ExecutionSnapshot(
            title: "Tacos",
            ingredientSections: ingredientSections,
            instructionSections: instructionSections
        )
        let encoded = try ExecutionSnapshotCodec.encode(snapshot)
        root = CookingSessionRootEvidence(
            id: sessionID,
            kitchenID: kitchenID,
            recipeID: Recipe.ID(rawValue: id(13)),
            recipeRevisionID: RecipeRevision.ID(rawValue: id(14)),
            startedAt: Date(timeIntervalSince1970: 100),
            snapshotFormatVersion: encoded.formatVersion,
            snapshotData: encoded.data,
            snapshotDigest: encoded.digest
        )
    }

    func fact(
        id: UUID,
        kind: SessionFact.Kind,
        heads: [UUID],
        target: UUID? = nil,
        payload: SessionFactPayload
    ) throws -> SessionFactEvidence {
        let encodedHeads = CausalHeadsCodec.encode(heads)
        let encodedPayload = try SessionFactPayloadCodec.encode(payload)
        return SessionFactEvidence(
            id: SessionFact.ID(rawValue: id),
            sessionID: sessionID,
            kitchenID: kitchenID,
            kind: kind.rawValue,
            targetSnapshotElementID: target,
            authoredAt: Date(timeIntervalSince1970: 200),
            causalHeadsFormatVersion: encodedHeads.formatVersion,
            causalHeadsData: encodedHeads.data,
            payloadFormatVersion: encodedPayload.formatVersion,
            payloadData: encodedPayload.data,
            payloadDigest: encodedPayload.digest
        )
    }

    func result(
        facts: [SessionFactEvidence],
        closures: [SessionClosureEvidence] = [],
        deletions: [SessionDeletionEvidence] = [],
        restorations: [SessionDeletionResolutionEvidence] = []
    ) -> SessionProjectionResult {
        SessionEvidenceProjector.project(
            SessionEvidence(
                sessionID: sessionID,
                roots: [root],
                facts: facts,
                closures: closures,
                deletions: deletions,
                restorations: restorations
            )
        )
    }

    func project(facts: [SessionFactEvidence]) throws -> CookingSessionProjection {
        let result = result(facts: facts)
        guard case let .session(session) = result else {
            throw ProjectionTestError.unexpected(result)
        }
        return session
    }
}

enum ProjectionTestError: Error {
    case unexpected(SessionProjectionResult)
}

func id(_ suffix: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
}
// swiftlint:enable file_length
