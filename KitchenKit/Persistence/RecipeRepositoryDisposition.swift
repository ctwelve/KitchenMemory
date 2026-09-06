// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

extension SwiftDataRecipeRepository {
  public func delete(_ command: RecipeDeleteCommand) throws {
    try performIsolatedWrite { writer in
      let identifier = command.id
      let existing = try writer.context.fetch(FetchDescriptor<RecipeDeletionRecord>(
        predicate: #Predicate { $0.id == identifier }
      ))
      guard existing.allSatisfy({
        $0.recipeID == command.recipeID.rawValue && $0.kitchenID == command.kitchenID.rawValue
          && $0.deletedAt == command.deletedAt
      }) else { throw RecipeDispositionError.identityCollision }
      if !existing.isEmpty { return }
      try writer.backfillLegacyAuthority(in: command.kitchenID)
      try writer.requireDispositionAuthority(recipeID: command.recipeID, kitchenID: command.kitchenID)
      writer.context.insert(RecipeDeletionRecord(
        id: command.id, recipeID: command.recipeID.rawValue,
        kitchenID: command.kitchenID.rawValue, deletedAt: command.deletedAt
      ))
    }
  }

  public func restore(_ command: RecipeRestoreCommand) throws {
    guard !command.observedDeletionIDs.isEmpty,
          Set(command.observedDeletionIDs).count == command.observedDeletionIDs.count,
          Set(command.restorations.map(\.id)).count == command.restorations.count
    else { throw RecipeDispositionError.invalidCommand }
    try performIsolatedWrite { writer in
      let rows = command.restorations.map { restoration in
        RecipeDeletionResolutionRecord(
          id: restoration.id,
          deletionID: restoration.deletionID, recipeID: command.recipeID.rawValue,
          kitchenID: command.kitchenID.rawValue, restoredAt: command.restoredAt
        )
      }
      let identifiers = Set(rows.map(\.id))
      let existing = try writer.context.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>())
        .filter { identifiers.contains($0.id) }
      for row in existing {
        guard rows.contains(where: {
          $0.id == row.id && $0.deletionID == row.deletionID && $0.recipeID == row.recipeID
            && $0.kitchenID == row.kitchenID && $0.restoredAt == row.restoredAt
        }) else { throw RecipeDispositionError.identityCollision }
      }
      let existingIDs = Set(existing.map(\.id))
      if existingIDs == identifiers { return }
      try writer.backfillLegacyAuthority(in: command.kitchenID)
      try writer.requireDispositionAuthority(recipeID: command.recipeID, kitchenID: command.kitchenID)
      let observed = Set(command.observedDeletionIDs)
      let deletions = try writer.context.fetch(FetchDescriptor<RecipeDeletionRecord>())
        .filter { observed.contains($0.id) }
      guard Set(deletions.map(\.id)) == observed,
            deletions.allSatisfy({
        $0.recipeID == command.recipeID.rawValue && $0.kitchenID == command.kitchenID.rawValue
      }) else { throw RecipeDispositionError.invalidCommand }
      for row in rows where !existingIDs.contains(row.id) { writer.context.insert(row) }
    }
  }

  public func deletedRecipes(in kitchenID: Kitchen.ID) throws -> [DeletedRecipe] {
    let kitchenIdentifier = kitchenID.rawValue
    let deletions = try context.fetch(FetchDescriptor<RecipeDeletionRecord>(
      predicate: #Predicate { $0.kitchenID == kitchenIdentifier }
    ))
    let restorations = try context.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>(
      predicate: #Predicate { $0.kitchenID == kitchenIdentifier || $0.kitchenID == nil }
    ))
    var identifiers = Set(deletions.map(\.recipeID))
    identifiers.formUnion(restorations.filter { $0.kitchenID == kitchenIdentifier }.map(\.recipeID))
    return try identifiers.sorted { $0.uuidString < $1.uuidString }.compactMap { identifier in
      let id = Recipe.ID(rawValue: identifier)
      guard let authority = try recipeAuthority(id: id) else { return nil }
      switch authority {
      case .available, .pruned, .recovery(.lateEvidenceAfterPrune): return nil
      case .deleted, .unavailable, .recovery:
        let resolved = Set(restorations.filter { $0.recipeID == identifier }.map(\.deletionID))
        let observed = Set(deletions.filter { $0.recipeID == identifier }.map(\.id))
          .subtracting(resolved).sorted { $0.uuidString < $1.uuidString }
        return DeletedRecipe(id: id, authority: authority, observedDeletionIDs: observed)
      }
    }
  }

  private func requireDispositionAuthority(recipeID: Recipe.ID, kitchenID: Kitchen.ID) throws {
    guard let authority = try recipeAuthority(id: recipeID) else {
      throw RecipeDispositionError.unavailable
    }
    switch authority {
    case let .available(value), let .deleted(value):
      guard value.recipe.kitchenID == kitchenID else { throw RecipeDispositionError.invalidCommand }
    case .unavailable, .recovery, .pruned:
      throw RecipeDispositionError.unavailable
    }
  }
}
