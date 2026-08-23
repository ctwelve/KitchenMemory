// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryLogic
import KitchenMemoryPersistence
import Foundation
import Observation

@MainActor
@Observable
final class RecipeLibraryModel {
  enum StartupState: Equatable {
    case loading
    case choosingSamples
    case ready
  }

  private let kitchenID: Kitchen.ID
  private let library: RecipeLibrary
  private let editor: RecipeEditor
  private let importer: any RecipeImportServing
  private let resetService: KitchenResetService
  private let sampleInstaller: SampleRecipeInstallService
  private let sampleConsentStore: any SampleRecipeConsentStoring

  private(set) var recipes: [StoredRecipe] = []
  var selectedRecipeID: Recipe.ID?
  private(set) var issue: RecipeLibraryIssue?
  private(set) var hasLoaded = false
  private(set) var startupState: StartupState = .loading
  private(set) var sampleConsent: SampleRecipeConsent

  init(
    kitchenID: Kitchen.ID,
    library: RecipeLibrary,
    editor: RecipeEditor,
    importer: any RecipeImportServing,
    resetService: KitchenResetService,
    sampleInstaller: SampleRecipeInstallService,
    sampleConsentStore: any SampleRecipeConsentStoring
  ) {
    self.kitchenID = kitchenID
    self.library = library
    self.editor = editor
    self.importer = importer
    self.resetService = resetService
    self.sampleInstaller = sampleInstaller
    self.sampleConsentStore = sampleConsentStore
    sampleConsent = sampleConsentStore.consent
  }

  var selectedRecipe: StoredRecipe? {
    recipes.first { $0.recipe.id == selectedRecipeID }
  }

  func loadIfNeeded() {
    guard !hasLoaded else { return }
    let sampleInstallFailed = sampleConsent == .accepted && !installSamples()
    reload()
    if sampleInstallFailed { issue = .samples }
    startupState = sampleConsent == .undecided ? .choosingSamples : .ready
  }

  func reload() {
    _ = reload(selecting: selectedRecipeID)
  }

  func acceptSampleRecipes() {
    sampleConsentStore.consent = .accepted
    sampleConsent = .accepted
    startupState = .loading
    let sampleInstallFailed = !installSamples()
    reload()
    if sampleInstallFailed { issue = .samples }
    startupState = .ready
  }

  func declineSampleRecipes() {
    sampleConsentStore.consent = .declined
    sampleConsent = .declined
    startupState = .ready
  }

  func retryCurrentIssue() {
    if issue == .samples {
      acceptSampleRecipes()
    } else {
      reload()
    }
  }

  @discardableResult
  private func reload(selecting preferredRecipeID: Recipe.ID?) -> Bool {
    do {
      recipes = try library.recipes(in: kitchenID)
      if let preferredRecipeID,
         recipes.contains(where: { $0.recipe.id == preferredRecipeID }) {
        selectedRecipeID = preferredRecipeID
      } else if !recipes.contains(where: { $0.recipe.id == selectedRecipeID }) {
        selectedRecipeID = recipes.first?.recipe.id
      }
      issue = nil
      hasLoaded = true
      return true
    } catch {
      recipes = []
      selectedRecipeID = nil
      issue = .read
      hasLoaded = true
      return false
    }
  }

  func createRecipe(from draft: RecipeDraft) -> Bool {
    do {
      let stored = try editor.create(in: kitchenID, from: draft)
      reload(selecting: stored.recipe.id)
      return true
    } catch {
      issue = .save
      return false
    }
  }

  func reviseRecipe(id: Recipe.ID, from draft: RecipeDraft) -> Bool {
    do {
      let stored = try editor.revise(recipeID: id, from: draft)
      reload(selecting: stored.recipe.id)
      return true
    } catch {
      issue = .save
      return false
    }
  }

  func importRecipe(from url: URL) async throws -> [RecipeImportOption] {
    try await importer.importRecipe(from: url)
  }

  @discardableResult
  func resetKitchen() -> Bool {
    do {
      try resetService.reset(kitchenID: kitchenID)
      sampleConsentStore.consent = .accepted
      sampleConsent = .accepted
      reload()
      return true
    } catch {
      issue = .reset
      return false
    }
  }

  private func installSamples() -> Bool {
    do {
      try sampleInstaller.install(in: kitchenID)
      return true
    } catch {
      return false
    }
  }
}
