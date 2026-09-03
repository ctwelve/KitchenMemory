// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Algorithms
import Foundation
import SwiftData

// Persistence reconstruction is deliberately kept beside its inverse mapping
// so schema changes can be reviewed in both directions.
// swiftlint:disable file_length type_body_length

/// A recipe together with the revision selected as its current content.
public struct StoredRecipe: Equatable, Identifiable, Sendable {
  public var id: Recipe.ID { recipe.id }
  public let recipe: Recipe
  public let revision: RecipeRevision

  public init(recipe: Recipe, revision: RecipeRevision) {
    self.recipe = recipe
    self.revision = revision
  }
}

/// Domain-facing storage operations needed by the first recipe workflow.
///
/// The protocol mentions no SwiftData types, so application use cases and test
/// doubles can depend on it without adopting the persistence framework.
@MainActor
public protocol RecipeRepository: AnyObject {
  func save(_ kitchen: Kitchen) throws
  /// Atomically creates one Kitchen together with its initial recipes.
  func create(_ kitchen: Kitchen, with recipes: [StoredRecipe]) throws
  func save(recipe: Recipe, revision: RecipeRevision) throws
  /// Atomically accepts one caller-identified immutable Save and Selection.
  func save(_ command: RecipeSaveCommand) throws
  func kitchens() throws -> [Kitchen]
  func kitchen(id: Kitchen.ID) throws -> Kitchen?
  /// Atomically claims legacy Kitchens and converges only matching ownership.
  func convergeKitchens(into kitchen: Kitchen, ownedBy ownerID: KitchenOwner.ID) throws
  func recipe(id: Recipe.ID) throws -> StoredRecipe?
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe]
  /// Atomically adds recipes whose stable identities are not already present.
  func addRecipes(_ recipes: [StoredRecipe], to kitchenID: Kitchen.ID) throws
  /// Returns every saved revision for a recipe, newest revision first.
  func revisions(for recipeID: Recipe.ID) throws -> [RecipeRevision]
  /// Atomically replaces every recipe and revision owned by one Kitchen.
  func replaceRecipes(in kitchenID: Kitchen.ID, with recipes: [StoredRecipe]) throws
}

public extension RecipeRepository {
  func save(_ command: RecipeSaveCommand) throws {
    try save(recipe: command.recipe, revision: command.revision)
  }

  func convergeKitchens(into kitchen: Kitchen, ownedBy ownerID: KitchenOwner.ID) throws {
    throw KitchenMemoryPersistenceError.ownershipConvergenceUnsupported
  }
}

private struct EncodedRecipeSaveAuthority {
  let ancestry: EncodedRecipeIdentifierSet
  let manifest: EncodedRecipePayloadManifest
  let revision: EncodedRecipeRevision
  let frontier: EncodedRecipeIdentifierSet
}

/// Failures detected while translating between domain values and stored rows.
public enum KitchenMemoryPersistenceError: Error, Equatable {
  /// The recipe and revision do not refer to each other as current content.
  case inconsistentRecipeIdentity

  /// A recipe cannot be saved before its owning Kitchen exists.
  case missingKitchen

  /// Bootstrap cannot replace an already-created Kitchen implicitly.
  case kitchenAlreadyExists(kitchenID: Kitchen.ID)

  /// Kitchens with explicit different owners must never be merged.
  case kitchenOwnedByAnotherOwner(kitchenID: Kitchen.ID)

  /// A repository adapter has not implemented the V4 ownership operation.
  case ownershipConvergenceUnsupported

  /// A recipe row refers to a revision that is absent from the store.
  case missingCurrentRevision

  /// A stable recipe identity cannot move between Kitchens through an upsert.
  case recipeAlreadyOwnedByAnotherKitchen(recipeID: Recipe.ID)

  /// A stable revision identity cannot move between recipes through an upsert.
  case revisionAlreadyOwnedByAnotherRecipe(revisionID: RecipeRevision.ID)

  /// A bulk replacement must describe each durable recipe identity once.
  case duplicateRecipeID(recipeID: Recipe.ID)

  /// A bulk replacement must describe each durable revision identity once.
  case duplicateRevisionID(revisionID: RecipeRevision.ID)

  /// A stored current revision points back to a different recipe identity.
  case inconsistentStoredRecipeIdentity(
    recipeID: Recipe.ID,
    revisionID: RecipeRevision.ID
  )

  /// Persisted encoded data or an enum raw value cannot be decoded safely.
  case invalidStoredValue(field: String)

  /// One logical Save identity described two different command envelopes.
  case recipeSaveCommandCollision(commandID: RecipeSaveCommand.ID)

  /// One logical Selection identity described two different command envelopes.
  case recipeSelectionCommandCollision(commandID: RecipeSelectionCommand.ID)

  /// A Save command's redundant identities or causal sets are inconsistent.
  case invalidRecipeSaveCommand
}

/// A SwiftData implementation of ``RecipeRepository``.
///
/// All access is main-actor isolated because `ModelContext` is an actor-bound
/// unit of work. Later background import can create its own repository and
/// context rather than passing managed records between actors.
@MainActor
public final class SwiftDataRecipeRepository: RecipeRepository {
  private let context: ModelContext
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  /// New captures share the existing optional source blob so adding source
  /// evidence does not mutate the released SwiftData V1 schema. The decoder
  /// below still accepts the original blob, which contained RecipeSource alone.
  private struct StoredSource: Codable {
    var source: RecipeSource?
    var capture: RecipeSourceCapture
  }

  public init(modelContainer: ModelContainer) {
    self.context = ModelContext(modelContainer)
  }

  private init(context: ModelContext) {
    self.context = context
  }

  public func save(_ kitchen: Kitchen) throws {
    try performIsolatedWrite { writer in
      try writer.upsert(kitchen)
    }
  }

  public func create(_ kitchen: Kitchen, with recipes: [StoredRecipe]) throws {
    try performIsolatedWrite { writer in
      guard try writer.kitchen(id: kitchen.id) == nil else {
        throw KitchenMemoryPersistenceError.kitchenAlreadyExists(kitchenID: kitchen.id)
      }
      try writer.validate(recipes, in: kitchen.id, requiresExistingKitchen: false)
      try writer.upsert(kitchen)
      try writer.replaceValidatedRecipes(in: kitchen.id, with: recipes)
    }
  }

  public func save(recipe: Recipe, revision: RecipeRevision) throws {
    let previousRevision = try revisions(for: recipe.id)
      .filter { $0.id != revision.id }
      .max { lhs, rhs in lhs.revisionNumber < rhs.revisionNumber }
    let parentIDs = previousRevision.map { [$0.id] } ?? []
    let observedSelectionIDs = previousRevision.map {
      [RecipeSelectionCommand.ID(rawValue: $0.id.rawValue)]
    } ?? []
    let selection = RecipeSelectionCommand(
      id: .init(rawValue: revision.id.rawValue),
      kitchenID: recipe.kitchenID,
      recipeID: recipe.id,
      selectedRevisionID: revision.id,
      selectedAt: .distantPast,
      observedSelectionIDs: observedSelectionIDs
    )
    try save(RecipeSaveCommand(
      id: .init(rawValue: revision.id.rawValue),
      recipe: recipe,
      revision: revision,
      savedAt: .distantPast,
      parentRevisionIDs: parentIDs,
      selection: selection
    ))
  }

  public func save(_ command: RecipeSaveCommand) throws {
    try performIsolatedWrite { writer in
      try writer.accept(command)
    }
  }

  public func kitchen(id: Kitchen.ID) throws -> Kitchen? {
    let identifier = id.rawValue
    let descriptor = FetchDescriptor<KitchenRecord>(predicate: #Predicate { $0.id == identifier })
    return try context.fetch(descriptor).first.map {
      Kitchen(
        id: .init(rawValue: $0.id),
        ownerID: try ownerID(for: .init(rawValue: $0.id)),
        name: $0.name
      )
    }
  }

  public func kitchens() throws -> [Kitchen] {
    let descriptor = FetchDescriptor<KitchenRecord>(sortBy: [SortDescriptor(\.name)])
    return try context.fetch(descriptor).uniqued(on: \.id).map {
      Kitchen(
        id: .init(rawValue: $0.id),
        ownerID: try ownerID(for: .init(rawValue: $0.id)),
        name: $0.name
      )
    }
  }

  public func convergeKitchens(
    into kitchen: Kitchen,
    ownedBy ownerID: KitchenOwner.ID
  ) throws {
    try performIsolatedWrite { writer in
      try writer.convergeKitchenRecords(into: kitchen, ownedBy: ownerID)
    }
  }

  public func recipe(id: Recipe.ID) throws -> StoredRecipe? {
    let identifier = id.rawValue
    let recipeDescriptor = FetchDescriptor<RecipeRecord>(
      predicate: #Predicate { $0.id == identifier })
    let recipeRecords = try context.fetch(recipeDescriptor)
    guard let recipeRecord = recipeRecords.first else { return nil }
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
    return StoredRecipe(recipe: recipe, revision: try domainRevision(from: revisionRecord))
  }

  public func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    let identifier = kitchenID.rawValue
    let descriptor = FetchDescriptor<RecipeRecord>(
      predicate: #Predicate { $0.kitchenID == identifier }
    )
    return try context.fetch(descriptor)
      .uniqued(on: \.id)
      .compactMap { try recipe(id: .init(rawValue: $0.id)) }
      .sorted {
        $0.revision.title.localizedStandardCompare($1.revision.title) == .orderedAscending
      }
  }

  public func addRecipes(_ recipes: [StoredRecipe], to kitchenID: Kitchen.ID) throws {
    try performIsolatedWrite { writer in
      try writer.validate(recipes, in: kitchenID)
      for stored in recipes {
        guard try writer.recipe(id: stored.id) == nil else { continue }
        try writer.accept(writer.legacyAuthorityCommand(for: stored))
      }
    }
  }

  public func revisions(for recipeID: Recipe.ID) throws -> [RecipeRevision] {
    let identifier = recipeID.rawValue
    let descriptor = FetchDescriptor<RecipeRevisionRecord>(
      predicate: #Predicate { $0.recipeID == identifier }
    )
    return try context.fetch(descriptor)
      .uniqued(on: \.id)
      .map(domainRevision)
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

  public func replaceRecipes(in kitchenID: Kitchen.ID, with recipes: [StoredRecipe]) throws {
    try performIsolatedWrite { writer in
      try writer.validate(recipes, in: kitchenID)
      try writer.replaceValidatedRecipes(in: kitchenID, with: recipes)
    }
  }

  private func performIsolatedWrite(
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

  private func validate(
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
    if requiresExistingKitchen, try kitchen(id: kitchenID) == nil {
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
      try validateOwnership(of: stored.recipe)
      try validateOwnership(of: stored.revision)
    }
  }

  private func accept(_ command: RecipeSaveCommand) throws {
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
    try upsert(command.recipe)
    if revisions.isEmpty { try replace(command.revision) }
    if saved.isEmpty {
      context.insert(saveRecord(for: command, encoded: encoded))
    }
    if selections.isEmpty {
      context.insert(selectionRecord(for: command, encoded: encoded))
    }
    try resolveDeletions(for: command.recipe.id)
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

  private func matchingRevisionRecords(
    for command: RecipeSaveCommand
  ) throws -> [RecipeRevisionRecord] {
    let revisionID = command.revision.id.rawValue
    let records = try context.fetch(
      FetchDescriptor<RecipeRevisionRecord>(predicate: #Predicate { $0.id == revisionID })
    )
    guard try records.allSatisfy({ try domainRevision(from: $0) == command.revision }) else {
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
    record.kitchenID == command.selection.kitchenID.rawValue
      && record.recipeID == command.selection.recipeID.rawValue
      && record.selectedRevisionID == command.selection.selectedRevisionID.rawValue
      && record.selectedAt == command.selection.selectedAt
      && record.frontierFormatVersion == encoded.frontier.formatVersion
      && record.observedSelectionIDsData == encoded.frontier.data
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
    let selection = command.selection
    return RecipeSelectionRecord(
      id: selection.id.rawValue,
      kitchenID: selection.kitchenID.rawValue,
      recipeID: selection.recipeID.rawValue,
      selectedRevisionID: selection.selectedRevisionID.rawValue,
      selectedAt: selection.selectedAt,
      frontierFormatVersion: encoded.frontier.formatVersion,
      observedSelectionIDsData: encoded.frontier.data
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

    var deletedRecipeIDs = Set<UUID>()
    for recipe in recipeRecords where deletedRecipeIDs.insert(recipe.id).inserted {
      context.insert(
        RecipeDeletionRecord(
          id: UUID(),
          recipeID: recipe.id,
          kitchenID: recipe.kitchenID
        )
      )
    }

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
    }
  }

  private func legacyAuthorityCommand(for stored: StoredRecipe) -> RecipeSaveCommand {
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

  private func activeDeletionIDs(for recipeID: Recipe.ID) throws -> Set<UUID> {
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

  private func resolveDeletions(for recipeID: Recipe.ID) throws {
    let identifier = recipeID.rawValue
    for deletionID in try activeDeletionIDs(for: recipeID) {
      context.insert(
        RecipeDeletionResolutionRecord(
          id: UUID(),
          deletionID: deletionID,
          recipeID: identifier
        )
      )
    }
  }

  private func validateOwnership(of recipe: Recipe) throws {
    let identifier = recipe.id.rawValue
    let descriptor = FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == identifier })
    if let existing = try context.fetch(descriptor).first,
      existing.kitchenID != recipe.kitchenID.rawValue {
      throw KitchenMemoryPersistenceError.recipeAlreadyOwnedByAnotherKitchen(recipeID: recipe.id)
    }
  }

  private func validateOwnership(of revision: RecipeRevision) throws {
    let identifier = revision.id.rawValue
    let descriptor = FetchDescriptor<RecipeRevisionRecord>(
      predicate: #Predicate { $0.id == identifier })
    if let existing = try context.fetch(descriptor).first,
      existing.recipeID != revision.recipeID.rawValue {
      throw KitchenMemoryPersistenceError.revisionAlreadyOwnedByAnotherRecipe(
        revisionID: revision.id)
    }
  }

  private func upsert(_ kitchen: Kitchen) throws {
    let identifier = kitchen.id.rawValue
    let descriptor = FetchDescriptor<KitchenRecord>(predicate: #Predicate { $0.id == identifier })
    if let record = try context.fetch(descriptor).first {
      record.name = kitchen.name
    } else {
      context.insert(KitchenRecord(id: identifier, name: kitchen.name))
    }
    if let ownerID = kitchen.ownerID {
      try replaceOwnership(of: kitchen.id, with: ownerID)
    }
  }

  private func ownerID(for kitchenID: Kitchen.ID) throws -> KitchenOwner.ID? {
    let identifier = kitchenID.rawValue
    let records = try context.fetch(
      FetchDescriptor<KitchenOwnershipRecord>(
        predicate: #Predicate { $0.kitchenID == identifier }
      )
    )
    let owners = Set(records.map(\.ownerID))
    guard owners.count <= 1 else {
      throw KitchenMemoryPersistenceError.kitchenOwnedByAnotherOwner(kitchenID: kitchenID)
    }
    return owners.first.map(KitchenOwner.ID.init(rawValue:))
  }

  private func replaceOwnership(
    of kitchenID: Kitchen.ID,
    with ownerID: KitchenOwner.ID
  ) throws {
    let identifier = kitchenID.rawValue
    var keptCanonicalRecord = false
    for record in try context.fetch(
      FetchDescriptor<KitchenOwnershipRecord>(
        predicate: #Predicate { $0.kitchenID == identifier }
      )
    ) {
      if !keptCanonicalRecord,
        record.id == identifier,
        record.ownerID == ownerID.rawValue {
        keptCanonicalRecord = true
      } else {
        context.delete(record)
      }
    }
    if !keptCanonicalRecord {
      context.insert(KitchenOwnershipRecord(
        id: identifier,
        kitchenID: identifier,
        ownerID: ownerID.rawValue
      ))
    }
  }

  private func convergeKitchenRecords(
    into kitchen: Kitchen,
    ownedBy ownerID: KitchenOwner.ID
  ) throws {
    let kitchenRecords = try context.fetch(FetchDescriptor<KitchenRecord>())
    let ownershipRecords = try context.fetch(FetchDescriptor<KitchenOwnershipRecord>())
    for ownership in ownershipRecords where ownership.ownerID != ownerID.rawValue {
      throw KitchenMemoryPersistenceError.kitchenOwnedByAnotherOwner(
        kitchenID: Kitchen.ID(rawValue: ownership.kitchenID)
      )
    }
    try rehomeRecipeRecords(to: kitchen.id.rawValue)
    try rehomeSessionRecords(to: kitchen.id.rawValue)
    try replaceKitchenRecords(with: kitchen, ownedBy: ownerID, existing: kitchenRecords)
  }

  private func rehomeRecipeRecords(to destinationID: UUID) throws {
    for record in try context.fetch(FetchDescriptor<RecipeRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<RecipeDeletionRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
  }

  private func rehomeSessionRecords(to destinationID: UUID) throws {
    for record in try context.fetch(FetchDescriptor<CookingSessionRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<SessionFactRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<SessionClosureRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<SessionDeletionRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<SessionDeletionResolutionRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
  }

  private func replaceKitchenRecords(
    with kitchen: Kitchen,
    ownedBy ownerID: KitchenOwner.ID,
    existing kitchenRecords: [KitchenRecord]
  ) throws {
    let destinationID = kitchen.id.rawValue
    var keptDestination = false
    for record in kitchenRecords {
      if record.id == destinationID, !keptDestination {
        if record.name != kitchen.name {
          record.name = kitchen.name
        }
        keptDestination = true
      } else {
        context.delete(record)
      }
    }
    if !keptDestination {
      context.insert(KitchenRecord(id: destinationID, name: kitchen.name))
    }
    for record in try context.fetch(FetchDescriptor<KitchenOwnershipRecord>())
    where record.kitchenID != destinationID {
      context.delete(record)
    }
    try replaceOwnership(of: kitchen.id, with: ownerID)
  }

  private func upsert(_ recipe: Recipe) throws {
    let identifier = recipe.id.rawValue
    let descriptor = FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == identifier })
    if let record = try context.fetch(descriptor).first {
      record.kitchenID = recipe.kitchenID.rawValue
      record.currentRevisionID = recipe.currentRevisionID.rawValue
    } else {
      context.insert(
        RecipeRecord(
          id: identifier, kitchenID: recipe.kitchenID.rawValue,
          currentRevisionID: recipe.currentRevisionID.rawValue))
    }
  }

  // swiftlint:disable:next function_body_length
  private func replace(_ revision: RecipeRevision) throws {
    let identifier = revision.id.rawValue
    try deleteRevisionRows(revisionID: identifier)
    let descriptor = FetchDescriptor<RecipeRevisionRecord>(
      predicate: #Predicate { $0.id == identifier })
    if let oldRecord = try context.fetch(descriptor).first { context.delete(oldRecord) }

    context.insert(
      RecipeRevisionRecord(
        id: identifier,
        recipeID: revision.recipeID.rawValue,
        revisionNumber: revision.revisionNumber,
        title: revision.title,
        summary: revision.summary,
        authorName: revision.authorName,
        contentLanguage: revision.contentLanguage?.rawValue,
        sourceData: try encodeSource(revision.source, capture: revision.sourceCapture),
        yieldData: try encodeOptional(revision.recipeYield),
        prepSeconds: revision.prepDuration?.seconds,
        cookSeconds: revision.cookDuration?.seconds,
        totalSeconds: revision.totalDuration?.seconds,
        cuisinesData: try encoder.encode(revision.cuisines),
        categoriesData: try encoder.encode(revision.categories),
        keywordsData: try encoder.encode(revision.keywords)
      ))

    for (index, media) in revision.media.enumerated() {
      context.insert(
        RecipeMediaRecord(
          id: media.id.rawValue, revisionID: identifier, sortIndex: index,
          role: media.role.rawValue, assetName: media.assetName,
          accessibilityLabel: media.accessibilityLabel))
    }
    for (index, item) in revision.equipment.enumerated() {
      context.insert(
        EquipmentRecord(
          id: item.id.rawValue, revisionID: identifier, sortIndex: index,
          originalText: item.originalText, quantityData: try encodeOptional(item.quantity),
          name: item.name, isOptional: item.isOptional))
    }
    for (sectionIndex, section) in revision.ingredientSections.enumerated() {
      context.insert(
        IngredientSectionRecord(
          id: section.id.rawValue, revisionID: identifier, sortIndex: sectionIndex,
          title: section.title))
      for (itemIndex, item) in section.ingredients.enumerated() {
        context.insert(
          RecipeIngredientRecord(
            id: item.id.rawValue, sectionID: section.id.rawValue, sortIndex: itemIndex,
            originalText: item.originalText, presentationMode: item.presentationMode.rawValue,
            customDisplayText: item.customDisplayText,
            quantityData: try encodeOptional(item.quantity), unitText: item.unitText,
            packageData: try encodeOptional(item.package), ingredientText: item.ingredientText,
            preparation: item.preparation, note: item.note, isOptional: item.isOptional,
            scalingBehavior: item.scalingBehavior.rawValue, parseState: item.parseState.rawValue
          ))
      }
    }
    for (sectionIndex, section) in revision.instructionSections.enumerated() {
      context.insert(
        InstructionSectionRecord(
          id: section.id.rawValue, revisionID: identifier, sortIndex: sectionIndex,
          title: section.title))
      for (stepIndex, step) in section.steps.enumerated() {
        context.insert(
          InstructionStepRecord(
            id: step.id.rawValue, sectionID: section.id.rawValue, sortIndex: stepIndex,
            name: step.name, text: step.text, durationSeconds: step.duration?.seconds,
            temperatureData: try encodeOptional(step.temperature)))
      }
    }
  }

  // swiftlint:disable:next function_body_length
  private func domainRevision(from record: RecipeRevisionRecord) throws -> RecipeRevision {
    let storedSource = try decodeSource(record.sourceData)
    let revisionID = record.id
    let media = try context.fetch(
      FetchDescriptor<RecipeMediaRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      )
    ).uniqued(on: \.id).map { item in
      guard let role = RecipeMedia.Role(rawValue: item.role) else {
        throw KitchenMemoryPersistenceError.invalidStoredValue(field: "media.role")
      }
      return RecipeMedia(
        id: .init(rawValue: item.id), role: role, assetName: item.assetName,
        accessibilityLabel: item.mediaAccessibilityLabel)
    }
    let equipment = try context.fetch(
      FetchDescriptor<EquipmentRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      )
    ).uniqued(on: \.id).map { item in
      EquipmentItem(
        id: .init(rawValue: item.id), originalText: item.originalText,
        quantity: try decodeOptional(
          QuantityExpression.self, from: item.quantityData, field: "equipment.quantity"),
        name: item.name, isOptional: item.isOptional)
    }

    let ingredientSectionRecords = try context.fetch(
      FetchDescriptor<IngredientSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      )
    ).uniqued(on: \.id)
    let ingredientSections = try ingredientSectionRecords.map { section in
      let sectionID = section.id
      let storedItems = try context.fetch(
        FetchDescriptor<RecipeIngredientRecord>(
          predicate: #Predicate { $0.sectionID == sectionID }, sortBy: [SortDescriptor(\.sortIndex)]
        )
      )
      let items = try storedItems.uniqued(on: \.id).map { item in
        guard let presentationMode = RecipeIngredient.PresentationMode(rawValue: item.presentationMode)
        else {
          throw KitchenMemoryPersistenceError.invalidStoredValue(
            field: "ingredient.presentationMode")
        }
        guard let scaling = RecipeIngredient.ScalingBehavior(rawValue: item.scalingBehavior) else {
          throw KitchenMemoryPersistenceError.invalidStoredValue(field: "ingredient.scalingBehavior")
        }
        guard let parseState = RecipeIngredient.ParseState(rawValue: item.parseState) else {
          throw KitchenMemoryPersistenceError.invalidStoredValue(field: "ingredient.parseState")
        }
        return RecipeIngredient(
          id: .init(rawValue: item.id), originalText: item.originalText,
          presentationMode: presentationMode,
          customDisplayText: item.customDisplayText,
          quantity: try decodeOptional(
            QuantityExpression.self, from: item.quantityData, field: "ingredient.quantity"),
          unitText: item.unitText,
          package: try decodeOptional(
            PackageDescription.self, from: item.packageData, field: "ingredient.package"),
          ingredientText: item.ingredientText, preparation: item.preparation, note: item.note,
          isOptional: item.isOptional, scalingBehavior: scaling, parseState: parseState
        )
      }
      return IngredientSection(
        id: .init(rawValue: section.id), title: section.title, ingredients: items)
    }

    let instructionSectionRecords = try context.fetch(
      FetchDescriptor<InstructionSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      )
    ).uniqued(on: \.id)
    let instructionSections = try instructionSectionRecords.map { section in
      let sectionID = section.id
      let storedSteps = try context.fetch(
        FetchDescriptor<InstructionStepRecord>(
          predicate: #Predicate { $0.sectionID == sectionID }, sortBy: [SortDescriptor(\.sortIndex)]
        )
      )
      let steps = try storedSteps.uniqued(on: \.id).map { step in
        InstructionStep(
          id: .init(rawValue: step.id), name: step.name, text: step.text,
          duration: step.durationSeconds.map(RecipeDuration.init(seconds:)),
          temperature: try decodeOptional(
            RecipeTemperature.self, from: step.temperatureData, field: "step.temperature"))
      }
      return InstructionSection(id: .init(rawValue: section.id), title: section.title, steps: steps)
    }

    let contentLanguage: RecipeContentLanguage?
    if let storedLanguage = record.contentLanguage {
      guard let language = RecipeContentLanguage(rawValue: storedLanguage) else {
        throw KitchenMemoryPersistenceError.invalidStoredValue(
          field: "revision.contentLanguage"
        )
      }
      contentLanguage = language
    } else {
      contentLanguage = nil
    }

    return RecipeRevision(
      id: .init(rawValue: record.id), recipeID: .init(rawValue: record.recipeID),
      revisionNumber: record.revisionNumber,
      title: record.title, summary: record.summary, authorName: record.authorName,
      contentLanguage: contentLanguage,
      source: storedSource.source,
      sourceCapture: storedSource.capture,
      recipeYield: try decodeOptional(
        RecipeYield.self, from: record.yieldData, field: "revision.yield"),
      prepDuration: record.prepSeconds.map(RecipeDuration.init(seconds:)),
      cookDuration: record.cookSeconds.map(RecipeDuration.init(seconds:)),
      totalDuration: record.totalSeconds.map(RecipeDuration.init(seconds:)),
      cuisines: try decode([String].self, from: record.cuisinesData, field: "revision.cuisines"),
      categories: try decode(
        [String].self, from: record.categoriesData, field: "revision.categories"),
      keywords: try decode([String].self, from: record.keywordsData, field: "revision.keywords"),
      media: media, equipment: equipment, ingredientSections: ingredientSections,
      instructionSections: instructionSections
    )
  }

  private func deleteRevisionRows(revisionID: UUID) throws {
    for record in try context.fetch(FetchDescriptor<RecipeMediaRecord>(
      predicate: #Predicate { $0.revisionID == revisionID }
    )) {
      context.delete(record)
    }
    for record in try context.fetch(FetchDescriptor<EquipmentRecord>(
      predicate: #Predicate { $0.revisionID == revisionID }
    )) {
      context.delete(record)
    }
    for section in try context.fetch(
      FetchDescriptor<IngredientSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID })) {
      let sectionID = section.id
      for item in try context.fetch(
        FetchDescriptor<RecipeIngredientRecord>(predicate: #Predicate { $0.sectionID == sectionID })
      ) { context.delete(item) }
      context.delete(section)
    }
    for section in try context.fetch(
      FetchDescriptor<InstructionSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID })) {
      let sectionID = section.id
      for step in try context.fetch(FetchDescriptor<InstructionStepRecord>(
        predicate: #Predicate { $0.sectionID == sectionID }
      )) {
        context.delete(step)
      }
      context.delete(section)
    }
  }

  private func encodeOptional<Value: Encodable>(_ value: Value?) throws -> Data? {
    try value.map(encoder.encode)
  }

  private func encodeSource(
    _ source: RecipeSource?,
    capture: RecipeSourceCapture?
  ) throws -> Data? {
    guard let capture else { return try encodeOptional(source) }
    return try encoder.encode(StoredSource(source: source, capture: capture))
  }

  private func decodeSource(_ data: Data?) throws -> (
    source: RecipeSource?, capture: RecipeSourceCapture?
  ) {
    guard let data else { return (nil, nil) }
    if let stored = try? decoder.decode(StoredSource.self, from: data) {
      return (stored.source, stored.capture)
    }
    return (
      try decode(RecipeSource.self, from: data, field: "revision.source"),
      nil
    )
  }

  private func decode<Value: Decodable>(_ type: Value.Type, from data: Data, field: String) throws
    -> Value {
    do { return try decoder.decode(type, from: data) } catch {
      throw KitchenMemoryPersistenceError.invalidStoredValue(field: field)
    }
  }

  private func decodeOptional<Value: Decodable>(_ type: Value.Type, from data: Data?, field: String)
    throws -> Value? {
    guard let data else { return nil }
    return try decode(type, from: data, field: field)
  }
}

// swiftlint:enable file_length type_body_length
