// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemory
import KitchenMemoryDomain
import KitchenMemoryLogic
import KitchenMemoryPersistence
import XCTest

@MainActor
final class RecipeLibraryStartupTests: XCTestCase {
  private enum SampleFailure: Error {
    case unavailable
  }

  private final class RecoveringSampleProvider: SampleRecipeProviding {
    var shouldFail = true

    func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
      if shouldFail { throw SampleFailure.unavailable }
      return try BundledSampleRecipeProvider().recipes(in: kitchenID)
    }
  }

  func testUndecidedResponseShowsChoiceBeforeAnEmptyLibrary() throws {
    let preferences = VolatileKitchenPreferencesStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      preferencesStore: preferences
    )

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.startupState, .choosingSamples)
    XCTAssertEqual(dependencies.libraryModel.sampleOnboardingResponse, .undecided)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .undecided)
  }

  func testExternalChangeBeforeInitialLoadLeavesStartupOwnedByLoad() throws {
    let preferences = VolatileKitchenPreferencesStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      preferencesStore: preferences
    )

    dependencies.libraryModel.reloadAfterExternalStoreChange()

    XCTAssertFalse(dependencies.libraryModel.hasLoaded)
    XCTAssertEqual(dependencies.libraryModel.startupState, .loading)

    dependencies.libraryModel.loadIfNeeded()
    XCTAssertEqual(dependencies.libraryModel.startupState, .choosingSamples)
  }

  func testExistingKitchenSkipsAQuestionThatWasNeverAnsweredOnThisDevice() throws {
    let preferences = VolatileKitchenPreferencesStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      preferencesStore: preferences,
      initialKitchenWasCreatedOverride: false
    )

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.sampleOnboardingResponse, .undecided)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)
  }

  func testRemoteContentDismissesAnInapplicableQuestionWithoutInventingAnAnswer() throws {
    let preferences = VolatileKitchenPreferencesStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      preferencesStore: preferences,
      initialKitchenWasCreatedOverride: true
    )
    dependencies.libraryModel.loadIfNeeded()
    XCTAssertEqual(dependencies.libraryModel.startupState, .choosingSamples)

    XCTAssertTrue(
      dependencies.libraryModel.createRecipe(from: RecipeDraft(title: "Synced Recipe"))
    )
    dependencies.libraryModel.reloadAfterExternalStoreChange()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.sampleOnboardingResponse, .undecided)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .undecided)
  }

  func testDecliningPersistsTheChoiceAndRevealsTheEmptyLibrary() throws {
    let preferences = VolatileKitchenPreferencesStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      preferencesStore: preferences
    )
    dependencies.libraryModel.loadIfNeeded()

    dependencies.libraryModel.declineSampleRecipes()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.sampleOnboardingResponse, .declined)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .declined)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)
  }

  func testAcceptingAddsSamplesBesideUserContentOnlyOnce() throws {
    let preferences = VolatileKitchenPreferencesStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      preferencesStore: preferences
    )
    dependencies.libraryModel.loadIfNeeded()
    XCTAssertTrue(
      dependencies.libraryModel.createRecipe(from: RecipeDraft(title: "Keep Me"))
    )

    dependencies.libraryModel.acceptSampleRecipes()
    let firstIDs = Set(dependencies.libraryModel.recipes.map(\.recipe.id))
    dependencies.libraryModel.acceptSampleRecipes()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.sampleOnboardingResponse, .accepted)
    XCTAssertEqual(dependencies.libraryModel.samplePresence, .complete)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .accepted)
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 4)
    XCTAssertEqual(Set(dependencies.libraryModel.recipes.map(\.recipe.id)), firstIDs)
    XCTAssertTrue(dependencies.libraryModel.recipes.contains { $0.revision.title == "Keep Me" })
  }

  func testAnsweredOnboardingDoesNotAutomaticallyReinsertMissingSamples() throws {
    let preferences = VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted)
    let dependencies = try AppDependencies(
      inMemory: true,
      preferencesStore: preferences
    )

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.samplePresence, .none)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)
    XCTAssertNil(dependencies.libraryModel.issue)
  }

  func testExplicitDisposableFixtureInstallsSamplesWithProvidedPreferences() throws {
    let preferences = VolatileKitchenPreferencesStore(
      sampleRecipeOnboardingResponse: .accepted
    )
    let dependencies = try AppDependencies(
      inMemory: true,
      preferencesStore: preferences,
      installsSampleFixture: true
    )

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.samplePresence, .complete)
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 3)
  }

  func testExplicitFailedInstallationKeepsResponseAndCanBeRetried() throws {
    let preferences = VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .declined)
    let samples = RecoveringSampleProvider()
    let dependencies = try AppDependencies(
      inMemory: true,
      preferencesStore: preferences,
      sampleProvider: samples
    )

    dependencies.libraryModel.loadIfNeeded()
    dependencies.libraryModel.acceptSampleRecipes()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.issue, .samples)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .accepted)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)

    samples.shouldFail = false
    dependencies.libraryModel.retryCurrentIssue()

    XCTAssertNil(dependencies.libraryModel.issue)
    XCTAssertEqual(dependencies.libraryModel.samplePresence, .complete)
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 3)
  }

  func testResetRecordsAcceptedResponseAfterDecliningSamples() throws {
    let preferences = VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .declined)
    let dependencies = try AppDependencies(
      inMemory: true,
      preferencesStore: preferences
    )
    dependencies.libraryModel.loadIfNeeded()

    XCTAssertTrue(dependencies.libraryModel.resetKitchen())

    XCTAssertEqual(dependencies.libraryModel.sampleOnboardingResponse, .accepted)
    XCTAssertEqual(dependencies.libraryModel.samplePresence, .complete)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .accepted)
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 3)
  }

}
