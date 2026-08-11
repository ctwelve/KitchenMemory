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

    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    XCTAssertTrue(recipeRow.waitForExistence(timeout: 5))
    XCTAssertTrue(recipeRow.label.contains("Tuna Noodle Hotdish"))
    recipeRow.click()

    let detail = app.descendants(matching: .any)["recipe-detail"]
    XCTAssertTrue(detail.waitForExistence(timeout: 5))

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
