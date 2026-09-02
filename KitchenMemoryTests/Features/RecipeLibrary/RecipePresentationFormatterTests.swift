// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenMemory
import KitchenKit
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
        .reviewMessage(locale: Locale(identifier: "en-US")),
      "1 ingredient line is preserved but unparsed"
    )
    XCTAssertEqual(
      RecipeImportConcern.unparsedIngredients(count: 2)
        .reviewMessage(locale: Locale(identifier: "en-US")),
      "2 ingredient lines are preserved but unparsed"
    )
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

  func testIngredientPresentationIsComputedFromStructuredFields() {
    let ingredient = RecipeIngredient(
      originalText: "two cups of flour",
      quantity: QuantityExpression(kind: .exact, lowerBound: RationalQuantity(numerator: 2)),
      unitText: "cups",
      ingredientText: "flour",
      preparation: "sifted"
    )

    XCTAssertEqual(formatter("en-US").ingredient(ingredient), "2 cups flour, sifted")
  }

  func testIngredientPresentationHonorsPreservedOriginalAndCustomText() {
    var ingredient = RecipeIngredient(
      originalText: "a couple glugs olive oil",
      ingredientText: "olive oil"
    )
    ingredient.presentationMode = .original
    XCTAssertEqual(formatter("en-US").ingredient(ingredient), "a couple glugs olive oil")

    ingredient.presentationMode = .custom
    ingredient.customDisplayText = "Olive oil, as needed"
    XCTAssertEqual(formatter("en-US").ingredient(ingredient), "Olive oil, as needed")
  }

  func testIncompleteStructuredPresentationFallsBackToOriginalText() {
    let ingredient = RecipeIngredient(originalText: "salt to taste")

    XCTAssertEqual(formatter("en-US").ingredient(ingredient), "salt to taste")
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
    let recipeFormatter = formatter("en-US")

    XCTAssertEqual(recipeFormatter.quantity(exact), "1/2")
    XCTAssertEqual(recipeFormatter.quantity(range), "2–3")
    XCTAssertEqual(recipeFormatter.quantity(approximate), "about 2")
    XCTAssertEqual(recipeFormatter.quantity(QuantityExpression(kind: .text, text: "to taste")), "to taste")
    XCTAssertNil(recipeFormatter.quantity(QuantityExpression(kind: .none)))
    XCTAssertEqual(recipeFormatter.rational(RationalQuantity(numerator: -1)), "-1")
    XCTAssertEqual(
      recipeFormatter.rational(RationalQuantity(numerator: -1, denominator: 2)),
      "-1/2"
    )
  }

  func testPackageQuantityParticipatesInComputedPresentation() {
    let ingredient = RecipeIngredient(
      quantity: QuantityExpression(kind: .exact, lowerBound: RationalQuantity(numerator: 4)),
      unitText: "cans",
      package: PackageDescription(
        quantity: QuantityExpression(kind: .exact, lowerBound: RationalQuantity(numerator: 5)),
        unitText: "ounces"
      ),
      ingredientText: "chunk light tuna"
    )

    XCTAssertEqual(
      formatter("en-US").ingredient(ingredient),
      "4 (5 ounces) cans chunk light tuna"
    )
  }

  private func formatter(_ localeIdentifier: String) -> RecipePresentationFormatter {
    RecipePresentationFormatter(locale: Locale(identifier: localeIdentifier))
  }
}
