// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

/// Adapts the application-owned asset catalog to UI-independent Kitchen logic.
@MainActor
struct BundledSampleRecipeProvider: SampleRecipeProviding {
  let preferredLanguages: [String]

  init(preferredLanguages: [String] = Locale.preferredLanguages) {
    self.preferredLanguages = preferredLanguages
  }

  /// Supplies bundle values when KitchenKit requests samples for a prepared Kitchen.
  ///
  /// Localization and identity checks run here, but this provider does not save.
  /// The calling install operation retains authority over durable publication.
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    let manifest = try SampleRecipeCatalog.loadManifest()
    let references = try SampleRecipeCatalog.localizedRecipes(
      in: manifest,
      preferredLanguages: preferredLanguages
    )
    return try references.map { reference in
      let document = try SampleRecipeCatalog.loadRecipe(reference)
      let materialized = try document.materialize(in: kitchenID)
      return StoredRecipe(recipe: materialized.recipe, revision: materialized.revision)
    }
  }
}
