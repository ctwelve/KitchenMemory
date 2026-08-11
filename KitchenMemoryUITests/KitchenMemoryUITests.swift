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

    let title = app.descendants(matching: .any)["recipe-title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertTrue(title.label.contains("Tuna Noodle Hotdish"))

    let ingredients = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS[c] %@", "Ingredients"))
      .firstMatch
    let instructions = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS[c] %@", "Instructions"))
      .firstMatch
    XCTAssertTrue(ingredients.waitForExistence(timeout: 2))
    XCTAssertTrue(instructions.waitForExistence(timeout: 2))
  }
}
