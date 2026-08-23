// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemory
import Foundation
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
    let preferences = VolatileSampleRecipeOnboardingStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleOnboardingStore: preferences
    )

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.startupState, .choosingSamples)
    XCTAssertEqual(dependencies.libraryModel.sampleOnboardingResponse, .undecided)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)
    XCTAssertEqual(preferences.response, .undecided)
  }

  func testDecliningPersistsTheChoiceAndRevealsTheEmptyLibrary() throws {
    let preferences = VolatileSampleRecipeOnboardingStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleOnboardingStore: preferences
    )
    dependencies.libraryModel.loadIfNeeded()

    dependencies.libraryModel.declineSampleRecipes()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.sampleOnboardingResponse, .declined)
    XCTAssertEqual(preferences.response, .declined)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)
  }

  func testAcceptingAddsSamplesBesideUserContentOnlyOnce() throws {
    let preferences = VolatileSampleRecipeOnboardingStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleOnboardingStore: preferences
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
    XCTAssertEqual(preferences.response, .accepted)
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 3)
    XCTAssertEqual(Set(dependencies.libraryModel.recipes.map(\.recipe.id)), firstIDs)
    XCTAssertTrue(dependencies.libraryModel.recipes.contains { $0.revision.title == "Keep Me" })
  }

  func testAnsweredOnboardingDoesNotAutomaticallyReinsertMissingSamples() throws {
    let preferences = VolatileSampleRecipeOnboardingStore(response: .accepted)
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleOnboardingStore: preferences
    )

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.samplePresence, .none)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)
    XCTAssertNil(dependencies.libraryModel.issue)
  }

  func testExplicitFailedInstallationKeepsResponseAndCanBeRetried() throws {
    let preferences = VolatileSampleRecipeOnboardingStore(response: .declined)
    let samples = RecoveringSampleProvider()
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleOnboardingStore: preferences,
      sampleProvider: samples
    )

    dependencies.libraryModel.loadIfNeeded()
    dependencies.libraryModel.acceptSampleRecipes()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.issue, .samples)
    XCTAssertEqual(preferences.response, .accepted)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)

    samples.shouldFail = false
    dependencies.libraryModel.retryCurrentIssue()

    XCTAssertNil(dependencies.libraryModel.issue)
    XCTAssertEqual(dependencies.libraryModel.samplePresence, .complete)
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 2)
  }

  func testResetRecordsAcceptedResponseAfterDecliningSamples() throws {
    let preferences = VolatileSampleRecipeOnboardingStore(response: .declined)
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleOnboardingStore: preferences
    )
    dependencies.libraryModel.loadIfNeeded()

    XCTAssertTrue(dependencies.libraryModel.resetKitchen())

    XCTAssertEqual(dependencies.libraryModel.sampleOnboardingResponse, .accepted)
    XCTAssertEqual(dependencies.libraryModel.samplePresence, .complete)
    XCTAssertEqual(preferences.response, .accepted)
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 2)
  }

  func testUserDefaultsStoreTreatsMissingAndUnknownValuesAsUndecided() throws {
    let suiteName = "RecipeLibraryStartupTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSampleRecipeOnboardingStore(defaults: defaults)

    XCTAssertEqual(store.response, .undecided)
    defaults.set("future-value", forKey: UserDefaultsSampleRecipeOnboardingStore.key)
    XCTAssertEqual(store.response, .undecided)

    store.response = .accepted
    XCTAssertEqual(store.response, .accepted)
  }
}
