// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import XCTest

final class RecipeScalingEdgeCaseTests: XCTestCase {
    func testEveryNumericYieldKindProvidesAnHonestNormalizedBasis() {
        let exact = RecipeYield(
            quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: 8, denominator: 4)
            ),
            originalText: "2 servings"
        )
        let approximate = RecipeYield(
            quantity: QuantityExpression(
                kind: .approximate,
                lowerBound: RationalQuantity(numerator: 12, denominator: 2)
            ),
            originalText: "About 6 servings"
        )
        let equalRange = RecipeYield(
            quantity: QuantityExpression(
                kind: .range,
                lowerBound: RationalQuantity(numerator: 4),
                upperBound: RationalQuantity(numerator: 8, denominator: 2)
            ),
            originalText: "4 servings"
        )

        XCTAssertEqual(
            exact.scalingBases,
            [RecipeYieldBasis(kind: .exact, quantity: RationalQuantity(numerator: 2))]
        )
        XCTAssertEqual(
            approximate.scalingBases,
            [RecipeYieldBasis(kind: .approximate, quantity: RationalQuantity(numerator: 6))]
        )
        XCTAssertEqual(
            equalRange.scalingBases,
            [RecipeYieldBasis(kind: .rangeLowerBound, quantity: RationalQuantity(numerator: 4))]
        )
    }

    func testInvalidOrAbsentYieldBoundsCannotBecomeScalingBases() {
        XCTAssertTrue(RecipeYield(originalText: "A platter").scalingBases.isEmpty)
        XCTAssertTrue(
            RecipeYield(
                quantity: QuantityExpression(
                    kind: .exact,
                    lowerBound: RationalQuantity(numerator: 0)
                ),
                originalText: "0 servings"
            ).scalingBases.isEmpty
        )
        XCTAssertTrue(
            RecipeYield(
                quantity: QuantityExpression(
                    kind: .approximate,
                    lowerBound: RationalQuantity(numerator: -2)
                ),
                originalText: "Invalid source quantity"
            ).scalingBases.isEmpty
        )

        let upperOnlyRange = RecipeYield(
            quantity: QuantityExpression(
                kind: .range,
                upperBound: RationalQuantity(numerator: 6)
            ),
            originalText: "Up to 6 servings"
        )
        XCTAssertEqual(
            upperOnlyRange.scalingBases,
            [RecipeYieldBasis(kind: .rangeUpperBound, quantity: RationalQuantity(numerator: 6))]
        )
    }

    func testEveryQuantityKindHasExplicitScalingSemantics() throws {
        let scale = try XCTUnwrap(RecipeScale(
            baseYield: RationalQuantity(numerator: 2),
            workingYield: RationalQuantity(numerator: 3)
        ))
        let exact = QuantityExpression(
            kind: .exact,
            lowerBound: RationalQuantity(numerator: 2),
            text: "two"
        )
        let approximate = QuantityExpression(
            kind: .approximate,
            lowerBound: RationalQuantity(numerator: 2),
            text: "about two"
        )
        let range = QuantityExpression(
            kind: .range,
            lowerBound: RationalQuantity(numerator: 2),
            upperBound: RationalQuantity(numerator: 4),
            text: "two to four"
        )
        let none = QuantityExpression(kind: .none)
        let text = QuantityExpression(kind: .text, text: "to taste")

        XCTAssertEqual(
            exact.scaled(by: scale),
            QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: 3),
                text: "two"
            )
        )
        XCTAssertEqual(
            approximate.scaled(by: scale),
            QuantityExpression(
                kind: .approximate,
                lowerBound: RationalQuantity(numerator: 3),
                text: "about two"
            )
        )
        XCTAssertEqual(
            range.scaled(by: scale),
            QuantityExpression(
                kind: .range,
                lowerBound: RationalQuantity(numerator: 3),
                upperBound: RationalQuantity(numerator: 6),
                text: "two to four"
            )
        )
        XCTAssertEqual(none.scaled(by: scale), none)
        XCTAssertEqual(text.scaled(by: scale), text)
    }

    func testMalformedOrOverflowingQuantitiesFailScalingAtomically() throws {
        let scale = try XCTUnwrap(RecipeScale(
            baseYield: RationalQuantity(numerator: 1),
            workingYield: RationalQuantity(numerator: 2)
        ))

        XCTAssertNil(QuantityExpression(kind: .exact).scaled(by: scale))
        XCTAssertNil(
            QuantityExpression(
                kind: .range,
                lowerBound: RationalQuantity(numerator: 1)
            ).scaled(by: scale)
        )
        XCTAssertNil(
            QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: Int.max)
            ).scaled(by: scale)
        )
    }

    func testLinearIngredientFailureModesAreDistinguishedWithoutMutation() throws {
        let scale = try XCTUnwrap(RecipeScale(
            baseYield: RationalQuantity(numerator: 1),
            workingYield: RationalQuantity(numerator: 2)
        ))
        let custom = RecipeIngredient(
            presentationMode: .custom,
            customDisplayText: "A custom amount",
            quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: 1)
            ),
            ingredientText: "sugar"
        )
        let withoutQuantity = RecipeIngredient(ingredientText: "salt")
        let none = RecipeIngredient(
            quantity: QuantityExpression(kind: .none),
            ingredientText: "water"
        )
        let overflow = RecipeIngredient(
            quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: Int.max)
            ),
            ingredientText: "flour"
        )

        XCTAssertEqual(custom.scaled(using: scale).status, .unchangedPresentationOverride)
        XCTAssertEqual(withoutQuantity.scaled(using: scale).status, .unchangedWithoutQuantity)
        XCTAssertEqual(none.scaled(using: scale).status, .unchangedText)
        XCTAssertEqual(overflow.scaled(using: scale).status, .unchangedArithmeticFailure)
        XCTAssertEqual(overflow.quantity?.lowerBound?.numerator, Int.max)
    }

    func testOriginalPresentationChangesOnlyWhenScaledStructureCanReplaceIt() throws {
        let doubled = try XCTUnwrap(RecipeScale(
            baseYield: RationalQuantity(numerator: 1),
            workingYield: RationalQuantity(numerator: 2)
        ))
        let identity = try XCTUnwrap(RecipeScale(
            baseYield: RationalQuantity(numerator: 3),
            workingYield: RationalQuantity(numerator: 3)
        ))
        let unstructured = RecipeIngredient(
            originalText: "one mystery amount",
            presentationMode: .original,
            quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: 1)
            )
        )
        let structured = RecipeIngredient(
            originalText: "1 cup sugar",
            presentationMode: .original,
            quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: 1)
            ),
            unitText: "cup",
            ingredientText: "sugar"
        )

        let rejected = unstructured.scaled(using: doubled)
        let unchangedPresentation = structured.scaled(using: identity)

        XCTAssertEqual(rejected.status, .unchangedPresentationOverride)
        XCTAssertEqual(rejected.ingredient, unstructured)
        XCTAssertEqual(unchangedPresentation.status, .scaled)
        XCTAssertEqual(unchangedPresentation.ingredient.presentationMode, .original)
        XCTAssertEqual(unchangedPresentation.ingredient, structured)
    }

    func testRecipeScaleRejectsNonpositiveAndOverflowingRatios() {
        XCTAssertNil(RecipeScale(
            baseYield: RationalQuantity(numerator: 0),
            workingYield: RationalQuantity(numerator: 1)
        ))
        XCTAssertNil(RecipeScale(
            baseYield: RationalQuantity(numerator: 1),
            workingYield: RationalQuantity(numerator: 0)
        ))
        XCTAssertNil(RecipeScale(
            baseYield: RationalQuantity(numerator: 1, denominator: Int.max),
            workingYield: RationalQuantity(numerator: Int.max)
        ))
    }
}
