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

  func testUndecidedConsentShowsChoiceBeforeAnEmptyLibrary() throws {
    let preferences = VolatileSampleRecipeConsentStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleConsentStore: preferences
    )

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.startupState, .choosingSamples)
    XCTAssertEqual(dependencies.libraryModel.sampleConsent, .undecided)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)
    XCTAssertEqual(preferences.consent, .undecided)
  }

  func testDecliningPersistsTheChoiceAndRevealsTheEmptyLibrary() throws {
    let preferences = VolatileSampleRecipeConsentStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleConsentStore: preferences
    )
    dependencies.libraryModel.loadIfNeeded()

    dependencies.libraryModel.declineSampleRecipes()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.sampleConsent, .declined)
    XCTAssertEqual(preferences.consent, .declined)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)
  }

  func testAcceptingAddsSamplesBesideUserContentOnlyOnce() throws {
    let preferences = VolatileSampleRecipeConsentStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleConsentStore: preferences
    )
    dependencies.libraryModel.loadIfNeeded()
    XCTAssertTrue(
      dependencies.libraryModel.createRecipe(from: RecipeDraft(title: "Keep Me"))
    )

    dependencies.libraryModel.acceptSampleRecipes()
    let firstIDs = Set(dependencies.libraryModel.recipes.map(\.recipe.id))
    dependencies.libraryModel.acceptSampleRecipes()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.sampleConsent, .accepted)
    XCTAssertEqual(preferences.consent, .accepted)
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 3)
    XCTAssertEqual(Set(dependencies.libraryModel.recipes.map(\.recipe.id)), firstIDs)
    XCTAssertTrue(dependencies.libraryModel.recipes.contains { $0.revision.title == "Keep Me" })
  }

  func testFailedInstallationKeepsConsentAndCanBeRetried() throws {
    let preferences = VolatileSampleRecipeConsentStore(consent: .accepted)
    let samples = RecoveringSampleProvider()
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleConsentStore: preferences,
      sampleProvider: samples
    )

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.issue, .samples)
    XCTAssertEqual(preferences.consent, .accepted)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)

    samples.shouldFail = false
    dependencies.libraryModel.retryCurrentIssue()

    XCTAssertNil(dependencies.libraryModel.issue)
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 2)
  }

  func testResetRecordsAcceptedConsentAfterDecliningSamples() throws {
    let preferences = VolatileSampleRecipeConsentStore(consent: .declined)
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleConsentStore: preferences
    )
    dependencies.libraryModel.loadIfNeeded()

    XCTAssertTrue(dependencies.libraryModel.resetKitchen())

    XCTAssertEqual(dependencies.libraryModel.sampleConsent, .accepted)
    XCTAssertEqual(preferences.consent, .accepted)
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 2)
  }

  func testUserDefaultsStoreTreatsMissingAndUnknownValuesAsUndecided() throws {
    let suiteName = "RecipeLibraryStartupTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsSampleRecipeConsentStore(defaults: defaults)

    XCTAssertEqual(store.consent, .undecided)
    defaults.set("future-value", forKey: UserDefaultsSampleRecipeConsentStore.key)
    XCTAssertEqual(store.consent, .undecided)

    store.consent = .accepted
    XCTAssertEqual(store.consent, .accepted)
  }
}
