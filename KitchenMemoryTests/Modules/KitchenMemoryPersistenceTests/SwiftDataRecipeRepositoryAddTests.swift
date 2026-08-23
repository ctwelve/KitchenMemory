// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
@testable import KitchenMemoryPersistence
import XCTest

@MainActor
final class SwiftDataRecipeRepositoryAddTests: XCTestCase {
  func testAddIsIdempotentAndPreservesRecipesAndRevisionHistory() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)

    let original = makeRecipe(kitchenID: kitchen.id, title: "User Recipe")
    try repository.save(recipe: original.recipe, revision: original.revision)
    let editedRevision = RecipeRevision(
      recipeID: original.id,
      revisionNumber: 2,
      title: "User Recipe Revised"
    )
    let editedRecipe = Recipe(
      id: original.id,
      kitchenID: kitchen.id,
      currentRevisionID: editedRevision.id
    )
    try repository.save(recipe: editedRecipe, revision: editedRevision)

    let sample = makeRecipe(kitchenID: kitchen.id, title: "Sample")
    try repository.addRecipes([sample], to: kitchen.id)
    try repository.addRecipes([sample], to: kitchen.id)

    XCTAssertEqual(
      Set(try repository.recipes(in: kitchen.id).map(\.id)),
      Set([original.id, sample.id])
    )
    XCTAssertEqual(
      try repository.revisions(for: original.id).map(\.id),
      [editedRevision.id, original.revision.id]
    )
  }

  private func makeRecipe(kitchenID: Kitchen.ID, title: String) -> StoredRecipe {
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: title)
    return StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id),
      revision: revision
    )
  }
}
