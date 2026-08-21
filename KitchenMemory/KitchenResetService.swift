// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryPersistence

/// Restores one Kitchen to the sample content bundled with this app version.
@MainActor
struct KitchenResetService {
  private let repository: any RecipeRepository

  init(repository: any RecipeRepository) {
    self.repository = repository
  }

  func reset(kitchenID: Kitchen.ID) throws {
    let manifest = try SampleRecipeCatalog.loadManifest()
    let samples = try manifest.recipes.map { reference in
      let document = try SampleRecipeCatalog.loadRecipe(reference)
      let materialized = try document.materialize(in: kitchenID)
      return StoredRecipe(recipe: materialized.recipe, revision: materialized.revision)
    }

    // Decode every bundled sample before deleting anything. The repository then
    // performs the destructive replacement in one save, so a malformed bundle
    // cannot leave an otherwise healthy Kitchen half-reset.
    try repository.replaceRecipes(in: kitchenID, with: samples)
  }
}
