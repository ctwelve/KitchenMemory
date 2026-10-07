// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

// swiftlint:disable file_length type_body_length

private struct EncodedRecipeSaveAuthority {
  let ancestry: EncodedRecipeIdentifierSet
  let manifest: EncodedRecipePayloadManifest
  let revision: EncodedRecipeRevision
  let frontier: EncodedRecipeIdentifierSet
}

/// Accepts immutable Save/Selection envelopes and deterministic legacy backfill.
/// The caller owns the transaction; this writer never saves or changes contexts.
@MainActor
final class RecipeAuthorityWriter {
  private let context: ModelContext
  private let payloads: RecipePayloadStore
  private let kitchens: KitchenRecordStore

  init(context: ModelContext, payloads: RecipePayloadStore, kitchens: KitchenRecordStore) {
    self.context = context
    self.payloads = payloads
    self.kitchens = kitchens
  }

  func validate(
    _ recipes: [StoredRecipe],
    in kitchenID: Kitchen.ID,
    requiresExistingKitchen: Bool = true
  ) throws {
    guard recipes.allSatisfy({ stored in
      stored.recipe.kitchenID == kitchenID
        && stored.revision.recipeID == stored.recipe.id
        && stored.recipe.currentRevisionID == stored.revision.id
    }) else {
      throw KitchenMemoryPersistenceError.inconsistentRecipeIdentity
    }
    if requiresExistingKitchen, try kitchens.kitchen(id: kitchenID) == nil {
      throw KitchenMemoryPersistenceError.missingKitchen
    }

    var recipeIDs = Set<Recipe.ID>()
    var revisionIDs = Set<RecipeRevision.ID>()
    for stored in recipes {
      guard recipeIDs.insert(stored.recipe.id).inserted else {
        throw KitchenMemoryPersistenceError.duplicateRecipeID(recipeID: stored.recipe.id)
      }
      guard revisionIDs.insert(stored.revision.id).inserted else {
        throw KitchenMemoryPersistenceError.duplicateRevisionID(revisionID: stored.revision.id)
      }
    }
    for stored in recipes {
      try payloads.validateOwnership(of: stored.recipe)
      try payloads.validateOwnership(of: stored.revision)
    }
  }

  func accept(_ command: RecipeSaveCommand) throws {
    let encoded = try validateAndEncode(command)
    let saveID = command.id.rawValue
    let saved = try context.fetch(
      FetchDescriptor<RecipeSaveRecord>(predicate: #Predicate { $0.id == saveID })
    )
    guard saved.allSatisfy({ saveRecord($0, matches: command, encoded: encoded) }) else {
      throw KitchenMemoryPersistenceError.recipeSaveCommandCollision(commandID: command.id)
    }
    let selectionID = command.selection.id.rawValue
    let selections = try context.fetch(
      FetchDescriptor<RecipeSelectionRecord>(predicate: #Predicate { $0.id == selectionID })
    )
    guard selections.allSatisfy({ selectionRecord($0, matches: command, encoded: encoded) }) else {
      throw KitchenMemoryPersistenceError.recipeSelectionCommandCollision(
        commandID: command.selection.id
      )
    }
    let revisions = try matchingRevisionRecords(for: command)
    try payloads.upsert(command.recipe)
    if revisions.isEmpty {
      try payloads.replace(command.revision)
    } else {
      try payloads.restoreImagePayloads(for: command.revision)
    }
    if saved.isEmpty {
      context.insert(saveRecord(for: command, encoded: encoded))
    }
    if selections.isEmpty {
      context.insert(selectionRecord(for: command, encoded: encoded))
    }
  }

  func acceptSelection(_ command: RecipeSelectionCommand) throws {
    guard Set(command.observedSelectionIDs).count == command.observedSelectionIDs.count else {
      throw KitchenMemoryPersistenceError.invalidRecipeSaveCommand
    }
    let revisionID = command.selectedRevisionID.rawValue
    let acceptedSaves = try context.fetch(
      FetchDescriptor<RecipeSaveRecord>(predicate: #Predicate { $0.revisionID == revisionID })
    )
    guard acceptedSaves.contains(where: {
      $0.kitchenID == command.kitchenID.rawValue && $0.recipeID == command.recipeID.rawValue
    }) else {
      throw KitchenMemoryPersistenceError.invalidRecipeSaveCommand
    }
    let observedIDs = Set(command.observedSelectionIDs.map(\.rawValue))
    let observedRecords = try context.fetch(FetchDescriptor<RecipeSelectionRecord>()).filter {
      observedIDs.contains($0.id)
        && $0.kitchenID == command.kitchenID.rawValue
        && $0.recipeID == command.recipeID.rawValue
    }
    guard Set(observedRecords.map(\.id)) == observedIDs else {
      throw KitchenMemoryPersistenceError.invalidRecipeSaveCommand
    }
    let frontier = RecipeIdentifierSetCodec.encode(command.observedSelectionIDs.map(\.rawValue))
    let selectionID = command.id.rawValue
    let existing = try context.fetch(
      FetchDescriptor<RecipeSelectionRecord>(predicate: #Predicate { $0.id == selectionID })
    )
    guard existing.allSatisfy({ selectionRecord($0, matches: command, frontier: frontier) }) else {
      throw KitchenMemoryPersistenceError.recipeSelectionCommandCollision(commandID: command.id)
    }
    if existing.isEmpty {
      context.insert(selectionRecord(for: command, frontier: frontier))
    }
    let recipeID = command.recipeID.rawValue
    for record in try context.fetch(
      FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == recipeID })
    ) where record.kitchenID == command.kitchenID.rawValue {
      record.currentRevisionID = revisionID
    }
  }

  func backfillLegacyAuthority(in kitchenID: Kitchen.ID) throws {
    let kitchenIdentifier = kitchenID.rawValue
    let recipeRecords = try context.fetch(
      FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.kitchenID == kitchenIdentifier })
    )
    let recipeIDs = Set(recipeRecords.map(\.id))
    let saveRecords = try context.fetch(FetchDescriptor<RecipeSaveRecord>())
    let selectionRecords = try context.fetch(FetchDescriptor<RecipeSelectionRecord>())
    var authoritativeRecipeIDs = Set(saveRecords.map(\.recipeID))
    authoritativeRecipeIDs.formUnion(selectionRecords.map(\.recipeID))
    authoritativeRecipeIDs.formUnion(
      try context.fetch(FetchDescriptor<RecipePruneRecord>()).map(\.recipeID)
    )
    let reservedSaveIDs = Set(saveRecords.map(\.id))
    let reservedSelectionIDs = Set(selectionRecords.map(\.id))
    let legacyRecipeIDs = recipeIDs.subtracting(authoritativeRecipeIDs)
    for recipeID in legacyRecipeIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
      try backfillLegacyRecipe(
        id: recipeID,
        records: recipeRecords.filter { $0.id == recipeID },
        kitchenID: kitchenID,
        reservedSaveIDs: reservedSaveIDs,
        reservedSelectionIDs: reservedSelectionIDs
      )
    }

    for restoration in try context.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>())
    where recipeIDs.contains(restoration.recipeID) && restoration.kitchenID == nil {
      restoration.kitchenID = kitchenIdentifier
    }
  }

  private func backfillLegacyRecipe(
    id recipeID: UUID,
    records: [RecipeRecord],
    kitchenID: Kitchen.ID,
    reservedSaveIDs: Set<UUID>,
    reservedSelectionIDs: Set<UUID>
  ) throws {
    let revisionRecords = try context.fetch(
      FetchDescriptor<RecipeRevisionRecord>(predicate: #Predicate { $0.recipeID == recipeID })
    )
    let revisions: [RecipeRevision]
    switch IdentityCollection.coalesce(try revisionRecords.map(payloads.domainRevision), id: \RecipeRevision.id) {
    case let .coalesced(values): revisions = values
    case .collision:
      throw KitchenMemoryPersistenceError.invalidStoredValue(field: "recipe.authority")
    }
    let revisionIDs = Set(revisions.map(\.id))
    let selectedIDs = Set(records.map { RecipeRevision.ID(rawValue: $0.currentRevisionID) })
    guard selectedIDs.isSubset(of: revisionIDs) else {
      throw KitchenMemoryPersistenceError.missingCurrentRevision
    }
    for revision in revisions {
      guard !reservedSaveIDs.contains(revision.id.rawValue) else {
        throw KitchenMemoryPersistenceError.recipeSaveCommandCollision(
          commandID: .init(rawValue: revision.id.rawValue)
        )
      }
      guard !selectedIDs.contains(revision.id)
        || !reservedSelectionIDs.contains(revision.id.rawValue)
      else {
        throw KitchenMemoryPersistenceError.recipeSelectionCommandCollision(
          commandID: .init(rawValue: revision.id.rawValue)
        )
      }
    }
    for revision in revisions.sorted(by: { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }) {
      try backfillLegacyRevision(
        revision,
        kitchenID: kitchenID,
        isSelected: selectedIDs.contains(revision.id)
      )
    }
  }

  private func backfillLegacyRevision(
    _ revision: RecipeRevision,
    kitchenID: Kitchen.ID,
    isSelected: Bool
  ) throws {
    let recipe = Recipe(
      id: revision.recipeID,
      kitchenID: kitchenID,
      currentRevisionID: revision.id
    )
    let selection = RecipeSelectionCommand(
      id: .init(rawValue: revision.id.rawValue),
      kitchenID: kitchenID,
      recipeID: recipe.id,
      selectedRevisionID: revision.id,
      selectedAt: .distantPast
    )
    let command = RecipeSaveCommand(
      id: .init(rawValue: revision.id.rawValue),
      recipe: recipe,
      revision: revision,
      savedAt: .distantPast,
      parentRevisionIDs: [],
      selection: selection
    )
    let encoded = try validateAndEncode(command)
    context.insert(saveRecord(for: command, encoded: encoded))
    if isSelected {
      context.insert(selectionRecord(for: command, encoded: encoded))
    }
  }

  private func validateAndEncode(
    _ command: RecipeSaveCommand
  ) throws -> EncodedRecipeSaveAuthority {
    let recipe = command.recipe
    let revision = command.revision
    let selection = command.selection
    try validate([StoredRecipe(recipe: recipe, revision: revision)], in: recipe.kitchenID)
    guard selection.kitchenID == recipe.kitchenID,
      selection.recipeID == recipe.id,
      selection.selectedRevisionID == revision.id,
      !command.parentRevisionIDs.contains(revision.id),
      Set(command.parentRevisionIDs).count == command.parentRevisionIDs.count,
      Set(selection.observedSelectionIDs).count == selection.observedSelectionIDs.count
    else { throw KitchenMemoryPersistenceError.invalidRecipeSaveCommand }
    try validateCausalReferences(
      parentRevisionIDs: command.parentRevisionIDs,
      observedSelectionIDs: selection.observedSelectionIDs,
      kitchenID: recipe.kitchenID,
      recipeID: recipe.id
    )
    let manifest = RecipePayloadManifest(revision: revision)
    guard manifestCollectionsAreUnique(manifest) else {
      throw KitchenMemoryPersistenceError.invalidRecipeSaveCommand
    }
    return try EncodedRecipeSaveAuthority(
      ancestry: RecipeIdentifierSetCodec.encode(command.parentRevisionIDs.map(\.rawValue)),
      manifest: RecipePayloadManifestCodec.encode(manifest),
      revision: RecipeRevisionCodec.encode(revision),
      frontier: RecipeIdentifierSetCodec.encode(selection.observedSelectionIDs.map(\.rawValue))
    )
  }

  private func validateCausalReferences(
    parentRevisionIDs: [RecipeRevision.ID],
    observedSelectionIDs: [RecipeSelectionCommand.ID],
    kitchenID: Kitchen.ID,
    recipeID: Recipe.ID
  ) throws {
    let parentIDs = Set(parentRevisionIDs.map(\.rawValue))
    let savedParents = try context.fetch(FetchDescriptor<RecipeSaveRecord>()).filter {
      parentIDs.contains($0.revisionID)
        && $0.kitchenID == kitchenID.rawValue
        && $0.recipeID == recipeID.rawValue
    }
    let observedIDs = Set(observedSelectionIDs.map(\.rawValue))
    let observedSelections = try context.fetch(FetchDescriptor<RecipeSelectionRecord>()).filter {
      observedIDs.contains($0.id)
        && $0.kitchenID == kitchenID.rawValue
        && $0.recipeID == recipeID.rawValue
    }
    guard Set(savedParents.map(\.revisionID)) == parentIDs,
      Set(observedSelections.map(\.id)) == observedIDs
    else { throw KitchenMemoryPersistenceError.invalidRecipeSaveCommand }
  }

  private func matchingRevisionRecords(
    for command: RecipeSaveCommand
  ) throws -> [RecipeRevisionRecord] {
    let revisionID = command.revision.id.rawValue
    let records = try context.fetch(
      FetchDescriptor<RecipeRevisionRecord>(predicate: #Predicate { $0.id == revisionID })
    )
    let expected = try RecipeRevisionCodec.encode(command.revision)
    guard try records.allSatisfy({
      try RecipeRevisionCodec.encode(payloads.domainRevision(from: $0)) == expected
    }) else {
      throw KitchenMemoryPersistenceError.recipeSaveCommandCollision(commandID: command.id)
    }
    return records
  }

  private func saveRecord(
    _ record: RecipeSaveRecord,
    matches command: RecipeSaveCommand,
    encoded: EncodedRecipeSaveAuthority
  ) -> Bool {
    record.kitchenID == command.recipe.kitchenID.rawValue
      && record.recipeID == command.recipe.id.rawValue
      && record.revisionID == command.revision.id.rawValue
      && record.savedAt == command.savedAt
      && record.ancestryFormatVersion == encoded.ancestry.formatVersion
      && record.parentRevisionIDsData == encoded.ancestry.data
      && record.payloadManifestFormatVersion == encoded.manifest.formatVersion
      && record.payloadManifestData == encoded.manifest.data
      && record.revisionFormatVersion == encoded.revision.formatVersion
      && record.revisionDigest == encoded.revision.digest
  }

  private func selectionRecord(
    _ record: RecipeSelectionRecord,
    matches command: RecipeSaveCommand,
    encoded: EncodedRecipeSaveAuthority
  ) -> Bool {
    selectionRecord(record, matches: command.selection, frontier: encoded.frontier)
  }

  private func selectionRecord(
    _ record: RecipeSelectionRecord,
    matches command: RecipeSelectionCommand,
    frontier: EncodedRecipeIdentifierSet
  ) -> Bool {
    record.kitchenID == command.kitchenID.rawValue
      && record.recipeID == command.recipeID.rawValue
      && record.selectedRevisionID == command.selectedRevisionID.rawValue
      && record.selectedAt == command.selectedAt
      && record.frontierFormatVersion == frontier.formatVersion
      && record.observedSelectionIDsData == frontier.data
  }

  private func saveRecord(
    for command: RecipeSaveCommand,
    encoded: EncodedRecipeSaveAuthority
  ) -> RecipeSaveRecord {
    RecipeSaveRecord(
      id: command.id.rawValue,
      kitchenID: command.recipe.kitchenID.rawValue,
      recipeID: command.recipe.id.rawValue,
      revisionID: command.revision.id.rawValue,
      savedAt: command.savedAt,
      ancestryFormatVersion: encoded.ancestry.formatVersion,
      parentRevisionIDsData: encoded.ancestry.data,
      payloadManifestFormatVersion: encoded.manifest.formatVersion,
      payloadManifestData: encoded.manifest.data,
      revisionFormatVersion: encoded.revision.formatVersion,
      revisionDigest: encoded.revision.digest
    )
  }

  private func selectionRecord(
    for command: RecipeSaveCommand,
    encoded: EncodedRecipeSaveAuthority
  ) -> RecipeSelectionRecord {
    selectionRecord(for: command.selection, frontier: encoded.frontier)
  }

  private func selectionRecord(
    for command: RecipeSelectionCommand,
    frontier: EncodedRecipeIdentifierSet
  ) -> RecipeSelectionRecord {
    RecipeSelectionRecord(
      id: command.id.rawValue,
      kitchenID: command.kitchenID.rawValue,
      recipeID: command.recipeID.rawValue,
      selectedRevisionID: command.selectedRevisionID.rawValue,
      selectedAt: command.selectedAt,
      frontierFormatVersion: frontier.formatVersion,
      observedSelectionIDsData: frontier.data
    )
  }

  private func manifestCollectionsAreUnique(_ manifest: RecipePayloadManifest) -> Bool {
    Set(manifest.mediaIDs).count == manifest.mediaIDs.count
      && Set(manifest.equipmentIDs).count == manifest.equipmentIDs.count
      && Set(manifest.ingredientSectionIDs).count == manifest.ingredientSectionIDs.count
      && Set(manifest.ingredientIDs).count == manifest.ingredientIDs.count
      && Set(manifest.instructionSectionIDs).count == manifest.instructionSectionIDs.count
      && Set(manifest.instructionStepIDs).count == manifest.instructionStepIDs.count
  }

  func legacyAuthorityCommand(for stored: StoredRecipe) -> RecipeSaveCommand {
    RecipeSaveCommand(
      id: .init(rawValue: stored.revision.id.rawValue),
      recipe: stored.recipe,
      revision: stored.revision,
      savedAt: .distantPast,
      parentRevisionIDs: [],
      selection: RecipeSelectionCommand(
        id: .init(rawValue: stored.revision.id.rawValue),
        kitchenID: stored.recipe.kitchenID,
        recipeID: stored.recipe.id,
        selectedRevisionID: stored.revision.id,
        selectedAt: .distantPast
      )
    )
  }
}

// swiftlint:enable file_length type_body_length
