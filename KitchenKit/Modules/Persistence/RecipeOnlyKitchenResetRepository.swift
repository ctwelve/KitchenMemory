// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// Keeps Logic-only repository doubles source-compatible without Session storage.
@MainActor
final class RecipeOnlyKitchenResetRepository: KitchenResetRepository {
  private let repository: any RecipeRepository

  init(repository: any RecipeRepository) {
    self.repository = repository
  }

  /// Atomically replaces this Kitchen's durable contents with explicitly supplied Recipes.
  /// Callers own separate device-local draft and delivery cleanup before invoking reset.
  func reset(kitchenID: Kitchen.ID, to recipes: [StoredRecipe]) throws {
    try repository.replaceRecipes(in: kitchenID, with: recipes)
  }
}
