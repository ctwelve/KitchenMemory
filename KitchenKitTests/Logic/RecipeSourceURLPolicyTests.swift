// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

final class RecipeSourceURLPolicyTests: XCTestCase {
  func testDisplayHostBracketsIPv6AndRejectsInvalidOptionalURLs() {
    XCTAssertEqual(
      RecipeSourceURLPolicy.displayHost(
        for: URL(string: "https://[2001:db8::1]:8443/soup")!
      ),
      "[2001:db8::1]:8443"
    )
    XCTAssertNil(RecipeSourceURLPolicy.validatedURL(nil))
    XCTAssertNil(RecipeSourceURLPolicy.displayHost(for: URL(string: "file:///soup")!))
    XCTAssertEqual(
      RecipeSourceURLPolicy.displayHost(for: URL(string: "https://recipes.example/soup")!),
      "recipes.example"
    )
  }
}
