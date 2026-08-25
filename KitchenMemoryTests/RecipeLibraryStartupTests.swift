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

  @MainActor
  private final class FakeUbiquitousKeyValueStore: UbiquitousKeyValueStoring {
    var values: [String: String] = [:]
    var synchronizationCount = 0

    var notificationObject: AnyObject { self }

    func onboardingString(forKey key: String) -> String? {
      values[key]
    }

    func setOnboardingString(_ value: String, forKey key: String) {
      values[key] = value
    }

    func synchronizeOnboardingStore() -> Bool {
      synchronizationCount += 1
      return true
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

  func testExternalChangeBeforeInitialLoadLeavesStartupOwnedByLoad() throws {
    let preferences = VolatileSampleRecipeOnboardingStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleOnboardingStore: preferences
    )

    dependencies.libraryModel.reloadAfterExternalStoreChange()

    XCTAssertFalse(dependencies.libraryModel.hasLoaded)
    XCTAssertEqual(dependencies.libraryModel.startupState, .loading)

    dependencies.libraryModel.loadIfNeeded()
    XCTAssertEqual(dependencies.libraryModel.startupState, .choosingSamples)
  }

  func testExistingKitchenSkipsAQuestionThatWasNeverAnsweredOnThisDevice() throws {
    let preferences = VolatileSampleRecipeOnboardingStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleOnboardingStore: preferences,
      initialKitchenWasCreatedOverride: false
    )

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.startupState, .ready)
    XCTAssertEqual(dependencies.libraryModel.sampleOnboardingResponse, .undecided)
    XCTAssertTrue(dependencies.libraryModel.recipes.isEmpty)
  }

  func testRemoteContentDismissesAnInapplicableQuestionWithoutInventingAnAnswer() throws {
    let preferences = VolatileSampleRecipeOnboardingStore()
    let dependencies = try AppDependencies(
      inMemory: true,
      sampleOnboardingStore: preferences,
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
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 4)
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
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 3)
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
    XCTAssertEqual(dependencies.libraryModel.recipes.count, 3)
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

  func testUbiquitousStoreMirrorsExplicitAnswersAndReceivesICloudChanges() throws {
    let suiteName = "RecipeLibraryStartupTests.iCloud.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let cloudStore = FakeUbiquitousKeyValueStore()
    let store = UbiquitousSampleRecipeOnboardingStore(
      defaults: defaults,
      ubiquitousStore: cloudStore,
      notificationCenter: NotificationCenter()
    )
    var receivedResponses: [SampleRecipeOnboardingResponse] = []

    store.startObservingChanges { receivedResponses.append($0) }
    XCTAssertEqual(cloudStore.synchronizationCount, 1)

    store.response = .declined
    XCTAssertEqual(
      cloudStore.values[UserDefaultsSampleRecipeOnboardingStore.key],
      SampleRecipeOnboardingResponse.declined.rawValue
    )
    XCTAssertEqual(store.response, .declined)

    cloudStore.values[UserDefaultsSampleRecipeOnboardingStore.key] =
      SampleRecipeOnboardingResponse.accepted.rawValue
    store.receiveExternalChange(
      changedKeys: [UserDefaultsSampleRecipeOnboardingStore.key],
      reason: NSUbiquitousKeyValueStoreServerChange
    )

    XCTAssertEqual(store.response, .accepted)
    XCTAssertEqual(receivedResponses, [.accepted])
    XCTAssertEqual(
      defaults.string(forKey: UserDefaultsSampleRecipeOnboardingStore.key),
      SampleRecipeOnboardingResponse.accepted.rawValue
    )
  }

  func testUbiquitousStoreMigratesAnExistingLocalAnswerAfterSynchronization() throws {
    let suiteName = "RecipeLibraryStartupTests.migration.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(
      SampleRecipeOnboardingResponse.declined.rawValue,
      forKey: UserDefaultsSampleRecipeOnboardingStore.key
    )
    let cloudStore = FakeUbiquitousKeyValueStore()
    let store = UbiquitousSampleRecipeOnboardingStore(
      defaults: defaults,
      ubiquitousStore: cloudStore,
      notificationCenter: NotificationCenter()
    )

    store.startObservingChanges { _ in }

    XCTAssertEqual(
      cloudStore.values[UserDefaultsSampleRecipeOnboardingStore.key],
      SampleRecipeOnboardingResponse.declined.rawValue
    )
  }

  func testICloudAccountChangeDoesNotRetainThePreviousAccountsAnswer() throws {
    let suiteName = "RecipeLibraryStartupTests.account.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(
      SampleRecipeOnboardingResponse.declined.rawValue,
      forKey: UserDefaultsSampleRecipeOnboardingStore.key
    )
    let cloudStore = FakeUbiquitousKeyValueStore()
    let store = UbiquitousSampleRecipeOnboardingStore(
      defaults: defaults,
      ubiquitousStore: cloudStore,
      notificationCenter: NotificationCenter()
    )
    var receivedResponse: SampleRecipeOnboardingResponse?
    store.startObservingChanges { receivedResponse = $0 }
    cloudStore.values.removeValue(forKey: UserDefaultsSampleRecipeOnboardingStore.key)

    store.receiveExternalChange(
      changedKeys: nil,
      reason: NSUbiquitousKeyValueStoreAccountChange
    )

    XCTAssertEqual(store.response, .undecided)
    XCTAssertEqual(receivedResponse, .undecided)
  }
}
