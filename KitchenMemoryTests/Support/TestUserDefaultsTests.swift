// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import XCTest

@MainActor
final class TestUserDefaultsTests: XCTestCase {
  func testCleanupRemovesThePersistentPreferenceFile() throws {
    let fixture = try makeTestUserDefaults(suiteNamePrefix: #function)
    fixture.defaults.set(true, forKey: "probe")
    fixture.defaults.synchronize()

    XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.preferencesFileURL.path))

    try fixture.cleanup()

    XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.preferencesFileURL.path))
  }
}
