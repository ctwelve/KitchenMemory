// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import Observation

@MainActor
protocol CloudSyncPreferenceStoring: AnyObject {
  var isEnabled: Bool { get set }
}

/// Keeps the iCloud transport choice local to this device.
///
/// The default preserves the synchronization behavior of installations that
/// predate the setting. Unlike sample onboarding, this choice must not travel
/// through iCloud and silently enable or disable another device.
@MainActor
final class UserDefaultsCloudSyncPreference: CloudSyncPreferenceStoring {
  static let key = "personalCloudSynchronizationEnabled"

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var isEnabled: Bool {
    get {
      guard defaults.object(forKey: Self.key) != nil else { return true }
      return defaults.bool(forKey: Self.key)
    }
    set {
      defaults.set(newValue, forKey: Self.key)
    }
  }
}

/// Presents an honest pending state while the current store remains open.
///
/// A SwiftData container chooses its CloudKit database when it is created.
/// Applying a new choice during the same launch would require overlapping two
/// coordinators on one SQLite store, so Settings records the choice and waits
/// for the next clean application launch to rebuild the container.
@MainActor
@Observable
final class CloudSyncSettings {
  enum ChangeResult: Equatable {
    case applied
    case requiresReconnectionConfirmation
  }

  private let preference: any CloudSyncPreferenceStoring
  let isEnabledAtLaunch: Bool
  private(set) var isEnabled: Bool {
    didSet {
      preference.isEnabled = isEnabled
    }
  }

  init(
    preference: any CloudSyncPreferenceStoring,
    isEnabledAtLaunch: Bool
  ) {
    self.preference = preference
    self.isEnabledAtLaunch = isEnabledAtLaunch
    isEnabled = preference.isEnabled
  }

  var requiresRelaunch: Bool {
    isEnabled != isEnabledAtLaunch
  }

  func requestChange(to newValue: Bool) -> ChangeResult {
    guard newValue != isEnabled else { return .applied }
    if newValue, !isEnabledAtLaunch {
      return .requiresReconnectionConfirmation
    }
    isEnabled = newValue
    return .applied
  }

  func confirmReconnection() {
    isEnabled = true
  }
}
