// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

enum AppBuildEnvironment: CaseIterable {
  case debug
  case develop
  case testing
  case production
  case productionTesting

  static var current: Self {
#if TESTING && PRODUCTION
    .productionTesting
#elseif TESTING
    .testing
#elseif DEVELOP
    .develop
#elseif PRODUCTION
    .production
#else
    .debug
#endif
  }

  var synchronizesWithPersonalCloud: Bool {
    self == .develop || self == .production
  }

  var offersCloudSyncSetting: Bool {
    // The unified platform plans run UI smoke through Testing. Expose the
    // setting there while synchronizesWithPersonalCloud remains false, so the
    // smoke can verify reconnection safely against its disposable store.
    self == .develop || self == .testing || self == .production || self == .productionTesting
  }

  var permitsUITestHarness: Bool {
    self == .testing || self == .productionTesting
  }

  var permitsCloudKitSchemaAdministration: Bool {
    self == .develop
  }
}
