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
    XCTAssertEqual(digest, "79fc37436859b5e07ad44fa4baec792ac22ccd2cc2a52247649ff6b548d3218e")
  }
}
