// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryApplication
import KitchenMemoryDomain
import KitchenMemoryPersistence
import Observation

@MainActor
@Observable
final class RecipeLibraryModel {
  private let kitchenID: Kitchen.ID
  private let library: RecipeLibrary

  private(set) var recipes: [StoredRecipe] = []
  var selectedRecipeID: Recipe.ID?
  private(set) var errorMessage: String?
  private(set) var hasLoaded = false

  init(kitchenID: Kitchen.ID, library: RecipeLibrary) {
    self.kitchenID = kitchenID
    self.library = library
  }

  var selectedRecipe: StoredRecipe? {
    recipes.first { $0.recipe.id == selectedRecipeID }
  }

  func loadIfNeeded() {
    guard !hasLoaded else { return }
    reload()
  }

  func reload() {
    do {
      recipes = try library.recipes(in: kitchenID)
      if !recipes.contains(where: { $0.recipe.id == selectedRecipeID }) {
        selectedRecipeID = recipes.first?.recipe.id
      }
      errorMessage = nil
    } catch {
      recipes = []
      selectedRecipeID = nil
      errorMessage = "Kitchen Memory could not read this recipe library."
    }
    hasLoaded = true
  }
}
