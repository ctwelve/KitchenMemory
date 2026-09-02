// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
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
    let preparedApp = try makePreparedApp(preferences: preferences)

    preparedApp.libraryModel.loadIfNeeded()

    XCTAssertEqual(preparedApp.libraryModel.startupState, .choosingSamples)
    XCTAssertEqual(preparedApp.libraryModel.sampleOnboardingResponse, .undecided)
    XCTAssertTrue(preparedApp.libraryModel.recipes.isEmpty)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .undecided)
  }

  func testExternalChangeBeforeInitialLoadLeavesStartupOwnedByLoad() throws {
    let preferences = VolatileKitchenPreferencesStore()
    let preparedApp = try makePreparedApp(preferences: preferences)

    preparedApp.libraryModel.reloadAfterExternalStoreChange()

    XCTAssertFalse(preparedApp.libraryModel.hasLoaded)
    XCTAssertEqual(preparedApp.libraryModel.startupState, .loading)

    preparedApp.libraryModel.loadIfNeeded()
    XCTAssertEqual(preparedApp.libraryModel.startupState, .choosingSamples)
  }

  func testExistingKitchenSkipsAQuestionThatWasNeverAnsweredOnThisDevice() throws {
    let preferences = VolatileKitchenPreferencesStore()
    let preparedApp = try makePreparedApp(
      preferences: preferences,
      initialKitchenWasCreatedOverride: false
    )

    preparedApp.libraryModel.loadIfNeeded()

    XCTAssertEqual(preparedApp.libraryModel.startupState, .ready)
    XCTAssertEqual(preparedApp.libraryModel.sampleOnboardingResponse, .undecided)
    XCTAssertTrue(preparedApp.libraryModel.recipes.isEmpty)
  }

  func testRemoteContentDismissesAnInapplicableQuestionWithoutInventingAnAnswer() throws {
    let preferences = VolatileKitchenPreferencesStore()
    let preparedApp = try makePreparedApp(
      preferences: preferences,
      initialKitchenWasCreatedOverride: true
    )
    preparedApp.libraryModel.loadIfNeeded()
    XCTAssertEqual(preparedApp.libraryModel.startupState, .choosingSamples)

    XCTAssertTrue(
      preparedApp.libraryModel.createRecipe(from: RecipeDraft(title: "Synced Recipe"))
    )
    preparedApp.libraryModel.reloadAfterExternalStoreChange()

    XCTAssertEqual(preparedApp.libraryModel.startupState, .ready)
    XCTAssertEqual(preparedApp.libraryModel.sampleOnboardingResponse, .undecided)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .undecided)
  }

  func testDecliningPersistsTheChoiceAndRevealsTheEmptyLibrary() throws {
    let preferences = VolatileKitchenPreferencesStore()
    let preparedApp = try makePreparedApp(preferences: preferences)
    preparedApp.libraryModel.loadIfNeeded()

    preparedApp.libraryModel.declineSampleRecipes()

    XCTAssertEqual(preparedApp.libraryModel.startupState, .ready)
    XCTAssertEqual(preparedApp.libraryModel.sampleOnboardingResponse, .declined)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .declined)
    XCTAssertTrue(preparedApp.libraryModel.recipes.isEmpty)
  }

  func testAcceptingAddsSamplesBesideUserContentOnlyOnce() throws {
    let preferences = VolatileKitchenPreferencesStore()
    let preparedApp = try makePreparedApp(preferences: preferences)
    preparedApp.libraryModel.loadIfNeeded()
    XCTAssertTrue(
      preparedApp.libraryModel.createRecipe(from: RecipeDraft(title: "Keep Me"))
    )

    preparedApp.libraryModel.acceptSampleRecipes()
    let firstIDs = Set(preparedApp.libraryModel.recipes.map(\.recipe.id))
    preparedApp.libraryModel.acceptSampleRecipes()

    XCTAssertEqual(preparedApp.libraryModel.startupState, .ready)
    XCTAssertEqual(preparedApp.libraryModel.sampleOnboardingResponse, .accepted)
    XCTAssertEqual(preparedApp.libraryModel.samplePresence, .complete)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .accepted)
    XCTAssertEqual(preparedApp.libraryModel.recipes.count, 4)
    XCTAssertEqual(Set(preparedApp.libraryModel.recipes.map(\.recipe.id)), firstIDs)
    XCTAssertTrue(preparedApp.libraryModel.recipes.contains { $0.revision.title == "Keep Me" })
  }

  func testAnsweredOnboardingDoesNotAutomaticallyReinsertMissingSamples() throws {
    let preferences = VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted)
    let preparedApp = try makePreparedApp(preferences: preferences)

    preparedApp.libraryModel.loadIfNeeded()

    XCTAssertEqual(preparedApp.libraryModel.startupState, .ready)
    XCTAssertEqual(preparedApp.libraryModel.samplePresence, .none)
    XCTAssertTrue(preparedApp.libraryModel.recipes.isEmpty)
    XCTAssertNil(preparedApp.libraryModel.issue)
  }

  func testExplicitDisposableFixtureInstallsSamplesWithProvidedPreferences() throws {
    let preferences = VolatileKitchenPreferencesStore(
      sampleRecipeOnboardingResponse: .accepted
    )
    let preparedApp = try makePreparedApp(
      preferences: preferences,
      library: .installed
    )

    preparedApp.libraryModel.loadIfNeeded()

    XCTAssertEqual(preparedApp.libraryModel.startupState, .ready)
    XCTAssertEqual(preparedApp.libraryModel.samplePresence, .complete)
    XCTAssertEqual(preparedApp.libraryModel.recipes.count, 3)
  }

  func testExplicitFailedInstallationKeepsResponseAndCanBeRetried() throws {
    let preferences = VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .declined)
    let samples = RecoveringSampleProvider()
    let preparedApp = try makePreparedApp(
      preferences: preferences,
      sampleProvider: samples
    )

    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.libraryModel.acceptSampleRecipes()

    XCTAssertEqual(preparedApp.libraryModel.startupState, .ready)
    XCTAssertEqual(preparedApp.libraryModel.issue, .samples)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .accepted)
    XCTAssertTrue(preparedApp.libraryModel.recipes.isEmpty)

    samples.shouldFail = false
    preparedApp.libraryModel.retryCurrentIssue()

    XCTAssertNil(preparedApp.libraryModel.issue)
    XCTAssertEqual(preparedApp.libraryModel.samplePresence, .complete)
    XCTAssertEqual(preparedApp.libraryModel.recipes.count, 3)
  }

  func testResetRecordsAcceptedResponseAfterDecliningSamples() throws {
    let preferences = VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .declined)
    let preparedApp = try makePreparedApp(preferences: preferences)
    preparedApp.libraryModel.loadIfNeeded()

    XCTAssertTrue(preparedApp.libraryModel.resetKitchen())

    XCTAssertEqual(preparedApp.libraryModel.sampleOnboardingResponse, .accepted)
    XCTAssertEqual(preparedApp.libraryModel.samplePresence, .complete)
    XCTAssertEqual(preferences.sampleRecipeOnboardingResponse, .accepted)
    XCTAssertEqual(preparedApp.libraryModel.recipes.count, 3)
  }

  private func makePreparedApp(
    preferences: any KitchenPreferencesStoring,
    library: AppLaunchPlan.SampleFixture = .empty,
    sampleProvider: (any SampleRecipeProviding)? = nil,
    initialKitchenWasCreatedOverride: Bool? = nil
  ) throws -> PreparedApp {
    try AppRuntime.testing(AppRuntime.TestingConfiguration(
      library: library,
      preferencesStore: preferences,
      sampleProvider: sampleProvider,
      initialKitchenWasCreatedOverride: initialKitchenWasCreatedOverride
    ))
  }
}
