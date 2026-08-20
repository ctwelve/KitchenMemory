// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryApplication
import KitchenMemoryDomain
import KitchenMemoryPersistence
import Foundation
import Observation

@MainActor
@Observable
final class RecipeLibraryModel {
  private let kitchenID: Kitchen.ID
  private let library: RecipeLibrary
  private let editor: RecipeEditor
  private let importer: any RecipeImportServing

  private(set) var recipes: [StoredRecipe] = []
  var selectedRecipeID: Recipe.ID?
  private(set) var errorMessage: String?
  private(set) var hasLoaded = false

  init(
    kitchenID: Kitchen.ID,
    library: RecipeLibrary,
    editor: RecipeEditor,
    importer: any RecipeImportServing = RecipeImportService()
  ) {
    self.kitchenID = kitchenID
    self.library = library
    self.editor = editor
    self.importer = importer
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

  func createRecipe(from draft: RecipeDraft) -> Bool {
    do {
      let stored = try editor.create(in: kitchenID, from: draft)
      reload()
      selectedRecipeID = stored.recipe.id
      return true
    } catch {
      errorMessage = "Kitchen Memory could not save this recipe."
      return false
    }
  }

  func reviseRecipe(id: Recipe.ID, from draft: RecipeDraft) -> Bool {
    do {
      let stored = try editor.revise(recipeID: id, from: draft)
      reload()
      selectedRecipeID = stored.recipe.id
      return true
    } catch {
      errorMessage = "Kitchen Memory could not save this recipe."
      return false
    }
  }

  func importRecipe(from url: URL) async throws -> [RecipeImportOption] {
    try await importer.importRecipe(from: url)
  }
}
