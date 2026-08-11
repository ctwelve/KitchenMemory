// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryPersistence

/// Read operations used by recipe-library interfaces and automation.
///
/// Keeping this application capability distinct from its repository lets
/// SwiftUI, future App Intents, and automation share the same entry point.
@MainActor
public struct RecipeLibrary {
  private let repository: any RecipeRepository

  public init(repository: any RecipeRepository) {
    self.repository = repository
  }

  public func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    try repository.recipes(in: kitchenID)
  }

  public func recipe(id: Recipe.ID) throws -> StoredRecipe? {
    try repository.recipe(id: id)
  }
}
