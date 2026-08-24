// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import XCTest

final class PrivacyManifestTests: XCTestCase {
  func testApplicationPrivacyManifestMatchesCurrentPolicy() throws {
    let appBundle = try XCTUnwrap(
      Bundle.allBundles.first { $0.bundleIdentifier == "net.ctwelve.KitchenMemory" }
    )
    let manifestURL = try XCTUnwrap(
      appBundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")
    )
    let data = try Data(contentsOf: manifestURL)
    let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
    let manifest = try XCTUnwrap(propertyList as? [String: Any])

    XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
    XCTAssertEqual(manifest["NSPrivacyTrackingDomains"] as? [String], [])
    XCTAssertEqual(
      (manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])?.isEmpty,
      true
    )

    let accessedAPITypes = try XCTUnwrap(
      manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]]
    )
    XCTAssertEqual(accessedAPITypes.count, 1)
    XCTAssertEqual(
      accessedAPITypes[0]["NSPrivacyAccessedAPIType"] as? String,
      "NSPrivacyAccessedAPICategoryUserDefaults"
    )
    XCTAssertEqual(
      accessedAPITypes[0]["NSPrivacyAccessedAPITypeReasons"] as? [String],
      ["CA92.1"]
    )
  }
}
