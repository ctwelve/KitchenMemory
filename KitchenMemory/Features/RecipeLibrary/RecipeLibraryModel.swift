// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import Foundation
import Observation

/// Presentation state for one prepared Kitchen's recipe library.
///
/// The model owns selection, startup sample choice, cloud-status display, and
/// coarse user-facing failure categories. It delegates recipe operations to
/// KitchenKit's `RecipeLibrary` and never exposes SwiftData records to views.
@MainActor
@Observable
final class RecipeLibraryModel {
  enum StartupState: Equatable {
    case loading
    case choosingSamples
    case ready
  }

  let library: RecipeLibrary
  let editingStore: any RecipeEditingStoring
  var editingStorageFailed = false
  var editingStorageIsAvailable = true
  private let samplePreferences: any SampleRecipeOnboardingStoring
  private var hasEstablishedKitchenEvidence: Bool
  private var resetPresentationState: () -> Void = {}

  private(set) var recipes: [StoredRecipe] = []
  var selectedRecipeID: Recipe.ID?
  var editor: RecipeEditingModel?
  var authoringItems: [RecipeEditingModel] = []
  var editingDrafts: [RecipeEditingModel] { authoringItems.filter { !$0.isImportCandidate } }
  var importCandidates: [RecipeEditingModel] { authoringItems.filter(\.isImportCandidate) }
  var isShowingDrafts = false
  private(set) var issue: RecipeLibraryIssue?
  private(set) var hasLoaded = false
  private(set) var startupState: StartupState = .loading
  private(set) var sampleOnboardingResponse: SampleRecipeOnboardingResponse
  private(set) var samplePresence: SampleRecipePresence = .unavailable
  private(set) var personalCloudStatus: PersonalCloudStatus = .notConfigured

  init(
    library: RecipeLibrary,
    samplePreferences: any SampleRecipeOnboardingStoring,
    kitchenWasCreated: Bool,
    editingStore: any RecipeEditingStoring = VolatileRecipeEditingStore()
  ) {
    self.library = library
    self.editingStore = editingStore
    self.samplePreferences = samplePreferences
    hasEstablishedKitchenEvidence = !kitchenWasCreated
    sampleOnboardingResponse = samplePreferences.sampleRecipeOnboardingResponse
    samplePreferences.startObservingSampleRecipeOnboardingResponse { [weak self] response in
      self?.receiveSampleOnboardingResponse(response)
    }
    restoreEditingDrafts()
  }

  var selectedRecipe: StoredRecipe? {
    recipes.first { $0.recipe.id == selectedRecipeID }
  }

  func installResetPresentationHandler(_ handler: @escaping () -> Void) {
    resetPresentationState = handler
  }

  func loadIfNeeded() {
    guard !hasLoaded else { return }
    reload()
    reconcileStartupState()
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
    reconcileStartupState()
  }

  func updatePersonalCloudStatus(_ status: PersonalCloudStatus) {
    personalCloudStatus = status
  }

  func acceptSampleRecipes() {
    samplePreferences.sampleRecipeOnboardingResponse = .accepted
    sampleOnboardingResponse = .accepted
    startupState = .loading
    let sampleInstallFailed = !installSamples()
    reload()
    if sampleInstallFailed { issue = .samples }
    startupState = .ready
  }

  func declineSampleRecipes() {
    samplePreferences.sampleRecipeOnboardingResponse = .declined
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
      let contents = try library.load()
      recipes = contents.recipes
      samplePresence = contents.samplePresence
      if let preferredRecipeID,
         recipes.contains(where: { $0.recipe.id == preferredRecipeID }) {
        selectedRecipeID = preferredRecipeID
      } else if !recipes.contains(where: { $0.recipe.id == selectedRecipeID }) {
        selectedRecipeID = recipes.first?.recipe.id
      }
      issue = nil
      hasLoaded = true
      if !recipes.isEmpty { hasEstablishedKitchenEvidence = true }
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

  private func receiveSampleOnboardingResponse(_ response: SampleRecipeOnboardingResponse) {
    sampleOnboardingResponse = response
    if hasLoaded { reconcileStartupState() }
  }

  private func reconcileStartupState() {
    sampleOnboardingResponse = samplePreferences.sampleRecipeOnboardingResponse
    startupState = sampleOnboardingResponse == .undecided
      && !hasEstablishedKitchenEvidence
      ? .choosingSamples
      : .ready
  }

  func createRecipe(from draft: RecipeDraft) -> Bool {
    do {
      let stored = try library.create(from: draft)
      reload(selecting: stored.recipe.id)
      return true
    } catch {
      issue = .save
      return false
    }
  }

  func reviseRecipe(id: Recipe.ID, from draft: RecipeDraft) -> Bool {
    do {
      let stored = try library.revise(recipeID: id, from: draft)
      reload(selecting: stored.recipe.id)
      return true
    } catch {
      issue = .save
      return false
    }
  }

  func importRecipe(from url: URL) async throws -> [RecipeImportOption] {
    let options = try await library.importRecipe(from: url)
    try Task.checkCancellation()
    try stageImports(options)
    return options
  }

  @discardableResult
  func resetKitchen() -> Bool {
    do {
      try library.reset()
      // Only this explicitly confirmed destructive action may replace a document
      // that could not be decoded. Ordinary autosave never does so.
      try editingStore.save([])
      authoringItems = []
      editingStorageIsAvailable = true
      editingStorageFailed = false
      editor = nil
      isShowingDrafts = false
      resetPresentationState()
      samplePreferences.sampleRecipeOnboardingResponse = .accepted
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
      try library.installSamples()
      return true
    } catch {
      return false
    }
  }
}
