// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import XCTest

final class CookingSessionLayoutModeTests: XCTestCase {
  func testAvailableWidthSelectsCompactRegularAndWideComposition() {
    XCTAssertEqual(CookingSessionLayoutMode.resolve(width: 539), .compact)
    XCTAssertEqual(CookingSessionLayoutMode.resolve(width: 540), .regular)
    XCTAssertEqual(CookingSessionLayoutMode.resolve(width: 899), .regular)
    XCTAssertEqual(CookingSessionLayoutMode.resolve(width: 900), .wide)
  }

  func testAccessibilityTextUsesCompactReadingOrderAtEveryWidth() {
    XCTAssertEqual(
      CookingSessionLayoutMode.resolve(width: 1_200, usesAccessibilityTextSize: true),
      .compact
    )
  }
}
