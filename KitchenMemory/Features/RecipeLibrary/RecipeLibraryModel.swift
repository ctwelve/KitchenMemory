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

  let organization: RecipeOrganizationModel?
  let library: RecipeLibrary
  let editingStore: any RecipeEditingStoring
  let drafts: RecipeDrafts
  let navigation: RecipeLibraryNavigation
  @ObservationIgnored var editingPresentations: [UUID: RecipeEditingModel] = [:]
  var editingStorageFailed: Bool {
    get { drafts.storageFailed }
    set { if !newValue { drafts.dismissStorageFailure() } }
  }
  var editingStorageIsAvailable: Bool { drafts.storageIsAvailable }
  private let samplePreferences: any SampleRecipeOnboardingStoring
  private var hasEstablishedKitchenEvidence: Bool
  private var resetPresentationState: () -> Void = {}

  private(set) var recipes: [StoredRecipe] = []
  private(set) var reconciliations: [RecipeReconciliation] = []
  var visibleReconciliations: [RecipeReconciliation] {
    reconciliations.filter { comparison in !deletedRecipes.contains { $0.id == comparison.recipeID } }
  }
  var reconciliationFailed = false
  var reconciliationFailureMessage: LocalizedStringResource = .recipeComparisonStorageFailure
  private(set) var recoveryRecipes: [RecipeRecovery] = []
  private(set) var deletedRecipes: [DeletedRecipe] = []
  private(set) var pendingDisposition: RecipeDispositionRequest?
  var selectedRecipeID: Recipe.ID? {
    get { navigation.selectedRecipeID }
    set { navigation.selectRecipe(newValue) }
  }
  var editor: RecipeEditingModel? {
    guard case .editor(let id) = navigation.destination,
          let draft = drafts.drafts.first(where: { $0.id == id }) else { return nil }
    return presentation(for: draft)
  }
  var editingDrafts: [RecipeEditingModel] { authoringItems.filter { !$0.isImportCandidate } }
  var importCandidates: [RecipeEditingModel] { authoringItems.filter(\.isImportCandidate) }
  var isShowingDrafts: Bool { navigation.destination == .drafts }
  private(set) var issue: RecipeLibraryIssue?
  private(set) var hasLoaded = false
  private(set) var startupState: StartupState = .loading
  private(set) var sampleOnboardingResponse: SampleRecipeOnboardingResponse
  private(set) var samplePackStatus: SamplePackStatus?
  private(set) var pendingSamplePack: SamplePackCommand?
  private(set) var samplePresence: SampleRecipePresence = .unavailable
  var synchronizationEvidenceIsStale = false
  private(set) var personalCloudStatus: PersonalCloudStatus = .notConfigured

  init(
    library: RecipeLibrary,
    samplePreferences: any SampleRecipeOnboardingStoring,
    kitchenWasCreated: Bool,
    editingStore: any RecipeEditingStoring = VolatileRecipeEditingStore(),
    navigation: RecipeLibraryNavigation = RecipeLibraryNavigation(),
    organization: RecipeOrganizationModel? = nil
  ) {
    self.organization = organization
    self.library = library
    self.editingStore = editingStore
    drafts = RecipeDrafts(library: library, store: editingStore)
    self.navigation = navigation
    self.samplePreferences = samplePreferences
    hasEstablishedKitchenEvidence = !kitchenWasCreated
    sampleOnboardingResponse = samplePreferences.sampleRecipeOnboardingResponse
    navigation.prepareToLeaveEditor = { [weak self] in
      guard let self, editor != nil else { return true }
      return editor?.confirmsDiscard != true && drafts.prepareToLeave()
    }
    samplePreferences.startObservingSampleRecipeOnboardingResponse { [weak self] response in
      self?.receiveSampleOnboardingResponse(response)
    }
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
    let sampleInstallFailed: Bool
    if samplePackStatus != nil || pendingSamplePack != nil {
      sampleInstallFailed = !setSamplePackEnabled(true)
    } else {
      sampleInstallFailed = !installSamples()
    }
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
    if pendingSamplePack != nil {
      _ = performPendingSamplePack()
    } else if pendingDisposition != nil {
      performPendingDisposition()
    } else if issue == .samples {
      acceptSampleRecipes()
    } else {
      reload()
    }
  }

  @discardableResult
  private func reload(selecting preferredRecipeID: Recipe.ID?) -> Bool {
    organization?.refresh()
    do {
      let contents = try library.load()
      recipes = contents.recipes
      reconciliations = contents.reconciliations
      deletedRecipes = contents.deletedRecipes
      recoveryRecipes = contents.recoveryRecipes
      samplePresence = contents.samplePresence
      samplePackStatus = try? library.samplePackStatus()
      if let preferredRecipeID,
         recipes.contains(where: { $0.recipe.id == preferredRecipeID }) {
        navigation.reconcileRecipeSelection(preferredRecipeID)
      } else if !recipes.contains(where: { $0.recipe.id == selectedRecipeID }) {
        navigation.reconcileRecipeSelection(recipes.first?.recipe.id)
      }
      issue = pendingSamplePack != nil ? .samples : (pendingDisposition == nil ? nil : .disposition)
      hasLoaded = true
      if !recipes.isEmpty { hasEstablishedKitchenEvidence = true }
      return true
    } catch {
      recipes = []
      reconciliations = []
      deletedRecipes = []
      recoveryRecipes = []
      navigation.reconcileRecipeSelection(nil)
      samplePresence = .unavailable
      issue = .read
      hasLoaded = true
      return false
    }
  }

  func deleteRecipe(_ command: RecipeDeleteCommand) {
    pendingDisposition = .delete(command)
    performPendingDisposition()
  }

  func restoreRecipe(_ command: RecipeRestoreCommand) {
    pendingDisposition = .restore(command)
    performPendingDisposition()
  }

  private func performPendingDisposition() {
    guard let pendingDisposition else { return }
    do {
      switch pendingDisposition {
      case let .delete(command): try library.delete(command)
      case let .restore(command): try library.restore(command)
      }
      self.pendingDisposition = nil
      reload()
      navigation.move(to: .deletedItems)
    } catch {
      issue = .disposition
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

  func importRecipe(from url: URL) async throws -> [RecipeImportOption] {
    let options = try await library.importRecipe(from: url)
    try Task.checkCancellation()
    try stageImports(options)
    return options
  }

  @discardableResult
  func resetKitchen() -> Bool {
    do {
      // Only this explicitly confirmed destructive action may replace a document
      // that could not be decoded. Ordinary autosave never does so.
      // Purge local authoring first: a failed file write must leave shared data
      // untouched, and a later shared-reset failure must not resurrect old drafts.
      guard drafts.purge() else { issue = .reset; return false }
      editingPresentations = [:]
      if case .editor = navigation.destination { navigation.move(to: .recipe) }
      if isShowingDrafts { navigation.move(to: .recipe) }
      organization?.clearForReset()
      try library.reset()
      pendingDisposition = nil
      pendingSamplePack = nil
      navigation.move(to: .recipe)
      resetPresentationState()
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

enum RecipeDispositionRequest {
  case delete(RecipeDeleteCommand)
  case restore(RecipeRestoreCommand)
}

extension RecipeLibraryModel {
  @discardableResult
  func setSamplePackEnabled(_ enabled: Bool) -> Bool {
    do {
      if pendingSamplePack == nil { pendingSamplePack = try library.prepareSamplePack(enabled: enabled) }
      return performPendingSamplePack()
    } catch {
      issue = .samples
      return false
    }
  }

  func prepareSamplePackRemoval() -> SamplePackCommand? {
    do { return try library.prepareSamplePack(enabled: false) } catch { issue = .samples; return nil }
  }

  func confirmSamplePackRemoval(_ command: SamplePackCommand) {
    guard pendingSamplePack == nil else { return }
    pendingSamplePack = command
    _ = performPendingSamplePack()
  }

  private func performPendingSamplePack() -> Bool {
    guard let pendingSamplePack else { return false }
    do {
      try library.setSamplePack(pendingSamplePack)
      self.pendingSamplePack = nil
      reload()
      return true
    } catch {
      issue = .samples
      return false
    }
  }

}
