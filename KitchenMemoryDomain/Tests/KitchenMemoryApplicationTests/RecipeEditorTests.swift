// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryApplication
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
        ingredientLines: ["2 tomatoes", "", "1 onion"],
        instructionLines: ["Chop the vegetables.", "", "Simmer until soft."]
      )
    )

    XCTAssertEqual(stored.recipe.kitchenID, kitchen.id)
    XCTAssertEqual(stored.revision.revisionNumber, 1)
    XCTAssertEqual(stored.revision.title, "Tomato Soup")
    XCTAssertEqual(stored.revision.summary, "A weekday favorite.")
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

  func testEditingPreservesContentTheTextFirstEditorDoesNotExpose() throws {
    let (kitchen, repository, editor) = try makeEditor()
    let first = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Tomato Soup"))
    let source = RecipeSource(kind: .webpage, title: "Tomato Notes")
    let media = RecipeMedia(role: .hero, assetName: "tomato-soup")
    let originalSections = [IngredientSection(title: "Soup", ingredients: [
      RecipeIngredient(originalText: "4 tomatoes", displayText: "4 tomatoes", parseState: .reviewed)
    ])]
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
    XCTAssertEqual(edited.revision.ingredientSections, originalSections)
  }

  func testRejectsAnUntitledDraft() throws {
    let (kitchen, _, editor) = try makeEditor()

    XCTAssertThrowsError(try editor.create(in: kitchen.id, from: RecipeDraft(title: " \n "))) {
      XCTAssertEqual($0 as? RecipeEditorError, .missingTitle)
    }
  }

  private func makeEditor() throws -> (Kitchen, SwiftDataRecipeRepository, RecipeEditor) {
    let kitchen = Kitchen(name: "Test Kitchen")
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    try repository.save(kitchen)
    return (kitchen, repository, RecipeEditor(repository: repository))
  }
}
