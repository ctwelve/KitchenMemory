// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Observation

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
      preference.personalCloudSynchronizationEnabled = isEnabled
    }
  }

  init(
    preference: any CloudSyncPreferenceStoring,
    isEnabledAtLaunch: Bool
  ) {
    self.preference = preference
    self.isEnabledAtLaunch = isEnabledAtLaunch
    isEnabled = preference.personalCloudSynchronizationEnabled
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
