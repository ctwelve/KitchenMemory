// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryApplication
import KitchenMemoryDomain
import KitchenMemoryPersistence
import XCTest

@MainActor
final class RecipeLibraryTests: XCTestCase {
  func testListsOnlyRecipesFromTheRequestedKitchen() throws {
    let kitchen = Kitchen(name: "Home")
    let otherKitchen = Kitchen(name: "Cabin")
    let repository = InMemoryRecipeRepository()
    let library = RecipeLibrary(repository: repository)
    let homeRecipe = makeStoredRecipe(title: "Apple Crisp", kitchenID: kitchen.id)
    let cabinRecipe = makeStoredRecipe(title: "Chili", kitchenID: otherKitchen.id)
    repository.storedRecipes = [homeRecipe, cabinRecipe]

    XCTAssertEqual(try library.recipes(in: kitchen.id), [homeRecipe])
  }

  func testLoadsARecipeByStableIdentifier() throws {
    let repository = InMemoryRecipeRepository()
    let library = RecipeLibrary(repository: repository)
    let stored = makeStoredRecipe(title: "Apple Crisp", kitchenID: Kitchen.ID())
    repository.storedRecipes = [stored]

    XCTAssertEqual(try library.recipe(id: stored.recipe.id), stored)
  }

  func testListsSavedRevisionsNewestFirst() throws {
    let repository = InMemoryRecipeRepository()
    let library = RecipeLibrary(repository: repository)
    let recipeID = Recipe.ID()
    let older = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "First Draft")
    let newer = RecipeRevision(recipeID: recipeID, revisionNumber: 2, title: "Family Draft")
    repository.revisionsByRecipeID[recipeID] = [newer, older]

    XCTAssertEqual(try library.revisions(for: recipeID), [newer, older])
  }

  private func makeStoredRecipe(title: String, kitchenID: Kitchen.ID) -> StoredRecipe {
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: title)
    return StoredRecipe(
      recipe: Recipe(
        id: recipeID,
        kitchenID: kitchenID,
        currentRevisionID: revision.id
      ),
      revision: revision
    )
  }
}

@MainActor
private final class InMemoryRecipeRepository: RecipeRepository {
  var storedRecipes: [StoredRecipe] = []
  var revisionsByRecipeID: [Recipe.ID: [RecipeRevision]] = [:]

  func save(_ kitchen: Kitchen) throws {}
  func save(recipe: Recipe, revision: RecipeRevision) throws {}
  func kitchens() throws -> [Kitchen] { [] }
  func kitchen(id: Kitchen.ID) throws -> Kitchen? { nil }

  func recipe(id: Recipe.ID) throws -> StoredRecipe? {
    storedRecipes.first { $0.recipe.id == id }
  }

  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    storedRecipes.filter { $0.recipe.kitchenID == kitchenID }
  }

  func revisions(for recipeID: Recipe.ID) throws -> [RecipeRevision] {
    revisionsByRecipeID[recipeID, default: []]
  }
}
