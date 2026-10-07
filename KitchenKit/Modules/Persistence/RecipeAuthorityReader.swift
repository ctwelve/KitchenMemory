// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData
import Algorithms

/// Reconstructs complete retained evidence before the pure authority projector classifies it.
@MainActor
final class RecipeAuthorityReader {
  private let context: ModelContext
  private let payloads: RecipePayloadStore

  init(context: ModelContext, payloads: RecipePayloadStore) {
    self.context = context
    self.payloads = payloads
  }

  // All synchronized families are collected before deriving ownership.
  // swiftlint:disable:next function_body_length
  func authority(
    id: Recipe.ID,
    hasLatePayload: ([RecipePruneRecord]) throws -> Bool
  ) throws -> RecipeAuthorityProjection? {
    let recipeID = id.rawValue
    let recipeRecords = try context.fetch(
      FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == recipeID })
    )
    let scopedSaveRecords = try context.fetch(
      FetchDescriptor<RecipeSaveRecord>(predicate: #Predicate { $0.recipeID == recipeID })
    )
    let saveIDs = Set(scopedSaveRecords.map(\.id))
    let parentRevisionIDs = Set(scopedSaveRecords.flatMap { record in
      (try? RecipeIdentifierSetCodec.decode(
        formatVersion: record.ancestryFormatVersion,
        data: record.parentRevisionIDsData
      )) ?? []
    })
    let saveRecords = try context.fetch(FetchDescriptor<RecipeSaveRecord>())
      .filter { saveIDs.contains($0.id) || parentRevisionIDs.contains($0.revisionID) }
    let scopedPruneRecords = try context.fetch(
      FetchDescriptor<RecipePruneRecord>(predicate: #Predicate { $0.recipeID == recipeID })
    )
    let pruneIDs = Set(scopedPruneRecords.map(\.id))
    let pruneRecords = try context.fetch(FetchDescriptor<RecipePruneRecord>())
      .filter { pruneIDs.contains($0.id) }
    let scopedSelectionRecords = try context.fetch(
      FetchDescriptor<RecipeSelectionRecord>(predicate: #Predicate { $0.recipeID == recipeID })
    )
    let selectionIDs = Set(scopedSelectionRecords.map(\.id))
    let observedSelectionIDs = Set(scopedSelectionRecords.flatMap { record in
      (try? RecipeIdentifierSetCodec.decode(
        formatVersion: record.frontierFormatVersion,
        data: record.observedSelectionIDsData
      )) ?? []
    })
    let selectionRecords = try context.fetch(FetchDescriptor<RecipeSelectionRecord>())
      .filter { selectionIDs.contains($0.id) || observedSelectionIDs.contains($0.id) }
    let scopedRevisionRecords = try context.fetch(
      FetchDescriptor<RecipeRevisionRecord>(predicate: #Predicate { $0.recipeID == recipeID })
    )
    var revisionIDs = Set(scopedRevisionRecords.map(\.id))
    revisionIDs.formUnion(scopedSaveRecords.map(\.revisionID))
    revisionIDs.formUnion(scopedSelectionRecords.map(\.selectedRevisionID))
    revisionIDs.formUnion(parentRevisionIDs)
    let revisionRecords = try context.fetch(FetchDescriptor<RecipeRevisionRecord>())
      .filter { revisionIDs.contains($0.id) }
    let scopedDeletionRecords = try context.fetch(
      FetchDescriptor<RecipeDeletionRecord>(predicate: #Predicate { $0.recipeID == recipeID })
    )
    let scopedRestorationRecords = try context.fetch(
      FetchDescriptor<RecipeDeletionResolutionRecord>(
        predicate: #Predicate { $0.recipeID == recipeID }
      )
    )
    var deletionIDs = Set(scopedDeletionRecords.map(\.id))
    deletionIDs.formUnion(scopedRestorationRecords.map(\.deletionID))
    let deletionRecords = try context.fetch(FetchDescriptor<RecipeDeletionRecord>())
      .filter { deletionIDs.contains($0.id) }
    let restorationIDs = Set(scopedRestorationRecords.map(\.id))
    let restorationRecords = try context.fetch(
      FetchDescriptor<RecipeDeletionResolutionRecord>()
    ).filter { restorationIDs.contains($0.id) }
    let kitchenIdentifiers = recipeRecords.map(\.kitchenID)
      + saveRecords.map(\.kitchenID)
      + selectionRecords.map(\.kitchenID)
      + deletionRecords.map(\.kitchenID)
      + restorationRecords.compactMap(\.kitchenID)
      + pruneRecords.map(\.kitchenID)
    guard let kitchenIdentifier = kitchenIdentifiers.min(by: {
      $0.uuidString < $1.uuidString
    }) else { return nil }
    if !recipeRecords.isEmpty, saveRecords.isEmpty, selectionRecords.isEmpty,
      pruneRecords.isEmpty {
      return try legacyRecipe(id: id).map { stored in
        .available(AvailableRecipeAuthority(
          recipe: stored.recipe,
          revisions: [ProjectedRecipeRevision(revision: stored.revision, state: .current)]
        ))
      }
    }
    if !pruneRecords.isEmpty {
      let retained = RecipeAuthorityProjector.project(RecipeAuthorityEvidence(
        kitchenID: .init(rawValue: kitchenIdentifier), recipeID: id,
        saves: [], selections: [], revisions: [], prunes: pruneRecords.map(recipePruneEvidence)
      ))
      guard retained == .pruned else { return retained }
      let hasLateRows = !recipeRecords.isEmpty || !revisionRecords.isEmpty || !saveRecords.isEmpty
        || !selectionRecords.isEmpty || !deletionRecords.isEmpty || !restorationRecords.isEmpty
      return try hasLateRows || hasLatePayload(pruneRecords) ? .recovery(.lateEvidenceAfterPrune) : .pruned
    }
    let revisions: [RecipeRevision]
    do {
      revisions = try revisionRecords.map(payloads.domainRevision)
    } catch let RecipePayloadStore.ReconstructionError.collision(revisionID) {
      return .recovery(.payloadCollision(revisionID))
    }
    let evidence = RecipeAuthorityEvidence(
      kitchenID: .init(rawValue: kitchenIdentifier),
      recipeID: id,
      saves: saveRecords.map(recipeSaveEvidence),
      selections: selectionRecords.map(recipeSelectionEvidence),
      revisions: revisions,
      deletions: deletionRecords.map(recipeDeletionEvidence),
      restorations: restorationRecords.map(recipeRestorationEvidence),
      prunes: pruneRecords.map(recipePruneEvidence)
    )
    return RecipeAuthorityProjector.project(evidence)
  }

  private func recipeSaveEvidence(_ record: RecipeSaveRecord) -> RecipeSaveEvidence {
    RecipeSaveEvidence(
      id: record.id,
      kitchenID: .init(rawValue: record.kitchenID),
      recipeID: .init(rawValue: record.recipeID),
      revisionID: .init(rawValue: record.revisionID),
      savedAt: record.savedAt,
      ancestryFormatVersion: record.ancestryFormatVersion,
      parentRevisionIDsData: record.parentRevisionIDsData,
      payloadManifestFormatVersion: record.payloadManifestFormatVersion,
      payloadManifestData: record.payloadManifestData,
      revisionFormatVersion: record.revisionFormatVersion,
      revisionDigest: record.revisionDigest
    )
  }

  private func recipeSelectionEvidence(
    _ record: RecipeSelectionRecord
  ) -> RecipeSelectionEvidence {
    RecipeSelectionEvidence(
      id: record.id,
      kitchenID: .init(rawValue: record.kitchenID),
      recipeID: .init(rawValue: record.recipeID),
      selectedRevisionID: .init(rawValue: record.selectedRevisionID),
      selectedAt: record.selectedAt,
      frontierFormatVersion: record.frontierFormatVersion,
      observedSelectionIDsData: record.observedSelectionIDsData
    )
  }

  private func recipeDeletionEvidence(_ record: RecipeDeletionRecord) -> RecipeDeletionEvidence {
    RecipeDeletionEvidence(
      id: record.id,
      kitchenID: .init(rawValue: record.kitchenID),
      recipeID: .init(rawValue: record.recipeID),
      deletedAt: record.deletedAt
    )
  }

  private func recipeRestorationEvidence(
    _ record: RecipeDeletionResolutionRecord
  ) -> RecipeRestorationEvidence {
    RecipeRestorationEvidence(
      id: record.id,
      deletionID: record.deletionID,
      kitchenID: record.kitchenID.map(Kitchen.ID.init(rawValue:)),
      recipeID: .init(rawValue: record.recipeID),
      restoredAt: record.restoredAt
    )
  }

  private func recipePruneEvidence(_ record: RecipePruneRecord) -> RecipePruneEvidence {
    RecipePruneEvidence(
      id: record.id,
      kitchenID: .init(rawValue: record.kitchenID),
      recipeID: .init(rawValue: record.recipeID),
      prunedAt: record.prunedAt,
      antiResurrectionUntil: record.antiResurrectionUntil,
      frontierFormatVersion: record.frontierFormatVersion,
      frontierData: record.frontierData,
      frontierDigest: record.frontierDigest
    )
  }

  private func legacyRecipe(id: Recipe.ID) throws -> StoredRecipe? {
    let identifier = id.rawValue
    let recipeDescriptor = FetchDescriptor<RecipeRecord>(
      predicate: #Predicate { $0.id == identifier })
    let recipeRecords = try context.fetch(recipeDescriptor)
    // The caller establishes that at least one compatibility Recipe row exists.
    let recipeRecord = recipeRecords[0]
    guard try activeDeletionIDs(for: id).isEmpty else { return nil }
    let currentRevisionIDs = Set(recipeRecords.map(\.currentRevisionID))
    let currentRevisionRecords = try context.fetch(FetchDescriptor<RecipeRevisionRecord>())
      .filter { currentRevisionIDs.contains($0.id) }
    if let mismatched = currentRevisionRecords.first(where: { $0.recipeID != identifier }) {
      throw KitchenMemoryPersistenceError.inconsistentStoredRecipeIdentity(
        recipeID: id,
        revisionID: .init(rawValue: mismatched.id)
      )
    }
    // CloudKit may resolve concurrent writes to RecipeRecord.currentRevisionID
    // with last-writer-wins while retaining both immutable revision rows. Read
    // every revision for the stable recipe identity so the mutable pointer can
    // never erase a valid branch from product-level reconciliation.
    let revisionRecords = try context.fetch(
      FetchDescriptor<RecipeRevisionRecord>(
        predicate: #Predicate { $0.recipeID == identifier }
      )
    )
    guard let revisionRecord = revisionRecords.max(by: Self.precedesForCurrentRevision) else {
      throw KitchenMemoryPersistenceError.missingCurrentRevision
    }
    let recipe = Recipe(
      id: .init(rawValue: recipeRecord.id),
      kitchenID: .init(rawValue: recipeRecord.kitchenID),
      currentRevisionID: .init(rawValue: revisionRecord.id)
    )
    return StoredRecipe(recipe: recipe, revision: try payloads.domainRevision(from: revisionRecord))
  }

  func recipeIdentifiers(in kitchenID: UUID) throws -> [UUID] {
    var identifiers = Set(try context.fetch(
      FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.kitchenID == kitchenID })
    ).map(\.id))
    identifiers.formUnion(try context.fetch(
      FetchDescriptor<RecipeSaveRecord>(predicate: #Predicate { $0.kitchenID == kitchenID })
    ).map(\.recipeID))
    identifiers.formUnion(try context.fetch(
      FetchDescriptor<RecipeSelectionRecord>(predicate: #Predicate { $0.kitchenID == kitchenID })
    ).map(\.recipeID))
    identifiers.formUnion(try context.fetch(
      FetchDescriptor<RecipeDeletionRecord>(predicate: #Predicate { $0.kitchenID == kitchenID })
    ).map(\.recipeID))
    identifiers.formUnion(try context.fetch(
      FetchDescriptor<RecipeDeletionResolutionRecord>(
        predicate: #Predicate { $0.kitchenID == kitchenID }
      )
    ).map(\.recipeID))
    identifiers.formUnion(try context.fetch(
      FetchDescriptor<RecipePruneRecord>(predicate: #Predicate { $0.kitchenID == kitchenID })
    ).map(\.recipeID))
    return identifiers.sorted { $0.uuidString < $1.uuidString }
  }

  func revisions(for recipeID: Recipe.ID) throws -> [RecipeRevision] {
    let identifier = recipeID.rawValue
    let descriptor = FetchDescriptor<RecipeRevisionRecord>(
      predicate: #Predicate { $0.recipeID == identifier }
    )
    return try context.fetch(descriptor)
      .uniqued(on: \.id)
      .map(payloads.domainRevision)
      .sorted { lhs, rhs in
        if lhs.revisionNumber != rhs.revisionNumber {
          return lhs.revisionNumber > rhs.revisionNumber
        }
        return lhs.id.rawValue.uuidString > rhs.id.rawValue.uuidString
      }
  }

  private static func precedesForCurrentRevision(
    _ lhs: RecipeRevisionRecord,
    _ rhs: RecipeRevisionRecord
  ) -> Bool {
    if lhs.revisionNumber != rhs.revisionNumber {
      return lhs.revisionNumber < rhs.revisionNumber
    }
    return lhs.id.uuidString < rhs.id.uuidString
  }

  func selectionHeads(
    for recipeID: Recipe.ID
  ) throws -> [RecipeSelectionCommand.ID] {
    let identifier = recipeID.rawValue
    let records = try context.fetch(
      FetchDescriptor<RecipeSelectionRecord>(predicate: #Predicate { $0.recipeID == identifier })
    )
    do {
      let observed = try records.flatMap { record in
        try RecipeIdentifierSetCodec.decode(
          formatVersion: record.frontierFormatVersion,
          data: record.observedSelectionIDsData
        )
      }
      let observedSet = Set(observed)
      return records.map(\.id).filter { !observedSet.contains($0) }
        .sorted { $0.uuidString < $1.uuidString }
        .map(RecipeSelectionCommand.ID.init(rawValue:))
    } catch {
      throw KitchenMemoryPersistenceError.invalidStoredValue(field: "recipe.authority")
    }
  }

  func activeDeletionIDs(for recipeID: Recipe.ID) throws -> Set<UUID> {
    let identifier = recipeID.rawValue
    let deletions = try context.fetch(
      FetchDescriptor<RecipeDeletionRecord>(
        predicate: #Predicate { $0.recipeID == identifier }
      )
    )
    let resolutions = try context.fetch(
      FetchDescriptor<RecipeDeletionResolutionRecord>(
        predicate: #Predicate { $0.recipeID == identifier }
      )
    )
    return Set(deletions.map(\.id)).subtracting(resolutions.map(\.deletionID))
  }
}
