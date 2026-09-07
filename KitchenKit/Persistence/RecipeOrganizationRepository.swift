// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

@MainActor
public protocol RecipeOrganizationRepository {
  func load(in kitchenID: Kitchen.ID) throws -> RecipeOrganization
  func accept(_ command: RecipeOrganizationCommand, firstSave: RecipeSaveCommand?) throws
}

/// Owns the one local commit boundary for bulk organization and first-Save assignment.
@MainActor
public final class SwiftDataRecipeOrganizationRepository: RecipeOrganizationRepository {
  private let container: ModelContainer

  public init(modelContainer: ModelContainer) { container = modelContainer }

  public func load(in kitchenID: Kitchen.ID) throws -> RecipeOrganization {
    try RecipeOrganization(folders: SwiftDataFolderRepository(modelContainer: container).library(in: kitchenID),
                           tags: SwiftDataTagRepository(modelContainer: container).library(in: kitchenID))
  }

  public func accept(_ command: RecipeOrganizationCommand, firstSave: RecipeSaveCommand? = nil) throws {
    guard command.folders.allSatisfy({ $0.kitchenID == command.kitchenID }),
          command.tags.allSatisfy({ $0.kitchenID == command.kitchenID }) else { throw FolderError.wrongKitchen }
    if let firstSave {
      guard firstSave.recipe.kitchenID == command.kitchenID, firstSave.parentRevisionIDs.isEmpty else {
        throw KitchenMemoryPersistenceError.invalidRecipeSaveCommand
      }
    }
    let context = ModelContext(container)
    try context.transaction {
      if let firstSave { try SwiftDataRecipeRepository(context: context).accept(firstSave) }
      // A retained batch receipt rejects reuse with a changed selection or operation,
      // including an empty batch. Child receipts separately preserve causal retry behavior.
      let receipt = OrganizationAction(id: command.id, authoredAt: command.authoredAt, observed: [],
        payload: BatchReceipt(commandDigest: try OrganizationCoding.digest(command),
                              saveDigest: try firstSave.map(OrganizationCoding.digest)))
      let receipts = OrganizationStore<BatchReceipt>(modelContainer: container,
                                                     namespace: "organization-batches", recipeID: { _ in nil })
      try receipts.append(receipt, in: command.kitchenID, context: context) { snapshot in
        guard snapshot.checkpoints.isEmpty else { throw FolderError.invalidEvidence }
        _ = try OrganizationEvidence(snapshot.actions)
      }
      let folders = SwiftDataFolderRepository(modelContainer: container)
      try folders.append(command.folders, in: command.kitchenID, context: context)
      let tags = SwiftDataTagRepository(modelContainer: container)
      try tags.append(command.tags, in: command.kitchenID, context: context)
    }
  }
}

private struct BatchReceipt: OrganizationPayload {
  let commandDigest: Data
  let saveDigest: Data?
  var compactableRegister: String? { nil }
}
