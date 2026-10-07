// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// The production reset adapter owns every durable record family being erased.
@MainActor
public final class SwiftDataKitchenResetRepository: KitchenResetRepository {
  private let modelContainer: ModelContainer

  /// Binds the container whose Recipe, Session, and organization records the reset owns.
  public init(modelContainer: ModelContainer) {
    self.modelContainer = modelContainer
  }

  /// Replaces Recipe authority and payload, and erases Session and organization evidence in one local transaction.
  /// Validates supplied Recipes before replacement; failure rolls back the transaction.
  /// Kitchen identity remains retained, and local editing/delivery documents are caller-owned.
  public func reset(kitchenID: Kitchen.ID, to recipes: [StoredRecipe]) throws {
    let context = ModelContext(modelContainer)
    let recipeRepository = SwiftDataRecipeRepository(context: context)
    try context.transaction {
      try recipeRepository.resetRecipesInCurrentTransaction(in: kitchenID, with: recipes)
      try deleteSessions(in: kitchenID, context: context)
      try deleteOrganization(in: kitchenID, context: context)
    }
  }

  private func deleteOrganization(in kitchenID: Kitchen.ID, context: ModelContext) throws {
    let identifier = kitchenID.rawValue
    for record in try context.fetch(FetchDescriptor<OrganizationActionRecord>(
      predicate: #Predicate { $0.kitchenID == identifier }
    )) { context.delete(record) }
    for record in try context.fetch(FetchDescriptor<OrganizationCheckpointRecord>(
      predicate: #Predicate { $0.kitchenID == identifier }
    )) { context.delete(record) }
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
