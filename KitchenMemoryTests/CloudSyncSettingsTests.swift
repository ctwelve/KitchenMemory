// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemory
import XCTest

@MainActor
final class CloudSyncSettingsTests: XCTestCase {
  private final class PreferenceStub: CloudSyncPreferenceStoring {
    var isEnabled: Bool

    init(isEnabled: Bool) {
      self.isEnabled = isEnabled
    }
  }

  func testPreferencePreservesExistingEnabledBehaviorAndStoresOptOut() throws {
    let suiteName = "CloudSyncSettingsTests.preference.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preference = UserDefaultsCloudSyncPreference(defaults: defaults)

    XCTAssertTrue(preference.isEnabled)

    preference.isEnabled = false

    XCTAssertFalse(preference.isEnabled)
    XCTAssertFalse(UserDefaultsCloudSyncPreference(defaults: defaults).isEnabled)
  }

  func testReconnectingLocalLibraryRequiresExplicitMergeConfirmation() {
    let preference = PreferenceStub(isEnabled: false)
    let settings = CloudSyncSettings(
      preference: preference,
      isEnabledAtLaunch: false
    )

    XCTAssertEqual(
      settings.requestChange(to: true),
      .requiresReconnectionConfirmation
    )
    XCTAssertFalse(settings.isEnabled)
    XCTAssertFalse(preference.isEnabled)

    settings.confirmReconnection()

    XCTAssertTrue(settings.isEnabled)
    XCTAssertTrue(preference.isEnabled)
    XCTAssertTrue(settings.requiresRelaunch)
  }

  func testPendingOptOutCanBeCancelledWithoutReconnectionWarning() {
    let preference = PreferenceStub(isEnabled: true)
    let settings = CloudSyncSettings(
      preference: preference,
      isEnabledAtLaunch: true
    )

    XCTAssertEqual(settings.requestChange(to: false), .applied)
    XCTAssertTrue(settings.requiresRelaunch)
    XCTAssertEqual(settings.requestChange(to: true), .applied)
    XCTAssertFalse(settings.requiresRelaunch)
  }
}
