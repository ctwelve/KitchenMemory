// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryLogic
import KitchenMemoryPersistence

/// Adapts the application-owned asset catalog to UI-independent Kitchen logic.
@MainActor
struct BundledSampleRecipeProvider: SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    let manifest = try SampleRecipeCatalog.loadManifest()
    return try manifest.recipes.map { reference in
      let document = try SampleRecipeCatalog.loadRecipe(reference)
      let materialized = try document.materialize(in: kitchenID)
      return StoredRecipe(recipe: materialized.recipe, revision: materialized.revision)
    }
  }
}
