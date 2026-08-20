// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
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

    func testIngredientPresentationIsComputedFromStructuredFields() {
        let ingredient = RecipeIngredient(
            originalText: "two cups of flour",
            quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: 2)
            ),
            unitText: "cups",
            ingredientText: "flour",
            preparation: "sifted"
        )

        XCTAssertEqual(ingredient.effectiveDisplayText, "2 cups flour, sifted")
    }

    func testIngredientCanPresentPreservedOriginalOrCustomText() {
        var ingredient = RecipeIngredient(
            originalText: "a couple glugs olive oil",
            ingredientText: "olive oil"
        )

        ingredient.presentationMode = .original
        XCTAssertEqual(ingredient.effectiveDisplayText, "a couple glugs olive oil")

        ingredient.presentationMode = .custom
        ingredient.customDisplayText = "Olive oil, as needed"
        XCTAssertEqual(ingredient.effectiveDisplayText, "Olive oil, as needed")
    }

    func testIncompleteStructuredPresentationFallsBackToOriginalText() {
        let ingredient = RecipeIngredient(originalText: "salt to taste")

        XCTAssertEqual(ingredient.effectiveDisplayText, "salt to taste")
    }

    func testEveryQuantityKindRendersWithoutInventingPrecision() {
        let exact = QuantityExpression(
            kind: .exact,
            lowerBound: RationalQuantity(numerator: 1, denominator: 2)
        )
        let range = QuantityExpression(
            kind: .range,
            lowerBound: RationalQuantity(numerator: 2),
            upperBound: RationalQuantity(numerator: 3)
        )
        let approximate = QuantityExpression(
            kind: .approximate,
            lowerBound: RationalQuantity(numerator: 2)
        )
        let text = QuantityExpression(kind: .text, text: "to taste")

        XCTAssertEqual(exact.renderedText, "1/2")
        XCTAssertEqual(range.renderedText, "2–3")
        XCTAssertEqual(approximate.renderedText, "about 2")
        XCTAssertEqual(text.renderedText, "to taste")
        XCTAssertNil(QuantityExpression(kind: .none).renderedText)
    }

    func testPackageQuantityParticipatesInComputedPresentation() {
        let ingredient = RecipeIngredient(
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
            ingredientText: "chunk light tuna"
        )

        XCTAssertEqual(
            ingredient.effectiveDisplayText,
            "4 (5-ounce) cans chunk light tuna"
        )
    }
}
