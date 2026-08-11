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

    let ingredients = app.descendants(matching: .any)["ingredients-section"]
    XCTAssertTrue(scroll(detail, untilVisible: ingredients))

    let instructions = app.descendants(matching: .any)["instructions-section"]
    XCTAssertTrue(scroll(detail, untilVisible: instructions))
  }

  @MainActor
  private func scroll(
    _ container: XCUIElement,
    untilVisible element: XCUIElement,
    attempts: Int = 6
  ) -> Bool {
    if element.waitForExistence(timeout: 1) { return true }

    for _ in 0..<attempts {
      container.swipeUp()
      if element.waitForExistence(timeout: 1) { return true }
    }

    return false
  }
}
