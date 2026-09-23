// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import XCTest

final class RecipeReadingLayoutTests: XCTestCase {
  func testRecipePaneAndTextSizeChooseCompositionWithoutChangingReadingOrder() {
    let narrow = RecipeReadingLayout(width: 390, minimumColumnWidth: 320, accessibilityText: false)
    let wide = RecipeReadingLayout(width: 1000, minimumColumnWidth: 320, accessibilityText: false)
    let enlarged = RecipeReadingLayout(width: 1000, minimumColumnWidth: 500, accessibilityText: false)
    let accessible = RecipeReadingLayout(width: 1400, minimumColumnWidth: 320, accessibilityText: true)
    XCTAssertFalse(narrow.sideBySide)
    XCTAssertTrue(wide.sideBySide)
    XCTAssertFalse(enlarged.sideBySide)
    XCTAssertFalse(accessible.sideBySide)
    for layout in [narrow, wide, enlarged, accessible] {
      XCTAssertEqual(layout.readingOrder, [.ingredients, .instructions])
    }
  }
}
