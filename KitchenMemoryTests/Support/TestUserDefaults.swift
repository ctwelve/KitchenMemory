// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import XCTest

@MainActor
struct TestUserDefaultsFixture {
  let defaults: UserDefaults
  let suiteName: String
  let preferencesFileURL: URL

  init(suiteNamePrefix: String) throws {
    suiteName = "\(suiteNamePrefix).\(UUID().uuidString)"
    defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    preferencesFileURL = try XCTUnwrap(
      FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
    )
    .appending(path: "Preferences")
    .appending(path: "\(suiteName).plist")
  }

  func cleanup() throws {
    defaults.removePersistentDomain(forName: suiteName)
    defaults.synchronize()
    if FileManager.default.fileExists(atPath: preferencesFileURL.path) {
      try FileManager.default.removeItem(at: preferencesFileURL)
    }
  }
}

@MainActor
extension XCTestCase {
  func makeTestUserDefaults(suiteNamePrefix: String) throws -> TestUserDefaultsFixture {
    let fixture = try TestUserDefaultsFixture(suiteNamePrefix: suiteNamePrefix)
    addTeardownBlock {
      try fixture.cleanup()
    }
    return fixture
  }
}
