// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

final class DomainSkeletonTests: XCTestCase {
    func testInitialRecipeRelationshipsUseStableIdentifiers() throws {
        let kitchenID = Kitchen.ID(rawValue: UUID(uuidString: "5F366829-6A6A-4F88-87F8-43BDFD2E88F4")!)
        let recipeID = Recipe.ID(rawValue: UUID(uuidString: "95781805-F5D3-46B0-B685-A660F8AC69F2")!)
        let revisionID = RecipeRevision.ID(rawValue: UUID(uuidString: "CD477A1F-A876-4C08-8AC9-1915ACD71E88")!)

        let kitchen = Kitchen(id: kitchenID, name: "Home")
        let recipe = Recipe(id: recipeID, kitchenID: kitchen.id, currentRevisionID: revisionID)
        let revision = RecipeRevision(
            id: revisionID,
            recipeID: recipe.id,
            revisionNumber: 1,
            title: "Tuna Noodle Hotdish"
        )

        XCTAssertEqual(recipe.kitchenID, kitchen.id)
        XCTAssertEqual(recipe.currentRevisionID, revision.id)
        XCTAssertEqual(revision.recipeID, recipe.id)
    }

    func testDomainValuesRoundTripThroughJSON() throws {
        let kitchen = Kitchen(name: "Home")
        let data = try JSONEncoder().encode(kitchen)

        XCTAssertEqual(try JSONDecoder().decode(Kitchen.self, from: data), kitchen)
    }

    func testCustomIngredientContentUsesEveryLosslessFallback() {
        let custom = RecipeIngredient(
            presentationMode: .custom,
            customDisplayText: "Use the family wording"
        )
        let structured = RecipeIngredient(
            presentationMode: .custom,
            ingredientText: "chickpeas"
        )
        let original = RecipeIngredient(
            originalText: "one handful herbs",
            presentationMode: .custom
        )
        let empty = RecipeIngredient(presentationMode: .custom)

        XCTAssertTrue(custom.hasMeaningfulDisplayContent)
        XCTAssertTrue(structured.hasMeaningfulDisplayContent)
        XCTAssertTrue(original.hasMeaningfulDisplayContent)
        XCTAssertFalse(empty.hasMeaningfulDisplayContent)
    }

    func testRationalScalingReducesExactly() throws {
        let scale = try XCTUnwrap(RecipeScale(
            baseYield: RationalQuantity(numerator: 8),
            workingYield: RationalQuantity(numerator: 6)
        ))

        XCTAssertEqual(scale.multiplier, RationalQuantity(numerator: 3, denominator: 4))
        XCTAssertEqual(
            RationalQuantity(numerator: 2).multiplied(by: scale.multiplier),
            RationalQuantity(numerator: 3, denominator: 2)
        )
    }

    func testExactAndRangedLinearQuantitiesScaleWithoutChangingPackageSize() throws {
        let scale = try XCTUnwrap(RecipeScale(
            baseYield: RationalQuantity(numerator: 8),
            workingYield: RationalQuantity(numerator: 4)
        ))
        let exact = RecipeIngredient(
            quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: 4)
            ),
            unitText: "cans",
            package: PackageDescription(
                quantity: QuantityExpression(
                    kind: .exact,
                    lowerBound: RationalQuantity(numerator: 5)
                ),
                unitText: "ounces"
            ),
            ingredientText: "tuna"
        ).scaled(using: scale)
        let range = RecipeIngredient(
            quantity: QuantityExpression(
                kind: .range,
                lowerBound: RationalQuantity(numerator: 2),
                upperBound: RationalQuantity(numerator: 3)
            ),
            unitText: "cups",
            ingredientText: "stock"
        ).scaled(using: scale)

        XCTAssertEqual(exact.status, .scaled)
        XCTAssertEqual(exact.ingredient.quantity?.lowerBound, RationalQuantity(numerator: 2))
        XCTAssertEqual(exact.ingredient.package?.quantity.lowerBound, RationalQuantity(numerator: 5))
        XCTAssertEqual(range.status, .scaled)
        XCTAssertEqual(range.ingredient.quantity?.lowerBound, RationalQuantity(numerator: 1))
        XCTAssertEqual(
            range.ingredient.quantity?.upperBound,
            RationalQuantity(numerator: 3, denominator: 2)
        )
    }

    func testNonlinearAndTextIngredientsRemainIntactWithExplicitStatuses() throws {
        let scale = try XCTUnwrap(RecipeScale(
            baseYield: RationalQuantity(numerator: 4),
            workingYield: RationalQuantity(numerator: 8)
        ))
        let fixed = RecipeIngredient(
            originalText: "oil for the pan",
            ingredientText: "oil for the pan",
            scalingBehavior: .fixed
        ).scaled(using: scale)
        let manual = RecipeIngredient(
            originalText: "salt to taste",
            ingredientText: "salt",
            scalingBehavior: .manualReview
        ).scaled(using: scale)
        let text = RecipeIngredient(
            quantity: QuantityExpression(kind: .text, text: "a handful"),
            ingredientText: "parsley"
        ).scaled(using: scale)

        XCTAssertEqual(fixed.status, .unchangedFixed)
        XCTAssertEqual(fixed.ingredient.originalText, "oil for the pan")
        XCTAssertEqual(manual.status, .unchangedManualReview)
        XCTAssertEqual(manual.ingredient.ingredientText, "salt")
        XCTAssertEqual(text.status, .unchangedText)
        XCTAssertEqual(text.ingredient.quantity?.text, "a handful")
    }

    func testOriginalPresentationUsesStructuredAmountOnlyForScaledCopy() throws {
        let scale = try XCTUnwrap(RecipeScale(
            baseYield: RationalQuantity(numerator: 4),
            workingYield: RationalQuantity(numerator: 8)
        ))
        let ingredient = RecipeIngredient(
            originalText: "1.3 lb ground beef",
            presentationMode: .original,
            quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: 13, denominator: 10)
            ),
            unitText: "pounds",
            ingredientText: "ground beef",
            parseState: .reviewed
        )

        let scaled = ingredient.scaled(using: scale)

        XCTAssertEqual(ingredient.presentationMode, .original)
        XCTAssertEqual(scaled.status, .scaled)
        XCTAssertEqual(scaled.ingredient.presentationMode, .structured)
        XCTAssertEqual(
            scaled.ingredient.quantity?.lowerBound,
            RationalQuantity(numerator: 13, denominator: 5)
        )
    }

    func testRangedYieldExposesBothHonestScalingBases() {
        let recipeYield = RecipeYield(
            quantity: QuantityExpression(
                kind: .range,
                lowerBound: RationalQuantity(numerator: 4),
                upperBound: RationalQuantity(numerator: 6)
            ),
            unitText: "servings",
            originalText: "Serves 4 to 6"
        )

        XCTAssertEqual(
            recipeYield.scalingBases,
            [
                RecipeYieldBasis(
                    kind: .rangeLowerBound,
                    quantity: RationalQuantity(numerator: 4)
                ),
                RecipeYieldBasis(
                    kind: .rangeUpperBound,
                    quantity: RationalQuantity(numerator: 6)
                ),
            ]
        )
        XCTAssertTrue(
            RecipeYield(
                quantity: QuantityExpression(kind: .text, text: "one large platter"),
                originalText: "One large platter"
            ).scalingBases.isEmpty
        )
    }
}
