// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryPersistence

@MainActor
public protocol SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe]
}

/// Creates the first Kitchen and its samples as one durable transaction.
@MainActor
public struct KitchenBootstrapService {
  private let repository: any RecipeRepository
  private let samples: any SampleRecipeProviding

  public init(repository: any RecipeRepository, samples: any SampleRecipeProviding) {
    self.repository = repository
    self.samples = samples
  }

  public func prepareInitialKitchen(named name: String = "Home Kitchen") throws -> Kitchen {
    if let existingKitchen = try repository.kitchens().first { return existingKitchen }
    let kitchen = Kitchen(name: name)
    let sampleRecipes = try samples.recipes(in: kitchen.id)
    try repository.create(kitchen, with: sampleRecipes)
    return kitchen
  }
}

/// Replaces one Kitchen only after every bundled sample has been decoded.
@MainActor
public struct KitchenResetService {
  private let repository: any RecipeRepository
  private let samples: any SampleRecipeProviding

  public init(repository: any RecipeRepository, samples: any SampleRecipeProviding) {
    self.repository = repository
    self.samples = samples
  }

  public func reset(kitchenID: Kitchen.ID) throws {
    let sampleRecipes = try samples.recipes(in: kitchenID)
    try repository.replaceRecipes(in: kitchenID, with: sampleRecipes)
  }
}
