// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenKit
import XCTest

final class IngredientPresentationEdgeCaseTests: XCTestCase {
    func testOriginalPresentationFallsBackThroughStructureToPlaceholder() {
        let structuredFallback = RecipeIngredient(
            originalText: " \n ",
            presentationMode: .original,
            ingredientText: "sea salt"
        )
        let placeholderFallback = RecipeIngredient(
            originalText: " \t ",
            presentationMode: .original
        )

        XCTAssertEqual(structuredFallback.effectiveDisplayText, "sea salt")
        XCTAssertEqual(placeholderFallback.effectiveDisplayText, "Ingredient")
    }

    func testCustomPresentationUsesTheCompleteFallbackChain() {
        let structuredFallback = RecipeIngredient(
            originalText: "preserved source",
            presentationMode: .custom,
            customDisplayText: "  ",
            ingredientText: "chickpeas"
        )
        let originalFallback = RecipeIngredient(
            originalText: "one handful of herbs",
            presentationMode: .custom,
            customDisplayText: "\n"
        )
        let placeholderFallback = RecipeIngredient(
            presentationMode: .custom,
            customDisplayText: "\t"
        )

        XCTAssertEqual(structuredFallback.effectiveDisplayText, "chickpeas")
        XCTAssertEqual(originalFallback.effectiveDisplayText, "one handful of herbs")
        XCTAssertEqual(placeholderFallback.effectiveDisplayText, "Ingredient")
        XCTAssertTrue(structuredFallback.hasMeaningfulDisplayContent)
        XCTAssertTrue(originalFallback.hasMeaningfulDisplayContent)
        XCTAssertFalse(placeholderFallback.hasMeaningfulDisplayContent)
    }

    func testStructuredPresentationUsesPlaceholderWhenEveryFieldIsEmpty() {
        let ingredient = RecipeIngredient(
            originalText: "  ",
            ingredientText: "\n"
        )

        XCTAssertNil(ingredient.structuredDisplayText)
        XCTAssertEqual(ingredient.effectiveDisplayText, "Ingredient")
    }

    func testApproximateQuantityFallsBackToPreservedTextWithoutABound() {
        let quantity = QuantityExpression(
            kind: .approximate,
            text: "roughly a handful"
        )

        XCTAssertEqual(quantity.renderedText, "roughly a handful")
    }

    func testPackageUnitTextIsPreservedInsteadOfEnglishSingularized() {
        for unit in ["boxes", "glass"] {
            let ingredient = RecipeIngredient(
                quantity: QuantityExpression(
                    kind: .exact,
                    lowerBound: RationalQuantity(numerator: 2)
                ),
                package: PackageDescription(
                    quantity: QuantityExpression(
                        kind: .exact,
                        lowerBound: RationalQuantity(numerator: 5)
                    ),
                    unitText: unit
                ),
                ingredientText: "tomatoes"
            )

            XCTAssertEqual(
                ingredient.effectiveDisplayText,
                "2 (5 \(unit)) tomatoes",
                "Authored package unit was mutated: \(unit)"
            )
        }
    }
}
