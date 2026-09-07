// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation
@testable import KitchenMemory
import XCTest

@MainActor
final class SoftwareNoticeTests: XCTestCase {
  func testCompiledBundleContainsTheReviewedDistributionNotices() throws {
    let url = try XCTUnwrap(
      SampleRecipeCatalog.resourceBundle.url(forResource: "ThirdPartyNotices", withExtension: "txt")
    )
    let data = try Data(contentsOf: url)
    // Pin the reviewed upstream license texts, including all Swift runtime exceptions.
    // This checks the built app bundle, so omitted or altered packaged notices fail.
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    XCTAssertEqual(digest, "f68923bf4cc1a9552d1db90f2d6e882518b48da6e178e1f5f33b72eaf1a5a57e")
  }
}
