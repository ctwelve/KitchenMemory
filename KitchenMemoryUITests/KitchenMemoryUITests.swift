// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import XCTest

final class KitchenMemoryUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testStarterRecipeCanBeRead() throws {
    let app = XCUIApplication()
    app.launchArguments.append("--ui-testing")
    app.launch()

    XCTAssertTrue(app.staticTexts["recipe-title"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["recipe-title"].label.contains("Tuna Noodle Hotdish"))
    XCTAssertTrue(app.staticTexts["Ingredients"].exists)
    XCTAssertTrue(app.staticTexts["Instructions"].exists)
  }
}
