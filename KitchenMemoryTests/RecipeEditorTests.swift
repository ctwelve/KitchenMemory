// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryLogic
import KitchenMemoryDomain
import KitchenMemoryPersistence
import XCTest

@MainActor
final class RecipeEditorTests: XCTestCase {
  func testCreatesARecipeFromTextFirstDraft() throws {
    let (kitchen, repository, editor) = try makeEditor()

    let stored = try editor.create(
      in: kitchen.id,
      from: RecipeDraft(
        title: "  Tomato Soup  ",
        summary: "  A weekday favorite.  ",
        contentLanguage: RecipeContentLanguage(rawValue: "es-MX"),
        ingredientLines: ["2 tomatoes", "", "1 onion"],
        instructionLines: ["Chop the vegetables.", "", "Simmer until soft."]
      )
    )

    XCTAssertEqual(stored.recipe.kitchenID, kitchen.id)
    XCTAssertEqual(stored.revision.revisionNumber, 1)
    XCTAssertEqual(stored.revision.title, "Tomato Soup")
    XCTAssertEqual(stored.revision.summary, "A weekday favorite.")
    XCTAssertEqual(stored.revision.contentLanguage?.rawValue, "es-MX")
    XCTAssertEqual(
      stored.revision.ingredientSections.flatMap(\.ingredients).map(\.originalText),
      ["2 tomatoes", "1 onion"]
    )
    XCTAssertEqual(
      stored.revision.instructionSections.flatMap(\.steps).map(\.text),
      ["Chop the vegetables.", "Simmer until soft."]
    )
    XCTAssertEqual(try repository.recipe(id: stored.recipe.id), stored)
  }

  func testCreatesImportedRevisionWithTaxonomyAndSourceEvidence() throws {
    let (kitchen, _, editor) = try makeEditor()
    let capture = RecipeSourceCapture(
      kind: .schemaOrgJSONLD,
      sourceURL: URL(string: "https://example.com/soup")!,
      capturedAt: Date(timeIntervalSince1970: 1_800_000_000),
      mediaType: "application/ld+json",
      payload: Data("source".utf8),
      blockIndex: 1,
      objectIndex: 2
    )

    let stored = try editor.create(in: kitchen.id, from: RecipeDraft(
      title: "Soup",
      sourceCapture: capture,
      cuisines: ["French"],
      categories: ["Dinner"],
      keywords: ["quick"]
    ))

    XCTAssertEqual(stored.revision.sourceCapture, capture)
    XCTAssertEqual(stored.revision.cuisines, ["French"])
    XCTAssertEqual(stored.revision.categories, ["Dinner"])
    XCTAssertEqual(stored.revision.keywords, ["quick"])
  }

  func testEditingCreatesANewCurrentRevisionAndKeepsTheOldOne() throws {
    let (kitchen, repository, editor) = try makeEditor()
    let first = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Tomato Soup"))

    let edited = try editor.revise(
      recipeID: first.recipe.id,
      from: RecipeDraft(title: "Roasted Tomato Soup", ingredientLines: ["4 tomatoes"])
    )

    XCTAssertNotEqual(edited.revision.id, first.revision.id)
    XCTAssertEqual(edited.revision.revisionNumber, 2)
    XCTAssertEqual(edited.recipe.currentRevisionID, edited.revision.id)
    XCTAssertEqual(
      try repository.revisions(for: first.recipe.id).map(\.title),
      ["Roasted Tomato Soup", "Tomato Soup"]
    )
  }

  func testEditingReidentifiesRevisionLocalContentWithoutMultiplyingRows() throws {
    let (kitchen, repository, editor) = try makeEditor()
    let first = try editor.create(
      in: kitchen.id,
      from: RecipeDraft(
        title: "Tomato Soup",
        ingredientLines: ["4 tomatoes", "1 onion"],
        instructionLines: ["Simmer."]
      )
    )

    var draft = RecipeDraft(revision: first.revision)
    draft.authorName = "Aunt Jo"
    let edited = try editor.revise(recipeID: first.recipe.id, from: draft)
    let reloaded = try XCTUnwrap(repository.recipe(id: first.recipe.id))

    XCTAssertEqual(reloaded.revision.ingredientSections.count, 1)
    XCTAssertEqual(reloaded.revision.ingredientSections.first?.ingredients.count, 2)
    XCTAssertEqual(reloaded.revision.instructionSections.first?.steps.count, 1)
    XCTAssertNotEqual(
      edited.revision.ingredientSections.first?.id,
      first.revision.ingredientSections.first?.id
    )
    XCTAssertNotEqual(
      edited.revision.ingredientSections.first?.ingredients.first?.id,
      first.revision.ingredientSections.first?.ingredients.first?.id
    )
  }

  func testEditingPreservesContentTheTextFirstEditorDoesNotExpose() throws {
    let (kitchen, repository, editor) = try makeEditor()
    let first = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Tomato Soup"))
    let source = RecipeSource(kind: .webpage, title: "Tomato Notes")
    let media = RecipeMedia(role: .hero, assetName: "tomato-soup")
    let originalSections = [
      IngredientSection(title: "Soup", ingredients: [
        RecipeIngredient(
          originalText: "4 tomatoes",
          presentationMode: .original,
          parseState: .reviewed
        ),
      ]),
    ]
    let importedRevision = RecipeRevision(
      id: first.revision.id,
      recipeID: first.recipe.id,
      revisionNumber: 1,
      title: first.revision.title,
      source: source,
      media: [media],
      ingredientSections: originalSections
    )
    try repository.save(recipe: first.recipe, revision: importedRevision)

    let edited = try editor.revise(
      recipeID: first.recipe.id,
      from: RecipeDraft(revision: importedRevision)
    )

    XCTAssertEqual(edited.revision.source, source)
    XCTAssertEqual(edited.revision.media, [media])
    XCTAssertEqual(edited.revision.ingredientSections.map(\.title), originalSections.map(\.title))
    XCTAssertEqual(
      edited.revision.ingredientSections.flatMap(\.ingredients).map(\.originalText),
      originalSections.flatMap(\.ingredients).map(\.originalText)
    )
    XCTAssertEqual(
      edited.revision.ingredientSections.flatMap(\.ingredients).map(\.presentationMode),
      [.original]
    )
  }

  func testCreatesAStructuredRevisionWithMetadataAndOriginalIngredientText() throws {
    let (kitchen, repository, editor) = try makeEditor()
    let ingredient = RecipeIngredient(
      originalText: "2 (14-ounce) cans whole tomatoes",
      unitText: "cans",
      ingredientText: "whole tomatoes",
      parseState: .reviewed
    )
    let stored = try editor.create(in: kitchen.id, from: RecipeDraft(
      title: "Tomato Soup",
      authorName: "Aunt Jo",
      source: RecipeSource(kind: .book, title: "Family Suppers", authorName: "Aunt Jo"),
      recipeYield: RecipeYield(
        quantity: QuantityExpression(
          kind: .exact,
          lowerBound: RationalQuantity(numerator: 4)
        ),
        unitText: "servings",
        originalText: "Serves 4"
      ),
      prepDuration: RecipeDuration(seconds: 900),
      ingredientSections: [IngredientSection(title: "Soup", ingredients: [ingredient])],
      instructionSections: [
        InstructionSection(title: "Cook", steps: [
          InstructionStep(name: "Simmer", text: "Simmer for 20 minutes."),
        ]),
      ]
    ))

    XCTAssertEqual(stored.revision.authorName, "Aunt Jo")
    XCTAssertEqual(stored.revision.source?.title, "Family Suppers")
    XCTAssertEqual(stored.revision.recipeYield?.originalText, "Serves 4")
    XCTAssertEqual(stored.revision.recipeYield?.quantity?.lowerBound, RationalQuantity(numerator: 4))
    XCTAssertEqual(stored.revision.recipeYield?.unitText, "servings")
    XCTAssertEqual(stored.revision.prepDuration?.seconds, 900)
    XCTAssertEqual(stored.revision.ingredientSections.first?.title, "Soup")
    XCTAssertEqual(
      stored.revision.ingredientSections.first?.ingredients.first?.originalText,
      "2 (14-ounce) cans whole tomatoes"
    )
    XCTAssertEqual(
      stored.revision.ingredientSections.first?.ingredients.first?.ingredientText,
      "whole tomatoes"
    )
    XCTAssertEqual(stored.revision.instructionSections.first?.steps.first?.name, "Simmer")
    XCTAssertEqual(try repository.recipe(id: stored.recipe.id), stored)
  }

  func testStructuredAndFreeFormQuantitiesRemainOptionalAndRoundTrip() throws {
    let (kitchen, _, editor) = try makeEditor()
    let preciseIngredient = RecipeIngredient(
      quantity: QuantityExpression(
        kind: .range,
        lowerBound: RationalQuantity(numerator: 2),
        upperBound: RationalQuantity(numerator: 3)
      ),
      unitText: "  cups  ",
      package: PackageDescription(
        quantity: QuantityExpression(
          kind: .exact,
          lowerBound: RationalQuantity(numerator: 14)
        ),
        unitText: "  ounces  "
      ),
      ingredientText: "  tomatoes  "
    )
    let freeFormIngredient = RecipeIngredient(
      quantity: QuantityExpression(kind: .text, text: "  to taste  "),
      ingredientText: "  salt  "
    )

    let stored = try editor.create(
      in: kitchen.id,
      from: RecipeDraft(
        title: "Tomato Soup",
        ingredientSections: [
          IngredientSection(ingredients: [preciseIngredient, freeFormIngredient])
        ]
      )
    )
    let ingredients = stored.revision.ingredientSections.flatMap(\.ingredients)

    XCTAssertEqual(ingredients[0].quantity?.renderedText, "2–3")
    XCTAssertEqual(ingredients[0].unitText, "cups")
    XCTAssertEqual(ingredients[0].package?.unitText, "ounces")
    XCTAssertEqual(ingredients[1].quantity?.renderedText, "to taste")
    XCTAssertNil(ingredients[1].unitText)
    XCTAssertNil(ingredients[1].package)
  }

  func testRejectsAnUntitledDraft() throws {
    let (kitchen, _, editor) = try makeEditor()

    XCTAssertThrowsError(try editor.create(in: kitchen.id, from: RecipeDraft(title: " \n "))) {
      XCTAssertEqual($0 as? RecipeEditorError, .missingTitle)
    }
  }

  // A tuple keeps the setup destructuring concise at each call site.
  // swiftlint:disable:next large_tuple
  private func makeEditor() throws -> (Kitchen, SwiftDataRecipeRepository, RecipeEditor) {
    let kitchen = Kitchen(name: "Test Kitchen")
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    try repository.save(kitchen)
    return (kitchen, repository, RecipeEditor(repository: repository))
  }
}
