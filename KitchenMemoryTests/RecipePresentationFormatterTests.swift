// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
@testable import KitchenMemory
import KitchenMemoryDomain
import KitchenMemoryLogic
import XCTest

final class RecipePresentationFormatterTests: XCTestCase {
  func testGeneratedRecipeWordingUsesTheRequestedLocale() {
    let quantity = QuantityExpression(
      kind: .approximate,
      lowerBound: RationalQuantity(numerator: 3, denominator: 2)
    )

    XCTAssertEqual(formatter("en-US").quantity(quantity), "about 1 1/2")
    XCTAssertEqual(formatter("fr-CA").quantity(quantity), "environ 1 1/2")
    XCTAssertEqual(formatter("es-MX").quantity(quantity), "aproximadamente 1 1/2")
    XCTAssertEqual(formatter("fr-CA").duration(RecipeDuration(seconds: 7_500)), "2 h 5 min")
  }

  func testAuthoredIngredientWordsArePreservedAroundLocalizedGeneratedWords() {
    let ingredient = RecipeIngredient(
      quantity: QuantityExpression(
        kind: .exact,
        lowerBound: RationalQuantity(numerator: 2)
      ),
      unitText: "tasses",
      ingredientText: "farine",
      isOptional: true
    )

    XCTAssertEqual(formatter("fr-CA").ingredient(ingredient), "2 tasses farine, facultatif")
    XCTAssertEqual(formatter("es-MX").ingredient(ingredient), "2 tasses farine, opcional")
  }

  func testCountMessagesUseLocalePluralRules() {
    XCTAssertEqual(
      RecipeImportConcern.unparsedIngredients(count: 1)
        .reviewMessage(locale: Locale(identifier: "fr-CA")),
      "1 ligne d’ingrédient est conservée sans être analysée"
    )
    XCTAssertEqual(
      RecipeImportConcern.unparsedIngredients(count: 2)
        .reviewMessage(locale: Locale(identifier: "fr-CA")),
      "2 lignes d’ingrédients sont conservées sans être analysées"
    )
    XCTAssertEqual(
      RecipeImportConcern.referencedImages(count: 2)
        .reviewMessage(locale: Locale(identifier: "es-MX")),
      "Se hace referencia a 2 imágenes de origen, pero no se descargaron"
    )
  }

  private func formatter(_ localeIdentifier: String) -> RecipePresentationFormatter {
    RecipePresentationFormatter(locale: Locale(identifier: localeIdentifier))
  }
}
