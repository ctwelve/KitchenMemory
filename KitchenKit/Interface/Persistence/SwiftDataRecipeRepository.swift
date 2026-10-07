// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

// swiftlint:disable file_length type_body_length

/// A SwiftData implementation of ``RecipeRepository``.
///
/// All access is main-actor isolated because `ModelContext` is an actor-bound
/// unit of work. Later background import can create its own repository and
/// context rather than passing managed records between actors.
@MainActor
public final class SwiftDataRecipeRepository: RecipeRepository {
  let context: ModelContext
  private let payloads: RecipePayloadStore
  private let authorityReader: RecipeAuthorityReader
  private let authorityWriter: RecipeAuthorityWriter
  private let kitchenRecords: KitchenRecordStore

  /// Creates a main-actor read context over the supplied container; writes use isolated contexts.
  public init(modelContainer: ModelContainer) {
    let context = ModelContext(modelContainer)
    self.context = context
    let payloads = RecipePayloadStore(context: context)
    let kitchens = KitchenRecordStore(context: context)
    self.payloads = payloads
    self.kitchenRecords = kitchens
    self.authorityReader = RecipeAuthorityReader(context: context, payloads: payloads)
    self.authorityWriter = RecipeAuthorityWriter(context: context, payloads: payloads, kitchens: kitchens)
  }

  init(context: ModelContext) {
    self.context = context
    let payloads = RecipePayloadStore(context: context)
    let kitchens = KitchenRecordStore(context: context)
    self.payloads = payloads
    self.kitchenRecords = kitchens
    self.authorityReader = RecipeAuthorityReader(context: context, payloads: payloads)
    self.authorityWriter = RecipeAuthorityWriter(context: context, payloads: payloads, kitchens: kitchens)
  }

  /// Persists Kitchen identity and name without authorizing Recipe or sample installation.
  public func save(_ kitchen: Kitchen) throws {
    try performIsolatedWrite { writer in
      try writer.kitchenRecords.upsert(kitchen)
    }
  }

  /// Atomically creates a previously absent Kitchen and its initial Recipe authority.
  /// Throws when the Kitchen already exists or the supplied ownership/identities are invalid.
  public func create(_ kitchen: Kitchen, with recipes: [StoredRecipe]) throws {
    try performIsolatedWrite { writer in
      guard try writer.kitchen(id: kitchen.id) == nil else {
        throw KitchenMemoryPersistenceError.kitchenAlreadyExists(kitchenID: kitchen.id)
      }
      try writer.authorityWriter.validate(recipes, in: kitchen.id, requiresExistingKitchen: false)
      try writer.kitchenRecords.upsert(kitchen)
      try writer.replaceValidatedRecipes(in: kitchen.id, with: recipes)
    }
  }

  /// Accepts a compatibility Recipe/revision pair through the immutable authority writer.
  /// Callers needing explicit retry control should retain a ``RecipeSaveCommand`` instead.
  public func save(recipe: Recipe, revision: RecipeRevision) throws {
    try save(try compatibilityCommand(recipe: recipe, revision: revision))
  }

  /// Accepts an immutable Save and Selection in one local transaction.
  /// Identical command retry coalesces; changed identity reuse throws. Success establishes
  /// local durability only, and a failed attempt must be retried with the same envelope.
  public func save(_ command: RecipeSaveCommand) throws {
    try performIsolatedWrite { writer in
      try writer.accept(command)
    }
  }

  /// Accepts an immutable choice of an existing accepted Revision.
  /// Its observed Selection frontier preserves concurrent unseen choices rather than using timestamps.
  public func select(_ command: RecipeSelectionCommand) throws {
    try performIsolatedWrite { writer in
      try writer.authorityWriter.acceptSelection(command)
    }
  }

  /// Idempotently gives a valid pre-V5 Recipe graph deterministic Save and
  /// root Selection evidence. The Kitchen transaction is the completion
  /// boundary: a failed pass never leaves partially backfilled authority.
  public func backfillLegacyRecipeAuthority(in kitchenID: Kitchen.ID) throws {
    try performIsolatedWrite { writer in
      try writer.backfillLegacyAuthority(in: kitchenID)
    }
  }

  /// Reads one Kitchen identity, or nil when absent; ownership decoding errors propagate.
  public func kitchen(id: Kitchen.ID) throws -> Kitchen? {
    try kitchenRecords.kitchen(id: id)
  }

  /// Reads locally retained Kitchens as domain values without exposing managed records.
  public func kitchens() throws -> [Kitchen] {
    try kitchenRecords.kitchens()
  }

  /// Atomically claims eligible unowned Kitchens and converges matching owner scope.
  /// Explicit evidence of another owner rejects the operation instead of moving their content.
  public func convergeKitchens(
    into kitchen: Kitchen,
    ownedBy ownerID: KitchenOwner.ID
  ) throws {
    try performIsolatedWrite { writer in
      try writer.kitchenRecords.convergeKitchenRecords(into: kitchen, ownedBy: ownerID)
    }
  }

  /// Reads ordinary current Recipe content, or nil for absent, deleted, pruned, or withheld content.
  /// Use ``recipeAuthority(id:)`` to distinguish withheld classifications; missing required
  /// revision or invalid stored authority may throw rather than supply partial content.
  public func recipe(id: Recipe.ID) throws -> StoredRecipe? {
    try storedRecipe(from: recipeAuthority(id: id))
  }

  /// Classifies all locally retained Recipe authority and payload evidence.
  /// Returns nil only when no routing evidence is known. Partial delivery remains
  /// Unavailable; positive invariant failures require Recovery, without erasing evidence.
  public func recipeAuthority(id: Recipe.ID) throws -> RecipeAuthorityProjection? {
    try authorityReader.authority(id: id, hasLatePayload: hasLatePayload)
  }

  /// Returns explicit comparisons for surviving revision branches or competing Selections.
  /// The compared parent set and observed Selection frontier are retained without choosing a winner.
  public func reconciliations(in kitchenID: Kitchen.ID) throws -> [RecipeReconciliation] {
    try recipeIdentifiers(in: kitchenID.rawValue).compactMap { identifier in
      let recipeID = Recipe.ID(rawValue: identifier)
      let selected: [RecipeRevision.ID]
      switch try recipeAuthority(id: recipeID) {
      case let .available(value): selected = [value.current.id]
      case let .recovery(.competingSelections(ids)): selected = ids
      default: return nil
      }
      let saves = try context.fetch(FetchDescriptor<RecipeSaveRecord>(
        predicate: #Predicate { $0.recipeID == identifier }
      ))
      let parents = try Set(saves.flatMap {
        try RecipeIdentifierSetCodec.decode(formatVersion: $0.ancestryFormatVersion, data: $0.parentRevisionIDsData)
      })
      let candidates = Set(saves.map(\.revisionID)).subtracting(parents).union(selected.map(\.rawValue))
      guard candidates.count > 1 else { return nil }
      let revisions = try revisions(for: recipeID).filter { candidates.contains($0.id.rawValue) }
        .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
      return try RecipeReconciliation(
        kitchenID: kitchenID, revisions: revisions, observedSelectionIDs: selectionHeads(for: recipeID)
      )
    }
  }

  /// Reads ordinary visible Recipes with selected current content.
  /// Deleted, pruned, and Recovery items are withheld; missing required payload or decode failures may throw.
  public func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    let identifier = kitchenID.rawValue
    let deletedIDs = Set(try deletedRecipes(in: kitchenID).map { $0.id.rawValue })
    let recipeIDs = try recipeIdentifiers(in: identifier).filter { !deletedIDs.contains($0) }
    return try recipeIDs
      .compactMap { identifier -> StoredRecipe? in
        let id = Recipe.ID(rawValue: identifier)
        let authority = try recipeAuthority(id: id)
        if case .recovery = authority { return nil }
        return try storedRecipe(from: authority)
      }
      .sorted {
        $0.revision.title.localizedStandardCompare($1.revision.title) == .orderedAscending
      }
  }

  /// Atomically installs supplied content absent from ordinary current Recipe reads.
  /// Visible Recipes are preserved. Compatibility acceptance reuses stable authority
  /// and resolves known deletions; conflicting identity or ownership evidence throws.
  public func addRecipes(_ recipes: [StoredRecipe], to kitchenID: Kitchen.ID) throws {
    try performIsolatedWrite { writer in
      try writer.authorityWriter.validate(recipes, in: kitchenID)
      for stored in recipes {
        guard try writer.recipe(id: stored.id) == nil else { continue }
        try writer.accept(writer.legacyAuthorityCommand(for: stored))
        try writer.restoreActiveDeletions(for: stored.id, in: kitchenID)
      }
    }
  }

  /// Reads retained immutable revisions in descending revision-number order.
  /// Ordering is descriptive and does not decide currentness or resolve competing Selections.
  public func revisions(for recipeID: Recipe.ID) throws -> [RecipeRevision] {
    try authorityReader.revisions(for: recipeID)
  }

  /// Atomically replaces Recipe contents for an explicit reset of this Kitchen.
  /// This Recipe-only operation does not erase Session or organization records; use
  /// ``KitchenResetRepository`` for the complete production reset boundary.
  public func replaceRecipes(in kitchenID: Kitchen.ID, with recipes: [StoredRecipe]) throws {
    try performIsolatedWrite { writer in
      try writer.authorityWriter.validate(recipes, in: kitchenID)
      try writer.replaceValidatedRecipes(in: kitchenID, with: recipes)
    }
  }

  /// Returns the locally observed maximal Selection identities for a Recipe.
  /// Retain this frontier with an edit or choice; it is not evidence of global synchronization.
  public func selectionHeads(
    for recipeID: Recipe.ID
  ) throws -> [RecipeSelectionCommand.ID] {
    try authorityReader.selectionHeads(for: recipeID)
  }

  func resetRecipesInCurrentTransaction(
    in kitchenID: Kitchen.ID,
    with recipes: [StoredRecipe]
  ) throws {
    try authorityWriter.validate(recipes, in: kitchenID)
    let kitchenIdentifier = kitchenID.rawValue
    let recipeRecords = try context.fetch(
      FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.kitchenID == kitchenIdentifier })
    )
    var recipeIDs = Set(recipeRecords.map(\.id))
    recipeIDs.formUnion(try context.fetch(
      FetchDescriptor<RecipeSaveRecord>(predicate: #Predicate { $0.kitchenID == kitchenIdentifier })
    ).map(\.recipeID))
    recipeIDs.formUnion(try context.fetch(
      FetchDescriptor<RecipeDeletionRecord>(
        predicate: #Predicate { $0.kitchenID == kitchenIdentifier }
      )
    ).map(\.recipeID))
    recipeIDs.formUnion(try context.fetch(
      FetchDescriptor<RecipeSelectionRecord>(
        predicate: #Predicate { $0.kitchenID == kitchenIdentifier }
      )
    ).map(\.recipeID))
    recipeIDs.formUnion(try context.fetch(
      FetchDescriptor<RecipePruneRecord>(predicate: #Predicate { $0.kitchenID == kitchenIdentifier })
    ).map(\.recipeID))
    recipeIDs.formUnion(try context.fetch(
      FetchDescriptor<RecipeDeletionResolutionRecord>(
        predicate: #Predicate { $0.kitchenID == kitchenIdentifier }
      )
    ).map(\.recipeID))

    for revision in try context.fetch(FetchDescriptor<RecipeRevisionRecord>())
    where recipeIDs.contains(revision.recipeID) {
      try deleteRevisionRows(revisionID: revision.id)
      context.delete(revision)
    }
    recipeRecords.forEach(context.delete)
    try deleteRecipeAuthorityAndDisposition(kitchenID: kitchenIdentifier, recipeIDs: recipeIDs)
    for stored in recipes {
      try accept(legacyAuthorityCommand(for: stored))
    }
  }

  private func deleteRecipeAuthorityAndDisposition(
    kitchenID: UUID,
    recipeIDs: Set<UUID>
  ) throws {
    for record in try context.fetch(FetchDescriptor<RecipeDeletionRecord>())
    where record.kitchenID == kitchenID || recipeIDs.contains(record.recipeID) {
      context.delete(record)
    }
    for record in try context.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>())
    where record.kitchenID == kitchenID || recipeIDs.contains(record.recipeID) {
      context.delete(record)
    }
    for record in try context.fetch(FetchDescriptor<RecipeSaveRecord>())
    where record.kitchenID == kitchenID || recipeIDs.contains(record.recipeID) {
      context.delete(record)
    }
    for record in try context.fetch(FetchDescriptor<RecipeSelectionRecord>())
    where record.kitchenID == kitchenID || recipeIDs.contains(record.recipeID) {
      context.delete(record)
    }
    for record in try context.fetch(FetchDescriptor<RecipePruneRecord>())
    where record.kitchenID == kitchenID || recipeIDs.contains(record.recipeID) {
      context.delete(record)
    }
  }

  private func storedRecipe(from authority: RecipeAuthorityProjection?) throws -> StoredRecipe? {
    guard let authority else { return nil }
    switch authority {
    case let .available(projected):
      return StoredRecipe(recipe: projected.recipe, revision: projected.current)
    case .deleted, .pruned:
      return nil
    case let .unavailable(reason):
      if case .missingRevision = reason {
        throw KitchenMemoryPersistenceError.missingCurrentRevision
      }
      return nil
    case .recovery:
      throw KitchenMemoryPersistenceError.invalidStoredValue(field: "recipe.authority")
    }
  }

  func recipeIdentifiers(in kitchenID: UUID) throws -> [UUID] {
    try authorityReader.recipeIdentifiers(in: kitchenID)
  }

  func performIsolatedWrite(
    _ operation: (SwiftDataRecipeRepository) throws -> Void
  ) throws {
    // A failed SwiftData save leaves its ModelContext's pending graph changed.
    // Isolating every repository write keeps the long-lived read context
    // immediately usable while `transaction` owns the durable commit/rollback.
    let writer = SwiftDataRecipeRepository(context: ModelContext(context.container))
    try writer.context.transaction {
      try operation(writer)
    }
  }

  func accept(_ command: RecipeSaveCommand) throws {
    try authorityWriter.accept(command)
  }

  func backfillLegacyAuthority(in kitchenID: Kitchen.ID) throws {
    try authorityWriter.backfillLegacyAuthority(in: kitchenID)
  }

  private func replaceValidatedRecipes(
    in kitchenID: Kitchen.ID,
    with recipes: [StoredRecipe]
  ) throws {
    let kitchenIdentifier = kitchenID.rawValue
    let recipeRecords = try context.fetch(
      FetchDescriptor<RecipeRecord>(
        predicate: #Predicate { $0.kitchenID == kitchenIdentifier }
      )
    )
    let recipeIdentifiers = Set(recipeRecords.map(\.id))
    let revisionRecords = try context.fetch(FetchDescriptor<RecipeRevisionRecord>())
      .filter { recipeIdentifiers.contains($0.recipeID) }

    markDeleted(recipeRecords)

    for revision in revisionRecords {
      try deleteRevisionRows(revisionID: revision.id)
      context.delete(revision)
    }
    for recipe in recipeRecords {
      context.delete(recipe)
    }

    for record in try context.fetch(
      FetchDescriptor<RecipeSaveRecord>(
        predicate: #Predicate { $0.kitchenID == kitchenIdentifier }
      )
    ) {
      context.delete(record)
    }
    for record in try context.fetch(
      FetchDescriptor<RecipeSelectionRecord>(
        predicate: #Predicate { $0.kitchenID == kitchenIdentifier }
      )
    ) {
      context.delete(record)
    }
    for record in try context.fetch(
      FetchDescriptor<RecipePruneRecord>(
        predicate: #Predicate { $0.kitchenID == kitchenIdentifier }
      )
    ) {
      context.delete(record)
    }

    for stored in recipes {
      try accept(legacyAuthorityCommand(for: stored))
      try restoreActiveDeletions(for: stored.id, in: kitchenID)
    }
  }

  private func markDeleted(_ recipes: [RecipeRecord]) {
    var deletedRecipeIDs = Set<UUID>()
    for recipe in recipes where deletedRecipeIDs.insert(recipe.id).inserted {
      context.insert(RecipeDeletionRecord(
        id: UUID(),
        recipeID: recipe.id,
        kitchenID: recipe.kitchenID
      ))
    }
  }

  func legacyAuthorityCommand(for stored: StoredRecipe) -> RecipeSaveCommand {
    authorityWriter.legacyAuthorityCommand(for: stored)
  }

  private func compatibilityCommand(
    recipe: Recipe,
    revision: RecipeRevision
  ) throws -> RecipeSaveCommand {
    if let accepted = try acceptedCompatibilityCommand(recipe: recipe, revision: revision) {
      return accepted
    }
    let currentRevision: RecipeRevision?
    switch try recipeAuthority(id: recipe.id) {
    case let .available(authority), let .deleted(authority): currentRevision = authority.current
    case .none, .pruned, .unavailable, .recovery: currentRevision = nil
    }
    // Equal current content necessarily has accepted Save/Selection rows and
    // returned through acceptedCompatibilityCommand above.
    let parents = currentRevision.map { [$0.id] } ?? []
    let selection = RecipeSelectionCommand(
      id: .init(rawValue: revision.id.rawValue),
      kitchenID: recipe.kitchenID,
      recipeID: recipe.id,
      selectedRevisionID: revision.id,
      selectedAt: .distantPast,
      observedSelectionIDs: try selectionHeads(for: recipe.id)
    )
    return RecipeSaveCommand(
      id: .init(rawValue: revision.id.rawValue), recipe: recipe, revision: revision,
      savedAt: .distantPast, parentRevisionIDs: parents, selection: selection
    )
  }

  private func acceptedCompatibilityCommand(
    recipe: Recipe,
    revision: RecipeRevision
  ) throws -> RecipeSaveCommand? {
    let identifier = revision.id.rawValue
    guard let save = try context.fetch(
      FetchDescriptor<RecipeSaveRecord>(predicate: #Predicate { $0.revisionID == identifier })
    ).first,
      let selection = try context.fetch(
        FetchDescriptor<RecipeSelectionRecord>(
          predicate: #Predicate { $0.selectedRevisionID == identifier }
        )
      ).first,
      save.kitchenID == recipe.kitchenID.rawValue,
      save.recipeID == recipe.id.rawValue,
      save.revisionID == identifier,
      selection.kitchenID == recipe.kitchenID.rawValue,
      selection.recipeID == recipe.id.rawValue,
      selection.selectedRevisionID == identifier
    else { return nil }
    do {
      let parents = try RecipeIdentifierSetCodec.decode(
        formatVersion: save.ancestryFormatVersion, data: save.parentRevisionIDsData
      ).map(RecipeRevision.ID.init(rawValue:))
      let frontier = try RecipeIdentifierSetCodec.decode(
        formatVersion: selection.frontierFormatVersion,
        data: selection.observedSelectionIDsData
      ).map(RecipeSelectionCommand.ID.init(rawValue:))
      return RecipeSaveCommand(
        id: .init(rawValue: save.id), recipe: recipe, revision: revision,
        savedAt: save.savedAt, parentRevisionIDs: parents,
        selection: RecipeSelectionCommand(
          id: .init(rawValue: selection.id), kitchenID: recipe.kitchenID,
          recipeID: recipe.id, selectedRevisionID: revision.id,
          selectedAt: selection.selectedAt, observedSelectionIDs: frontier
        )
      )
    } catch {
      throw KitchenMemoryPersistenceError.invalidStoredValue(field: "recipe.authority")
    }
  }

  private func restoreActiveDeletions(
    for recipeID: Recipe.ID,
    in kitchenID: Kitchen.ID
  ) throws {
    let identifier = recipeID.rawValue
    for deletionID in try authorityReader.activeDeletionIDs(for: recipeID) {
      context.insert(RecipeDeletionResolutionRecord(
        id: UUID(),
        deletionID: deletionID,
        recipeID: identifier,
        kitchenID: kitchenID.rawValue,
        restoredAt: Date()
      ))
    }
  }

  func domainRevision(from record: RecipeRevisionRecord) throws -> RecipeRevision {
    try payloads.domainRevision(from: record)
  }

  func deleteRevisionRows(revisionID: UUID) throws {
    try payloads.deleteRevisionRows(revisionID: revisionID)
  }
}

// swiftlint:enable file_length type_body_length
