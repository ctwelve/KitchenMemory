// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import Observation
import XCTest

@MainActor
final class KitchenPreferencesStoreTests: XCTestCase {
  private struct Fixture {
    let store: DefaultsKitchenPreferencesStore
    let defaults: UserDefaults
  }

  func testOrganizationPreferencesAdoptExistingRawStorage() throws {
    let fixture = try makeFixture(testName: #function)
    let kitchenID = Kitchen.ID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000215")!)
    let folderID = Folder.ID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    let prefix = "organization.owner.local.00000000-0000-0000-0000-000000000215"
    fixture.defaults.set(false, forKey: "organization.folders.enabled")
    fixture.defaults.set(false, forKey: "organization.tags.enabled")
    fixture.defaults.set(false, forKey: prefix + ".tags-expanded")
    fixture.defaults.set(["invalid", folderID.rawValue.uuidString], forKey: prefix + ".expanded")

    let preferences = fixture.store.organizationPreferences(scope: "owner.local", kitchenID: kitchenID)

    XCTAssertFalse(preferences.foldersEnabled)
    XCTAssertFalse(preferences.tagsEnabled)
    XCTAssertFalse(preferences.tagsExpanded)
    XCTAssertEqual(preferences.expanded, [folderID])
    XCTAssertEqual(fixture.defaults.stringArray(forKey: prefix + ".expanded"),
                   ["invalid", folderID.rawValue.uuidString])
  }

  func testOrganizationPreferenceChangesNotifyAnotherBoundConsumer() async throws {
    let fixture = try makeFixture(testName: #function)
    let kitchenID = Kitchen.ID()
    let settings = fixture.store.organizationPreferences(scope: "owner.local", kitchenID: kitchenID)
    let sidebar = fixture.store.organizationPreferences(scope: "owner.local", kitchenID: kitchenID)
    let changed = expectation(description: "Sidebar observes Settings visibility")
    withObservationTracking {
      _ = sidebar.foldersEnabled
    } onChange: {
      changed.fulfill()
    }

    settings.foldersEnabled = false
    await fulfillment(of: [changed], timeout: 1)

    XCTAssertFalse(sidebar.foldersEnabled)
  }

  func testOrganizationScopesShareDeviceVisibilityButNeverExpansion() throws {
    let fixture = try makeFixture(testName: #function)
    let stores: [any KitchenPreferencesStoring] = [fixture.store, VolatileKitchenPreferencesStore()]
    for store in stores {
      let kitchenID = Kitchen.ID(), folderID = Folder.ID()
      let first = store.organizationPreferences(scope: "owner.local", kitchenID: kitchenID)
      first.foldersEnabled = false
      first.tagsEnabled = false
      first.tagsExpanded = false
      first.expanded = [folderID]

      for other in [
        store.organizationPreferences(scope: "other.local", kitchenID: kitchenID),
        store.organizationPreferences(scope: "owner.cloud", kitchenID: kitchenID),
        store.organizationPreferences(scope: "owner.local", kitchenID: Kitchen.ID()),
      ] {
        XCTAssertFalse(other.foldersEnabled)
        XCTAssertFalse(other.tagsEnabled)
        XCTAssertTrue(other.tagsExpanded)
        XCTAssertTrue(other.expanded.isEmpty)
      }
      let rebound = store.organizationPreferences(scope: "owner.local", kitchenID: kitchenID)
      XCTAssertFalse(rebound.tagsExpanded)
      XCTAssertEqual(rebound.expanded, [folderID])
    }

    let otherDevice = try makeFixture(testName: #function + "other-device")
    let other = otherDevice.store.organizationPreferences(scope: "owner.local", kitchenID: Kitchen.ID())
    XCTAssertTrue(other.foldersEnabled)
    XCTAssertTrue(other.tagsEnabled)
  }

  func testOrganizationResetSurvivesRelaunchWithoutReadoptingLegacyExpansion() throws {
    let fixture = try makeFixture(testName: #function)
    let kitchenID = Kitchen.ID(), folderID = Folder.ID()
    let prefix = "organization.owner.local." + kitchenID.rawValue.uuidString
    fixture.defaults.set(false, forKey: prefix + ".tags-expanded")
    fixture.defaults.set([folderID.rawValue.uuidString], forKey: prefix + ".expanded")
    let preferences = fixture.store.organizationPreferences(scope: "owner.local", kitchenID: kitchenID)
    preferences.foldersEnabled = false
    preferences.tagsEnabled = false
    XCTAssertEqual(preferences.expanded, [folderID])

    preferences.resetExpansion()

    let relaunched = DefaultsKitchenPreferencesStore(defaults: fixture.defaults)
      .organizationPreferences(scope: "owner.local", kitchenID: kitchenID)
    XCTAssertFalse(relaunched.foldersEnabled)
    XCTAssertFalse(relaunched.tagsEnabled)
    XCTAssertTrue(relaunched.tagsExpanded)
    XCTAssertTrue(relaunched.expanded.isEmpty)
    relaunched.expanded = [folderID]
    relaunched.tagsExpanded = false
    let reopened = DefaultsKitchenPreferencesStore(defaults: fixture.defaults)
      .organizationPreferences(scope: "owner.local", kitchenID: kitchenID)
    XCTAssertEqual(reopened.expanded, [folderID])
    XCTAssertFalse(reopened.tagsExpanded)
  }

  func testOrganizationMissingAndMalformedValuesRetainDefaults() throws {
    let fixture = try makeFixture(testName: #function)
    let kitchenID = Kitchen.ID()
    fixture.defaults.set("invalid", forKey: "organization.folders.enabled")
    fixture.defaults.set(42, forKey: "organization.owner." + kitchenID.rawValue.uuidString + ".expanded")
    let preferences = fixture.store.organizationPreferences(scope: "owner", kitchenID: kitchenID)
    XCTAssertTrue(preferences.foldersEnabled)
    XCTAssertTrue(preferences.tagsEnabled)
    XCTAssertTrue(preferences.tagsExpanded)
    XCTAssertTrue(preferences.expanded.isEmpty)
  }

  func testStableOnboardingKeyTreatsMissingAndUnknownValuesAsUndecided() throws {
    let fixture = try makeFixture(testName: #function)

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
    let preferences = try makeTestUserDefaults(
      suiteNamePrefix: "KitchenPreferencesStoreTests.\(testName)"
    )
    let store = DefaultsKitchenPreferencesStore(
      defaults: preferences.defaults,
      notificationCenter: NotificationCenter(),
      permitsPersonalPreferencesICloud: false
    )
    return Fixture(store: store, defaults: preferences.defaults)
  }
}
