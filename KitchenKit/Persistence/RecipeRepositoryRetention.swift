// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation
import SwiftData

extension SwiftDataRecipeRepository {
  /// Revalidates eligibility and commits payload removal with its tombstone atomically.
  public func maintainDeletedRecipes(in kitchenID: Kitchen.ID, at now: Date) throws -> RecipeRetentionResult {
    var result = RecipeRetentionResult()
    try performIsolatedWrite { writer in
      result.expiredTombstoneRecipeIDs = try writer.expireTombstones(in: kitchenID, at: now)
      for item in try writer.deletedRecipes(in: kitchenID) {
        guard let authority = item.recoverableRecipe,
              try writer.retentionWindowHasElapsed(item, at: now),
              try !writer.hasRetainedDependencies(authority) else { continue }
        try writer.prune(authority, at: now)
        result.prunedRecipeIDs.append(item.id)
      }
    }
    return result
  }

  /// One complete authority aggregate per transaction; dependencies are never truncated.
  func maintainRecipeCandidate(_ id: Recipe.ID, in kitchenID: Kitchen.ID, at now: Date,
                               expireTombstone: Bool) throws {
    try performIsolatedWrite { writer in
      if expireTombstone {
        _ = try writer.expireTombstones(in: kitchenID, at: now, recipeID: id.rawValue)
        return
      }
      guard case let .deleted(authority) = try writer.recipeAuthority(id: id),
            authority.recipe.kitchenID == kitchenID else { return }
      let identifier = id.rawValue
      let deletions = try writer.context.fetch(FetchDescriptor<RecipeDeletionRecord>(
        predicate: #Predicate { $0.recipeID == identifier }
      ))
      let restored = try Set(writer.context.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>(
        predicate: #Predicate { $0.recipeID == identifier }
      )).map(\.deletionID))
      let item = DeletedRecipe(id: id, authority: .deleted(authority),
        observedDeletionIDs: deletions.map(\.id).filter { !restored.contains($0) })
      guard try writer.retentionWindowHasElapsed(item, at: now),
            try !writer.hasRetainedDependencies(authority) else { return }
      try writer.prune(authority, at: now)
    }
  }

  private func expireTombstones(
    in kitchenID: Kitchen.ID, at now: Date, recipeID: UUID? = nil
  ) throws -> [Recipe.ID] {
    let identifier = kitchenID.rawValue
    let request: FetchDescriptor<RecipePruneRecord>
    if let recipeID {
      request = FetchDescriptor(predicate: #Predicate { $0.kitchenID == identifier && $0.recipeID == recipeID })
    } else {
      request = FetchDescriptor(predicate: #Predicate { $0.kitchenID == identifier })
    }
    let rows = try context.fetch(request)
    var expired: [Recipe.ID] = []
    for (recipeID, records) in Dictionary(grouping: rows, by: \.recipeID) {
      guard records.allSatisfy({ now >= $0.antiResurrectionUntil && now >= retentionHorizon(after: $0.prunedAt) }),
            try recipeAuthority(id: .init(rawValue: recipeID)) == .pruned else { continue }
      for record in records { context.delete(record) }
      expired.append(.init(rawValue: recipeID))
    }
    return expired.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }
  }

  private func retentionHorizon(after date: Date) -> Date {
    // A conservative fixed horizon covers five years even across leap years.
    date.addingTimeInterval(5 * 366 * 86_400)
  }

  private func retentionWindowHasElapsed(_ item: DeletedRecipe, at now: Date) throws -> Bool {
    let recipeID = item.id.rawValue
    let active = Set(item.observedDeletionIDs)
    let deletions = try context.fetch(FetchDescriptor<RecipeDeletionRecord>(
      predicate: #Predicate { $0.recipeID == recipeID }
    )).filter { active.contains($0.id) }
    return !deletions.isEmpty && deletions.allSatisfy {
      guard let deletedAt = $0.deletedAt else { return false }
      return now.timeIntervalSince(deletedAt) >= 30 * 86_400
    }
  }

  private func hasRetainedDependencies(_ authority: AvailableRecipeAuthority) throws -> Bool {
    let recipeID = authority.recipe.id.rawValue
    let revisions = Set(authority.revisions.map { $0.revision.id.rawValue })
    let media = Set(authority.revisions.flatMap { $0.revision.media.map { $0.id.rawValue } })
    let requiredPayload = Set(authority.revisions.flatMap {
      payloadReferences(RecipePayloadManifest(revision: $0.revision))
    })
    // A malformed cross-aggregate edge must not turn cleanup into further evidence loss.
    for save in try context.fetch(FetchDescriptor<RecipeSaveRecord>()) where save.recipeID != recipeID {
      guard let parents = try? RecipeIdentifierSetCodec.decode(
        formatVersion: save.ancestryFormatVersion, data: save.parentRevisionIDsData
      ) else { return true }
      if !revisions.isDisjoint(with: parents) { return true }
      guard let manifest = try? RecipePayloadManifestCodec.decode(
        formatVersion: save.payloadManifestFormatVersion, data: save.payloadManifestData
      ) else { return true }
      if !requiredPayload.isDisjoint(with: payloadReferences(manifest)) { return true }
    }
    for row in try context.fetch(FetchDescriptor<RecipeMediaRecord>()) where !revisions.contains(row.revisionID) {
      if media.contains(row.id) { return true }
    }
    let ingredientSections = Set(authority.revisions.flatMap { $0.revision.ingredientSections.map { $0.id.rawValue } })
    for row in try context.fetch(FetchDescriptor<IngredientSectionRecord>())
      where !revisions.contains(row.revisionID) && ingredientSections.contains(row.id) { return true }
    let instructionSections = Set(authority.revisions.flatMap { revision in
      revision.revision.instructionSections.map { $0.id.rawValue }
    })
    for row in try context.fetch(FetchDescriptor<InstructionSectionRecord>())
      where !revisions.contains(row.revisionID) && instructionSections.contains(row.id) { return true }
    return try sessionsRetain(media: media, in: authority.recipe.kitchenID)
  }

  private func payloadReferences(_ manifest: RecipePayloadManifest) -> [UUID] {
    manifest.mediaIDs.map(\.rawValue) + manifest.equipmentIDs.map(\.rawValue)
      + manifest.ingredientSectionIDs.map(\.rawValue) + manifest.ingredientIDs.map(\.rawValue)
      + manifest.instructionSectionIDs.map(\.rawValue) + manifest.instructionStepIDs.map(\.rawValue)
  }

  private func sessionsRetain(media: Set<UUID>, in kitchenID: Kitchen.ID) throws -> Bool {
    for root in try context.fetch(FetchDescriptor<CookingSessionRecord>()) {
      guard root.kitchenID == kitchenID.rawValue else { continue }
      guard Data(SHA256.hash(data: root.snapshotData)) == root.snapshotDigest,
            let snapshot = try? ExecutionSnapshotCodec.decode(
              formatVersion: root.snapshotFormatVersion, data: root.snapshotData
            ) else { return true }
      // Recipe/Revision IDs explain provenance; the snapshot owns the cooking content.
      // Media references have no embedded payload and remain hard dependencies.
      if !media.isDisjoint(with: snapshot.media.compactMap { $0.sourceMediaID?.rawValue }) { return true }
    }
    return false
  }

  private func prune(_ authority: AvailableRecipeAuthority, at now: Date) throws {
    let recipeID = authority.recipe.id.rawValue
    let saves = try context.fetch(FetchDescriptor<RecipeSaveRecord>(predicate: #Predicate { $0.recipeID == recipeID }))
    let selections = try context.fetch(FetchDescriptor<RecipeSelectionRecord>(
      predicate: #Predicate { $0.recipeID == recipeID }
    ))
    let deletions = try context.fetch(FetchDescriptor<RecipeDeletionRecord>(
      predicate: #Predicate { $0.recipeID == recipeID }
    ))
    let restorations = try context.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>(
      predicate: #Predicate { $0.recipeID == recipeID }
    ))
    let parents = try Set(saves.flatMap {
      try RecipeIdentifierSetCodec.decode(formatVersion: $0.ancestryFormatVersion, data: $0.parentRevisionIDsData)
    })
    let frontier = RecipeAuthorityFrontierCodec.encode(RecipeAuthorityFrontier(
      revisionHeads: saves.filter { !parents.contains($0.revisionID) }.map { .init(rawValue: $0.revisionID) },
      selectionHeads: try selectionHeads(for: authority.recipe.id),
      deletionIDs: deletions.map(\.id), restorationIDs: restorations.map(\.id)
    ))
    let horizon = retentionHorizon(after: now)
    context.insert(RecipePruneRecord(
      id: UUID(), kitchenID: authority.recipe.kitchenID.rawValue, recipeID: recipeID,
      prunedAt: now, antiResurrectionUntil: horizon, frontierFormatVersion: frontier.formatVersion,
      frontierData: frontier.data, frontierDigest: frontier.digest
    ))
    for revision in try context.fetch(FetchDescriptor<RecipeRevisionRecord>(
      predicate: #Predicate { $0.recipeID == recipeID }
    )) {
      try deleteRevisionRows(revisionID: revision.id)
      context.delete(revision)
    }
    for recipe in try context.fetch(FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == recipeID })) {
      context.delete(recipe)
    }
    for row in saves { context.delete(row) }
    for row in selections { context.delete(row) }
    for row in deletions { context.delete(row) }
    for row in restorations { context.delete(row) }
  }
}
