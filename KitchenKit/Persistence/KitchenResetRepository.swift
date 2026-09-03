// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// One atomic persistence boundary for returning a Kitchen to bundled samples.
@MainActor
public protocol KitchenResetRepository: AnyObject {
  func reset(kitchenID: Kitchen.ID, to recipes: [StoredRecipe]) throws
}

/// The production reset adapter owns every durable record family being erased.
@MainActor
public final class SwiftDataKitchenResetRepository: KitchenResetRepository {
  private let modelContainer: ModelContainer

  public init(modelContainer: ModelContainer) {
    self.modelContainer = modelContainer
  }

  public func reset(kitchenID: Kitchen.ID, to recipes: [StoredRecipe]) throws {
    let context = ModelContext(modelContainer)
    let recipeRepository = SwiftDataRecipeRepository(context: context)
    try context.transaction {
      try recipeRepository.resetRecipesInCurrentTransaction(in: kitchenID, with: recipes)
      try deleteSessions(in: kitchenID, context: context)
    }
  }

  private func deleteSessions(in kitchenID: Kitchen.ID, context: ModelContext) throws {
    let identifier = kitchenID.rawValue
    for record in try context.fetch(
      FetchDescriptor<CookingSessionRecord>(predicate: #Predicate { $0.kitchenID == identifier })
    ) { context.delete(record) }
    for record in try context.fetch(
      FetchDescriptor<SessionFactRecord>(predicate: #Predicate { $0.kitchenID == identifier })
    ) { context.delete(record) }
    for record in try context.fetch(
      FetchDescriptor<SessionClosureRecord>(predicate: #Predicate { $0.kitchenID == identifier })
    ) { context.delete(record) }
    for record in try context.fetch(
      FetchDescriptor<SessionDeletionRecord>(predicate: #Predicate { $0.kitchenID == identifier })
    ) { context.delete(record) }
    for record in try context.fetch(
      FetchDescriptor<SessionDeletionResolutionRecord>(
        predicate: #Predicate { $0.kitchenID == identifier }
      )
    ) { context.delete(record) }
  }
}

/// Keeps Logic-only repository doubles source-compatible without Session storage.
@MainActor
final class RecipeOnlyKitchenResetRepository: KitchenResetRepository {
  private let repository: any RecipeRepository

  init(repository: any RecipeRepository) {
    self.repository = repository
  }

  func reset(kitchenID: Kitchen.ID, to recipes: [StoredRecipe]) throws {
    try repository.replaceRecipes(in: kitchenID, with: recipes)
  }
}
