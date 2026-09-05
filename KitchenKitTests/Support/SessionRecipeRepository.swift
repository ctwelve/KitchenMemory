// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation

@MainActor
final class SessionRecipeRepository: RecipeRepository {
  func save(_ command: RecipeSaveCommand) throws {
    throw KitchenMemoryPersistenceError.recipeSaveUnsupported
  }

  func select(_ command: RecipeSelectionCommand) throws {
    throw KitchenMemoryPersistenceError.recipeSelectionUnsupported
  }

  func selectionHeads(for recipeID: Recipe.ID) throws -> [RecipeSelectionCommand.ID] {
    throw KitchenMemoryPersistenceError.recipeSelectionHeadsUnsupported
  }

  func recipeAuthority(id: Recipe.ID) throws -> RecipeAuthorityProjection? {
    throw KitchenMemoryPersistenceError.recipeAuthorityUnsupported
  }

  func convergeKitchens(into kitchen: Kitchen, ownedBy ownerID: KitchenOwner.ID) throws {
    throw KitchenMemoryPersistenceError.ownershipConvergenceUnsupported
  }

  var stored: [StoredRecipe]
  var readError: Error?

  init(stored: [StoredRecipe], readError: Error? = nil) {
    self.stored = stored
    self.readError = readError
  }

  func save(_ kitchen: Kitchen) throws {}
  func create(_ kitchen: Kitchen, with recipes: [StoredRecipe]) throws { stored = recipes }
  func save(recipe: Recipe, revision: RecipeRevision) throws {
    stored.append(StoredRecipe(recipe: recipe, revision: revision))
  }
  func kitchens() throws -> [Kitchen] { [] }
  func kitchen(id: Kitchen.ID) throws -> Kitchen? { nil }
  func recipe(id: Recipe.ID) throws -> StoredRecipe? {
    if let readError { throw readError }
    return stored.first { $0.id == id }
  }
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    stored.filter { $0.recipe.kitchenID == kitchenID }
  }
  func addRecipes(_ recipes: [StoredRecipe], to kitchenID: Kitchen.ID) throws {
    stored += recipes
  }
  func revisions(for recipeID: Recipe.ID) throws -> [RecipeRevision] {
    if let readError { throw readError }
    return stored.filter { $0.id == recipeID }.map(\.revision)
  }
  func replaceRecipes(in kitchenID: Kitchen.ID, with recipes: [StoredRecipe]) throws {
    stored = recipes
  }
}
