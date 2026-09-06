// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

extension SwiftDataRecipeRepository {
  public func recoveryRecipes(in kitchenID: Kitchen.ID) throws -> [RecipeRecovery] {
    try recipeIdentifiers(in: kitchenID.rawValue).compactMap { identifier in
      let id = Recipe.ID(rawValue: identifier)
      guard let authority = try recipeAuthority(id: id) else { return nil }
      switch authority {
      case .available, .deleted, .pruned, .recovery(.competingSelections): return nil
      case .unavailable, .recovery:
        return RecipeRecovery(id: id, authority: authority,
                              revisions: try recoveryPayloads(id: id, kitchenID: kitchenID))
      }
    }
  }

  private func recoveryPayloads(id: Recipe.ID, kitchenID: Kitchen.ID) throws -> [RecipeRevision] {
    let identifier = id.rawValue
    let owners = try context.fetch(FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == identifier }))
    let saves = try context.fetch(FetchDescriptor<RecipeSaveRecord>(
      predicate: #Predicate { $0.recipeID == identifier }
    ))
    guard owners.allSatisfy({ $0.kitchenID == kitchenID.rawValue }),
          saves.allSatisfy({ $0.kitchenID == kitchenID.rawValue }) else { return [] }
    let records = try context.fetch(FetchDescriptor<RecipeRevisionRecord>(
      predicate: #Predicate { $0.recipeID == identifier }
    ))
    return Dictionary(grouping: records, by: \.id).values.compactMap { records in
      let values = records.compactMap { try? domainRevision(from: $0) }
      guard values.count == records.count, let first = values.first,
            values.allSatisfy({ $0 == first }),
            !first.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
      return first
    }.sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
  }
}
