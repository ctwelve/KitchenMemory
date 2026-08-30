// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenKit
import XCTest

@MainActor
final class RecipeEditorCleaningTests: XCTestCase {
  func testRevisingAMissingRecipeReportsTheBusinessFailure() throws {
    let editor = RecipeEditor(repository: try repository())

    XCTAssertThrowsError(try editor.revise(
      recipeID: Recipe.ID(),
      from: RecipeDraft(title: "Soup")
    )) { error in
      XCTAssertEqual(error as? RecipeEditorError, .missingRecipe)
    }
  }

  func testMalformedOptionalStructureIsCleanedWithoutInventingPrecision() throws {
    let repository = try repository()
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let draft = malformedDraft()

    let stored = try RecipeEditor(repository: repository).create(in: kitchen.id, from: draft)
    let kept = stored.revision.ingredientSections[0].ingredients

    XCTAssertEqual(kept.count, 5)
    XCTAssertEqual(kept[0].quantity?.kind, .text)
    XCTAssertEqual(kept[0].quantity?.text, "pinch")
    XCTAssertNil(kept[0].package)
    XCTAssertNil(kept[1].quantity)
    XCTAssertEqual(kept[2].quantity?.text, "about one")
    XCTAssertNil(kept[3].quantity)
    XCTAssertEqual(kept[4].quantity?.lowerBound, RationalQuantity(numerator: 2))
    XCTAssertNil(kept[4].quantity?.upperBound)
    XCTAssertEqual(stored.revision.ingredientSections[1].title, "Empty")
    XCTAssertEqual(stored.revision.instructionSections.map(\.title), ["Notes"])
  }

  // Keep the deliberately malformed variants together so omissions in the
  // editor's conservative cleanup matrix are easy to spot during review.
  // swiftlint:disable:next function_body_length
  private func malformedDraft() -> RecipeDraft {
    let ingredients = [
      RecipeIngredient(),
      RecipeIngredient(
        customDisplayText: " custom ",
        quantity: QuantityExpression(kind: .none),
        unitText: " ",
        ingredientText: " ",
        preparation: " ",
        note: " "
      ),
      RecipeIngredient(
        quantity: QuantityExpression(
          kind: .exact,
          lowerBound: RationalQuantity(numerator: 1, denominator: 0),
          text: " pinch "
        ),
        package: PackageDescription(
          quantity: QuantityExpression(
            kind: .exact,
            lowerBound: RationalQuantity(numerator: 2)
          ),
          unitText: " "
        ),
        ingredientText: "salt"
      ),
      RecipeIngredient(
        quantity: QuantityExpression(
          kind: .range,
          lowerBound: RationalQuantity(numerator: 1)
        ),
        ingredientText: "onion"
      ),
      RecipeIngredient(
        quantity: QuantityExpression(
          kind: .approximate,
          lowerBound: RationalQuantity(numerator: -1),
          text: " about one "
        ),
        ingredientText: "pepper"
      ),
      RecipeIngredient(
        quantity: QuantityExpression(kind: .text, text: " "),
        ingredientText: "water"
      ),
      RecipeIngredient(
        quantity: QuantityExpression(
          kind: .approximate,
          lowerBound: RationalQuantity(numerator: 2),
          upperBound: RationalQuantity(numerator: 9)
        ),
        ingredientText: "carrots"
      ),
    ]
    return RecipeDraft(
      title: "Soup",
      ingredientSections: [
        IngredientSection(ingredients: ingredients),
        IngredientSection(title: " Empty ", ingredients: []),
        IngredientSection(ingredients: []),
      ],
      instructionSections: [
        InstructionSection(steps: [InstructionStep(text: " \n ")]),
        InstructionSection(title: " Notes ", steps: []),
        InstructionSection(steps: []),
      ]
    )
  }

  private func repository() throws -> SwiftDataRecipeRepository {
    SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
  }
}
