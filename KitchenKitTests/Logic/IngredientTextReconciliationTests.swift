// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import XCTest

final class IngredientTextReconciliationTests: XCTestCase {
    func testInsertedLinesAndConflictingEditsPreserveReviewedPrecision() throws {
        let reviewed = RecipeIngredient(
            originalText: "1 can tomatoes", presentationMode: .custom, customDisplayText: "My tomatoes",
            quantity: .init(kind: .exact, lowerBound: .init(numerator: 3, denominator: 2)), unitText: "can",
            package: .init(quantity: .init(kind: .exact, lowerBound: .init(numerator: 6)), unitText: "oz"),
            ingredientText: "tomatoes", preparation: "crushed by hand", note: "Reserve juice",
            isOptional: true, scalingBehavior: .fixed, parseState: .reviewed)
        let salt = IngredientLineParser.parse("salt to taste")
        let section = IngredientSection(title: "Sauce", ingredients: [reviewed, salt])
        let inserted = IngredientTextReconciliation.reconcile(
            lines: ["2 tbsp oil", reviewed.originalText, salt.originalText],
            with: section, locale: .init(identifier: "en_US"))
        XCTAssertEqual(inserted.section.id, section.id)
        XCTAssertEqual(inserted.section.title, "Sauce")
        XCTAssertEqual(inserted.section.ingredients[1], reviewed)
        XCTAssertEqual(inserted.section.ingredients[2], salt)
        XCTAssertTrue(inserted.conflicts.isEmpty)
        let changed = IngredientTextReconciliation.reconcile(
            lines: ["2 cans tomatoes", salt.originalText], with: section, locale: .init(identifier: "en_US"))
        var retained = reviewed
        retained.originalText = "2 cans tomatoes"
        XCTAssertEqual(changed.section.ingredients.first, retained)
        let conflict = try XCTUnwrap(changed.conflicts.first)
        XCTAssertEqual(conflict.proposed.id, reviewed.id)
        XCTAssertEqual(conflict.proposed.quantity?.lowerBound, .init(numerator: 2))
        XCTAssertEqual(conflict.proposed.note, "Reserve juice")
        XCTAssertEqual(conflict.proposed.customDisplayText, "My tomatoes")
        XCTAssertEqual(conflict.proposed.scalingBehavior, .fixed)
        XCTAssertEqual(changed.section.ingredients.last, salt)
        let decoded = try JSONDecoder().decode(IngredientTextReconciliation.self,
                                               from: JSONEncoder().encode(changed))
        XCTAssertEqual(decoded, changed)
    }
}
