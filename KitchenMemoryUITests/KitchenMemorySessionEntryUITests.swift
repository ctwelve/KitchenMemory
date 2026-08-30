// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import XCTest

extension KitchenMemoryUITests {
  @MainActor
  func testCookingSessionEntryShellSmoke() {
    let app = launchApp(additionalArguments: ["-AppleLanguages", "(en-US)"])
    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    XCTAssertTrue(recipeRow.waitForExistence(timeout: 5))
    activate(recipeRow)
    activate(app.buttons["start-cooking"])

    XCTAssertTrue(app.descendants(matching: .any)["session-entries"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any)["session-entry-draft"].exists)
    XCTAssertTrue(app.buttons["submit-session-entry"].exists)
    XCTAssertTrue(app.descendants(matching: .any)["session-outcome"].exists)
  }
}
