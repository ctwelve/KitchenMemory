// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class RecipeRetentionEvidenceTests: XCTestCase {
  func testUnknownOrRecentDeletionDatesKeepPayloadRecoverable() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let recipe = try RecipeEditor(repository: repository).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let replica = ModelContext(container)
    replica.insert(RecipeDeletionRecord(id: UUID(), recipeID: recipe.id.rawValue, kitchenID: kitchen.id.rawValue))
    try replica.save()
    XCTAssertTrue(try repository.maintainDeletedRecipes(in: kitchen.id, at: Date.distantFuture).prunedRecipeIDs.isEmpty)
    XCTAssertEqual(try repository.revisions(for: recipe.id).count, 1)
    XCTAssertTrue(try repository.recoveryRecipes(in: kitchen.id).isEmpty)
  }

  func testSharedSectionDependencyCannotBeRemovedWithDeletedRecipe() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let ingredients = [IngredientSection(ingredients: [RecipeIngredient(originalText: "salt")])]
    let source = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Soup", ingredientSections: ingredients))
    let live = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Stew", ingredientSections: ingredients))
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: source.id,
                                              deletedAt: now.addingTimeInterval(-31 * 86_400)))
    XCTAssertTrue(try repository.maintainDeletedRecipes(in: kitchen.id, at: now).prunedRecipeIDs.isEmpty)
    XCTAssertEqual(try repository.recipe(id: live.id)?.revision.ingredientSections, live.revision.ingredientSections)
  }
}
