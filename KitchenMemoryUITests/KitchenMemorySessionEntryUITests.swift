// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import XCTest

extension KitchenMemoryUITests {
  @MainActor
  func testCookingSessionEntryAndOutcomeSmoke() {
    let app = launchApp(additionalArguments: ["-AppleLanguages", "(en-US)"])
    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    XCTAssertTrue(recipeRow.waitForExistence(timeout: 5))
    activate(recipeRow)
    activate(app.buttons["start-cooking"])

    let draft = app.descendants(matching: .any)["session-entry-draft"]
    if !draft.waitForExistence(timeout: 2) {
#if os(macOS)
      let sessionScrollView = app.scrollViews.firstMatch
      XCTAssertTrue(sessionScrollView.waitForExistence(timeout: 2))
      for _ in 0..<4 where !draft.exists {
        sessionScrollView.swipeUp()
      }
#else
      for _ in 0..<4 where !draft.exists {
        app.swipeUp()
      }
#endif
    }
    XCTAssertTrue(draft.waitForExistence(timeout: 5))
    activate(draft)
    draft.typeText("UI smoke note 🍋")
    let submit = app.buttons["submit-session-entry"]
    XCTAssertTrue(submit.waitForExistence(timeout: 3))
    activate(submit)

    XCTAssertTrue(app.staticTexts["UI smoke note 🍋"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.descendants(matching: .any)["session-outcome"].exists)
  }
}
