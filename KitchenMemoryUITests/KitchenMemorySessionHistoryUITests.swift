// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import XCTest

extension KitchenMemoryUITests {
  @MainActor
  func testSessionHistoryContinuationSmoke() {
    let app = launchApp(additionalArguments: ["-AppleLanguages", "(en-US)"])
    openFirstRecipeAndStart(in: app)

    activate(app.buttons["finish-session"])
    let confirmation = app.buttons["confirm-finish-session"].firstMatch
    XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
    activate(confirmation)
    XCTAssertTrue(app.descendants(matching: .any)["finished-session"].waitForExistence(timeout: 5))

    let continuation = app.descendants(matching: .any)["continue-session"]
    XCTAssertTrue(continuation.waitForExistence(timeout: 5))
    activate(continuation)
    XCTAssertTrue(app.descendants(matching: .any)["cooking-session-shell"].waitForExistence(
      timeout: 5
    ))
    activate(app.buttons["leave-session"])
    openSessionHistory(in: app)
    XCTAssertTrue(app.descendants(matching: .any)["sessions-history"].waitForExistence(timeout: 5))

    let finished = app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "finished-session-row-")
    ).firstMatch
    XCTAssertTrue(finished.waitForExistence(timeout: 5))
    activate(finished)
    XCTAssertTrue(app.descendants(matching: .any)["session-lineage"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testCurrentRecentSwitchingAndRecipeHistorySmoke() {
    let app = launchApp(additionalArguments: ["-AppleLanguages", "(en-US)"])
    openFirstRecipeAndStart(in: app)
    activate(app.buttons["leave-session"])
    activate(app.buttons["start-cooking"])
    activate(app.buttons["stop-session"])
    activate(app.buttons["leave-session"])

    openSessionHistory(in: app)
    XCTAssertTrue(app.descendants(matching: .any)["sessions-current"].waitForExistence(timeout: 5))
    let recent = app.descendants(matching: .any)["sessions-recent"]
    XCTAssertTrue(recent.waitForExistence(timeout: 5))
    let recentRow = recent.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "history-session-row-")
    ).firstMatch
    XCTAssertTrue(recentRow.waitForExistence(timeout: 5))
    activate(recentRow)
    XCTAssertTrue(app.buttons["stop-session"].waitForExistence(timeout: 5))
    activate(app.buttons["leave-session"])

    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    activate(recipeRow)
    XCTAssertTrue(app.buttons["recipe-session-history"].waitForExistence(timeout: 5))
    activate(app.buttons["recipe-session-history"])
    XCTAssertTrue(app.descendants(matching: .any)["sessions-history"].waitForExistence(timeout: 5))
  }

  @MainActor
  private func openSessionHistory(in app: XCUIApplication) {
    let destination = app.descendants(matching: .any)["sessions-destination"]
#if os(iOS)
    if !destination.waitForExistence(timeout: 2) {
      let backButton = app.buttons["BackButton"]
      if backButton.waitForExistence(timeout: 3) {
        activate(backButton)
      }
    }
#else
    if !destination.waitForExistence(timeout: 2) {
      let toggle = app.buttons["toggle-sidebar"]
      if toggle.waitForExistence(timeout: 3) {
        activate(toggle)
      }
    }
#endif
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    activate(destination)
  }

  @MainActor
  private func openFirstRecipeAndStart(in app: XCUIApplication) {
    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    XCTAssertTrue(recipeRow.waitForExistence(timeout: 5))
    activate(recipeRow)
    XCTAssertTrue(app.buttons["start-cooking"].waitForExistence(timeout: 5))
    activate(app.buttons["start-cooking"])
    XCTAssertTrue(app.descendants(matching: .any)["cooking-session-shell"].waitForExistence(
      timeout: 5
    ))
  }
}
