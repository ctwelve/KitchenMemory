// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

// Coherent recipe-library operations live in Logic rather than any one UI.

import Foundation

/// The durable content and bundled-sample state of one Kitchen's library.
public struct RecipeLibraryContents: Equatable, Sendable {
  /// Recipes eligible for ordinary library presentation with their selected revisions.
  public let recipes: [StoredRecipe]
  /// Competing Recipe content retained for explicit comparison and reconciliation.
  public let reconciliations: [RecipeReconciliation]
  /// Unavailable or invalid Recipe authority with retained recoverable payload choices.
  public let recoveryRecipes: [RecipeRecovery]
  /// Deliberately hidden Recipes and retained deletion evidence for explicit restoration.
  public let deletedRecipes: [DeletedRecipe]
  /// Presence of current bundled sample identities, independent of onboarding authorization.
  public let samplePresence: SampleRecipePresence

  /// Creates one library read result from already classified values.
  public init(recipes: [StoredRecipe], samplePresence: SampleRecipePresence,
              reconciliations: [RecipeReconciliation] = [], deletedRecipes: [DeletedRecipe] = [],
              recoveryRecipes: [RecipeRecovery] = []) {
    self.recoveryRecipes = recoveryRecipes
    self.reconciliations = reconciliations
    self.deletedRecipes = deletedRecipes
    self.recipes = recipes
    self.samplePresence = samplePresence
  }
}

/// Product intentions for one Kitchen's recipe library.
///
/// Callers do not need to coordinate repository reads, recipe revisioning,
/// imports, bundled-sample presence, or reset behavior. The observable app
/// model remains responsible only for presentation state such as selection and
/// localized failure categories.
@MainActor
public struct RecipeLibrary {
  private let kitchenID: Kitchen.ID
  private let repository: any RecipeRepository
  private let organization: (any RecipeOrganizationRepository)?
  private let editor: RecipeEditor
  private let importer: any RecipeImportServing
  private let samplePack: (any SamplePackRepository)?
  private let samples: any SampleRecipeProviding
  private let sampleFolderName: String
  private let sampleTagName: String
  private let sampleInstaller: SampleRecipeInstallService
  private let resetter: KitchenResetService

  /// Binds product intentions to one Kitchen and its main-actor repositories.
  /// Optional organization and sample-pack adapters enable their atomic operations.
  /// Without a reset adapter, the fallback reset owns Recipe records only.
  public init(
    kitchenID: Kitchen.ID,
    repository: any RecipeRepository,
    samples: any SampleRecipeProviding,
    importer: any RecipeImportServing,
    resetRepository: (any KitchenResetRepository)? = nil,
    organizationRepository: (any RecipeOrganizationRepository)? = nil,
    samplePackRepository: (any SamplePackRepository)? = nil,
    sampleFolderName: String, sampleTagName: String
  ) {
    self.samplePack = samplePackRepository
    self.samples = samples
    self.sampleFolderName = sampleFolderName
    self.sampleTagName = sampleTagName
    self.kitchenID = kitchenID
    self.repository = repository
    organization = organizationRepository
    editor = RecipeEditor(repository: repository)
    self.importer = importer
    sampleInstaller = SampleRecipeInstallService(repository: repository, samples: samples)
    resetter = KitchenResetService(
      repository: resetRepository ?? RecipeOnlyKitchenResetRepository(repository: repository),
      samples: samples
    )
  }

  /// Loads recipe content and derives current sample presence in one pass.
  ///
  /// Sample assets can be unavailable independently of durable recipe content,
  /// so that condition is represented in the returned contents rather than
  /// making the whole library unreadable.
  public func load() throws -> RecipeLibraryContents {
    let recipes = try repository.recipes(in: kitchenID)
    let samplePresence: SampleRecipePresence
    do {
      samplePresence = try sampleInstaller.presence(in: kitchenID, installedRecipeIDs: Set(recipes.map(\.id)))
    } catch {
      samplePresence = .unavailable
    }
    return RecipeLibraryContents(
      recipes: recipes, samplePresence: samplePresence,
      reconciliations: try repository.reconciliations(in: kitchenID),
      deletedRecipes: try repository.deletedRecipes(in: kitchenID),
      recoveryRecipes: try repository.recoveryRecipes(in: kitchenID)
    )
  }

  /// Prepares and locally accepts a new Recipe and its initial selected Revision.
  /// Throws validation or repository failures. Each call prepares fresh identities;
  /// retain ``prepareSave(from:original:observedSelectionIDs:)`` for durable exact retry.
  public func create(from draft: RecipeDraft) throws -> StoredRecipe {
    try editor.create(in: kitchenID, from: draft)
  }

  /// Prepares and accepts a new revision using the currently readable Recipe and Selection heads.
  /// Throws when the Recipe is absent, input is invalid, or storage fails; repeated calls
  /// prepare new identities rather than retrying a frozen Save.
  public func revise(recipeID: Recipe.ID, from draft: RecipeDraft) throws -> StoredRecipe {
    try editor.revise(recipeID: recipeID, from: draft)
  }

  /// Retrieves candidates for explicit review without adding them to the library.
  public func importRecipe(from url: URL) async throws -> [RecipeImportOption] {
    try await importer.importRecipe(from: url)
  }

  /// Interprets supplied HTML or JSON-LD bytes into reviewable candidates without fetching or saving.
  public func importDocument(
    _ data: Data, sourceURL: URL, format: RecipeImportService.DocumentFormat
  ) throws -> [RecipeImportOption] {
    try RecipeImportService.documentOptions(from: data, sourceURL: sourceURL, format: format)
  }

  /// Reads the observed Selection frontier to retain with an editing draft.
  /// The frontier describes local evidence and does not prove global synchronization.
  public func editingSelectionHeads(for recipeID: Recipe.ID) throws -> [RecipeSelectionCommand.ID] {
    try repository.selectionHeads(for: recipeID)
  }

  /// Validates and freezes a Recipe Save with the draft's retained base and observed Selection frontier.
  /// This allocates new identities but writes no Recipe; retain the result before submitting it.
  public func prepareSave(
    from draft: RecipeDraft, original: StoredRecipe?,
    observedSelectionIDs: [RecipeSelectionCommand.ID]
  ) throws -> RecipeSaveCommand {
    try editor.prepareSave(in: kitchenID, from: draft, original: original,
                           observedSelectionIDs: observedSelectionIDs)
  }

  /// Accepts an exact frozen Save for this Kitchen through the repository.
  /// Wrong-Kitchen commands throw; success proves local acceptance, and retry must use
  /// the same command rather than prepare another revision.
  public func save(_ command: RecipeSaveCommand) throws {
    guard command.recipe.kitchenID == kitchenID else {
      throw KitchenMemoryPersistenceError.inconsistentRecipeIdentity
    }
    try repository.save(command)
  }

  /// Freezes first-Save assignments from current organization evidence.
  /// Returns nil for no choices when organization is unavailable; nonempty unsupported
  /// choices throw rather than silently lose assignments.
  public func prepareOrganization(_ pending: PendingRecipeOrganization, for command: RecipeSaveCommand) throws
    -> RecipeOrganizationCommand? {
    guard let organization else {
      guard pending == PendingRecipeOrganization() else { throw FolderError.invalidEvidence }
      return nil
    }
    return try organization.load(in: kitchenID).prepare(pending, for: command.recipe.id,
                                                       id: command.id.rawValue, at: command.savedAt)
  }

  /// Accepts a frozen first Save and organization batch in the adapter's shared local transaction.
  /// A nil batch uses ordinary Save; absent or mismatched organization scope throws.
  public func save(_ command: RecipeSaveCommand, organization batch: RecipeOrganizationCommand?) throws {
    guard let batch else { try save(command); return }
    guard let organization, batch.kitchenID == kitchenID else { throw FolderError.wrongKitchen }
    try organization.accept(batch, firstSave: command)
  }

  /// Freezes a multi-parent reconciliation Save using every compared revision and observed Selection.
  /// Rejects a comparison outside this Kitchen or invalid choices; writes no shared authority.
  public func prepareReconciliationSave(
    _ comparison: RecipeReconciliation, session: RecipeEditSession
  ) throws -> RecipeSaveCommand {
    guard comparison.kitchenID == kitchenID else { throw RecipeReconciliationError.invalidParents }
    return try editor.prepareReconciliationSave(comparison, session: session)
  }

  /// Copies one eligible retained recovery revision for a new Recipe draft.
  /// Throws when that payload is unavailable; copying never repairs the original authority.
  public func prepareRecoveryDraft(recipeID: Recipe.ID, revisionID: RecipeRevision.ID) throws -> RecipeDraft {
    guard let recovery = try repository.recoveryRecipes(in: kitchenID).first(where: { $0.id == recipeID }),
          let revision = recovery.revisions.first(where: { $0.id == revisionID }) else {
      throw RecipeDispositionError.unavailable
    }
    return editor.copyForRecovery(revision)
  }

  /// Creates a stable explicit deletion command for this Kitchen without writing evidence.
  public func prepareDeletion(of recipeID: Recipe.ID) -> RecipeDeleteCommand {
    RecipeDeleteCommand(kitchenID: kitchenID, recipeID: recipeID)
  }

  /// Freezes restoration of every observed unresolved deletion for a recoverable item.
  /// Throws when complete Recipe content or the observed deletion frontier is unavailable.
  public func prepareRestoration(of item: DeletedRecipe) throws -> RecipeRestoreCommand {
    guard item.recoverableRecipe != nil, !item.observedDeletionIDs.isEmpty else {
      throw RecipeDispositionError.unavailable
    }
    return RecipeRestoreCommand(
      kitchenID: kitchenID, recipeID: item.id, observedDeletionIDs: item.observedDeletionIDs
    )
  }

  /// Accepts deletion evidence for this Kitchen, retaining Recipe history for restoration and pruning.
  public func delete(_ command: RecipeDeleteCommand) throws {
    guard command.kitchenID == kitchenID else { throw RecipeDispositionError.invalidCommand }
    try repository.delete(command)
  }

  /// Accepts observed restoration evidence for this Kitchen; unseen deletion evidence remains effective.
  public func restore(_ command: RecipeRestoreCommand) throws {
    guard command.kitchenID == kitchenID else { throw RecipeDispositionError.invalidCommand }
    try repository.restore(command)
  }

  /// Reads sample-pack intent and content status, or nil when the adapter is absent.
  /// Bundled decoding and repository failures propagate.
  public func samplePackStatus() throws -> SamplePackStatus? {
    try samplePack?.status(in: kitchenID, samples: samples.recipes(in: kitchenID))
  }

  /// Freezes an explicit sample-pack transition, including only currently eligible removal identities.
  /// Throws without an adapter or available sample content; acceptance rechecks removal safety.
  public func prepareSamplePack(enabled: Bool) throws -> SamplePackCommand {
    guard let samplePack else { throw RecipeDispositionError.unavailable }
    let values = try samples.recipes(in: kitchenID)
    let status = try samplePack.status(in: kitchenID, samples: values)
    return SamplePackCommand(kitchenID: kitchenID, enabled: enabled, samples: values,
      removalIDs: enabled ? [] : status.removableIDs, folderName: sampleFolderName, tagName: sampleTagName)
  }

  /// Accepts the exact sample-pack command for this Kitchen through its atomic adapter.
  public func setSamplePack(_ command: SamplePackCommand) throws {
    guard let samplePack, command.kitchenID == kitchenID else { throw RecipeDispositionError.invalidCommand }
    try samplePack.accept(command)
  }

  /// Accepts sample-pack enablement when supported, otherwise uses compatibility sample installation.
  /// Compatibility installation preserves visible Recipes and can resolve retained deletions.
  public func installSamples() throws {
    if samplePack != nil {
      try setSamplePack(prepareSamplePack(enabled: true))
    } else {
      try sampleInstaller.install(in: kitchenID)
    }
  }

  /// Resets durable Kitchen contents using retained sample-pack intent.
  /// Callers own prior cleanup of local drafts and delivery state; errors propagate.
  public func reset() throws {
    // Read accepted intent without requiring bundled content to be available.
    let installSamples = try samplePack?.status(in: kitchenID, samples: []).isEnabled ?? true
    try resetter.reset(kitchenID: kitchenID, installSamples: installSamples)
  }
}
