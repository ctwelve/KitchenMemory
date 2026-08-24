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
  private let sampleOnboardingStore: any SampleRecipeOnboardingStoring

  private(set) var recipes: [StoredRecipe] = []
  var selectedRecipeID: Recipe.ID?
  private(set) var issue: RecipeLibraryIssue?
  private(set) var hasLoaded = false
  private(set) var startupState: StartupState = .loading
  private(set) var sampleOnboardingResponse: SampleRecipeOnboardingResponse
  private(set) var samplePresence: SampleRecipePresence = .unavailable
  private(set) var personalCloudStatus: PersonalCloudStatus = .notConfigured

  init(
    kitchenID: Kitchen.ID,
    library: RecipeLibrary,
    editor: RecipeEditor,
    importer: any RecipeImportServing,
    resetService: KitchenResetService,
    sampleInstaller: SampleRecipeInstallService,
    sampleOnboardingStore: any SampleRecipeOnboardingStoring
  ) {
    self.kitchenID = kitchenID
    self.library = library
    self.editor = editor
    self.importer = importer
    self.resetService = resetService
    self.sampleInstaller = sampleInstaller
    self.sampleOnboardingStore = sampleOnboardingStore
    sampleOnboardingResponse = sampleOnboardingStore.response
  }

  // Swift 6.2 runtimes through OS 26.2 can double-free task-local state when
  // an actor-isolated class uses a synthesized deinitializer. Keep this
  // explicit empty deinitializer until affected deployment versions retire.
  deinit {}

  var selectedRecipe: StoredRecipe? {
    recipes.first { $0.recipe.id == selectedRecipeID }
  }

  func loadIfNeeded() {
    guard !hasLoaded else { return }
    reload()
    startupState = sampleOnboardingResponse == .undecided ? .choosingSamples : .ready
  }

  func reload() {
    _ = reload(selecting: selectedRecipeID)
  }

  /// Refreshes visible state after persistence imports changes from elsewhere.
  ///
  /// A remote notification may arrive while the launch screen is still up. In
  /// that case `loadIfNeeded()` must remain responsible for advancing the
  /// sample-choice state machine, so an early import is deliberately ignored.
  func reloadAfterExternalStoreChange() {
    guard hasLoaded else { return }
    reload()
  }

  func updatePersonalCloudStatus(_ status: PersonalCloudStatus) {
    personalCloudStatus = status
  }

  func acceptSampleRecipes() {
    sampleOnboardingStore.response = .accepted
    sampleOnboardingResponse = .accepted
    startupState = .loading
    let sampleInstallFailed = !installSamples()
    reload()
    if sampleInstallFailed { issue = .samples }
    startupState = .ready
  }

  func declineSampleRecipes() {
    sampleOnboardingStore.response = .declined
    sampleOnboardingResponse = .declined
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
      do {
        samplePresence = try sampleInstaller.presence(in: kitchenID)
      } catch {
        samplePresence = .unavailable
      }
      issue = nil
      hasLoaded = true
      return true
    } catch {
      recipes = []
      selectedRecipeID = nil
      samplePresence = .unavailable
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
      sampleOnboardingStore.response = .accepted
      sampleOnboardingResponse = .accepted
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
