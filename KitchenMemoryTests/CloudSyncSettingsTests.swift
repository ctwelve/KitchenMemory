// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import XCTest

@MainActor
final class CloudSyncSettingsTests: XCTestCase {
  private final class PreferenceStub: CloudSyncPreferenceStoring {
    var personalCloudSynchronizationEnabled: Bool

    init(isEnabled: Bool) {
      personalCloudSynchronizationEnabled = isEnabled
    }
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
    XCTAssertFalse(preference.personalCloudSynchronizationEnabled)

    settings.confirmReconnection()

    XCTAssertTrue(settings.isEnabled)
    XCTAssertTrue(preference.personalCloudSynchronizationEnabled)
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
