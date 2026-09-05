// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

// Coherent recipe-library operations live in Logic rather than any one UI.

import Foundation

/// The durable content and bundled-sample state of one Kitchen's library.
public struct RecipeLibraryContents: Equatable, Sendable {
  public let recipes: [StoredRecipe]
  public let samplePresence: SampleRecipePresence

  public init(recipes: [StoredRecipe], samplePresence: SampleRecipePresence) {
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
  private let editor: RecipeEditor
  private let importer: any RecipeImportServing
  private let sampleInstaller: SampleRecipeInstallService
  private let resetter: KitchenResetService

  public init(
    kitchenID: Kitchen.ID,
    repository: any RecipeRepository,
    samples: any SampleRecipeProviding,
    importer: any RecipeImportServing,
    resetRepository: (any KitchenResetRepository)? = nil
  ) {
    self.kitchenID = kitchenID
    self.repository = repository
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
    return RecipeLibraryContents(recipes: recipes, samplePresence: samplePresence)
  }

  public func create(from draft: RecipeDraft) throws -> StoredRecipe {
    try editor.create(in: kitchenID, from: draft)
  }

  public func revise(recipeID: Recipe.ID, from draft: RecipeDraft) throws -> StoredRecipe {
    try editor.revise(recipeID: recipeID, from: draft)
  }

  public func importRecipe(from url: URL) async throws -> [RecipeImportOption] {
    try await importer.importRecipe(from: url)
  }

  public func importDocument(
    _ data: Data, sourceURL: URL, format: RecipeImportService.DocumentFormat
  ) throws -> [RecipeImportOption] {
    try RecipeImportService.documentOptions(from: data, sourceURL: sourceURL, format: format)
  }

  public func editingSelectionHeads(for recipeID: Recipe.ID) throws -> [RecipeSelectionCommand.ID] {
    try repository.selectionHeads(for: recipeID)
  }

  public func prepareSave(
    from draft: RecipeDraft, original: StoredRecipe?,
    observedSelectionIDs: [RecipeSelectionCommand.ID]
  ) throws -> RecipeSaveCommand {
    try editor.prepareSave(in: kitchenID, from: draft, original: original,
                           observedSelectionIDs: observedSelectionIDs)
  }

  public func save(_ command: RecipeSaveCommand) throws {
    guard command.recipe.kitchenID == kitchenID else {
      throw KitchenMemoryPersistenceError.inconsistentRecipeIdentity
    }
    try repository.save(command)
  }

  public func installSamples() throws {
    try sampleInstaller.install(in: kitchenID)
  }

  public func reset() throws {
    try resetter.reset(kitchenID: kitchenID)
  }
}
