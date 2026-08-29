// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

@MainActor
final class KitchenPreferencesStoreTests: XCTestCase {
  private struct Fixture {
    let store: DefaultsKitchenPreferencesStore
    let defaults: UserDefaults
    let suiteName: String
  }

  func testStableOnboardingKeyTreatsMissingAndUnknownValuesAsUndecided() throws {
    let fixture = try makeFixture(testName: #function)
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

    XCTAssertEqual(fixture.store.sampleRecipeOnboardingResponse, .undecided)
    fixture.defaults.set(
      "future-value",
      forKey: DefaultsKitchenPreferencesStore.sampleRecipeOnboardingResponseKey
    )
    XCTAssertEqual(fixture.store.sampleRecipeOnboardingResponse, .undecided)

    fixture.store.sampleRecipeOnboardingResponse = .accepted

    XCTAssertEqual(fixture.store.sampleRecipeOnboardingResponse, .accepted)
    XCTAssertEqual(
      fixture.defaults.string(
        forKey: DefaultsKitchenPreferencesStore.sampleRecipeOnboardingResponseKey
      ),
      SampleRecipeOnboardingResponse.accepted.rawValue
    )
  }

  func testDeviceLocalCloudPreferencePreservesEnabledDefaultAndStoresOptOut() throws {
    let fixture = try makeFixture(testName: #function)
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

    XCTAssertTrue(fixture.store.personalCloudSynchronizationEnabled)

    fixture.store.personalCloudSynchronizationEnabled = false

    XCTAssertFalse(fixture.store.personalCloudSynchronizationEnabled)
    XCTAssertFalse(
      DefaultsKitchenPreferencesStore(defaults: fixture.defaults)
        .personalCloudSynchronizationEnabled
    )
    XCTAssertEqual(
      fixture.defaults.object(
        forKey: DefaultsKitchenPreferencesStore.personalCloudSynchronizationEnabledKey
      ) as? Bool,
      false
    )
  }

  func testOnboardingPreferenceObservationPublishesTypedChanges() async throws {
    let fixture = try makeFixture(testName: #function)
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    let changed = expectation(description: "Defaults change observed")
    var receivedResponse: SampleRecipeOnboardingResponse?
    fixture.store.startObservingSampleRecipeOnboardingResponse {
      receivedResponse = $0
      changed.fulfill()
    }

    fixture.store.sampleRecipeOnboardingResponse = .declined
    await fulfillment(of: [changed], timeout: 1)

    XCTAssertEqual(fixture.store.sampleRecipeOnboardingResponse, .declined)
    XCTAssertEqual(receivedResponse, .declined)
  }

  func testICloudAccountChangeDoesNotRetainThePreviousAccountsAnswer() async throws {
    let fixture = try makeFixture(testName: #function)
    defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
    fixture.store.sampleRecipeOnboardingResponse = .declined
    let changed = expectation(description: "Account change observed")
    var receivedResponse: SampleRecipeOnboardingResponse?
    fixture.store.startObservingSampleRecipeOnboardingResponse {
      receivedResponse = $0
      changed.fulfill()
    }

    fixture.store.receiveExternalChange(reason: NSUbiquitousKeyValueStoreAccountChange)
    await fulfillment(of: [changed], timeout: 1)

    XCTAssertEqual(fixture.store.sampleRecipeOnboardingResponse, .undecided)
    XCTAssertEqual(receivedResponse, .undecided)
  }

  private func makeFixture(
    testName: String
  ) throws -> Fixture {
    let suiteName = "KitchenPreferencesStoreTests.\(testName).\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    let store = DefaultsKitchenPreferencesStore(
      defaults: defaults,
      notificationCenter: NotificationCenter(),
      permitsPersonalPreferencesICloud: false
    )
    return Fixture(store: store, defaults: defaults, suiteName: suiteName)
  }
}
