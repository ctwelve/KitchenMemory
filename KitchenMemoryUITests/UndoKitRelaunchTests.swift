// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import XCTest

final class UndoKitRelaunchTests: XCTestCase {
  @MainActor
  func testUnacknowledgedAcceptanceRecoversAfterApplicationTerminationWithoutDuplicateEffects() {
    continueAfterFailure = false
    let app = XCUIApplication()
    if app.state != .notRunning { app.terminate() }
    app.launchArguments = [
      "-ApplePersistenceIgnoreState", "YES", "--ui-testing", "--undo-qualification", UUID().uuidString,
    ]
    app.launch()
    let state = app.staticTexts["undo-qualification-state"]
    ensureWindow(app, state: state)
    waitForState("Soup, Bread; accepted: 0", in: state)
    activate(app.buttons["undo-qualification-lose-reply"])
    waitForState("Bread, Soup; accepted: 1", in: state)
    XCTAssertFalse(app.buttons["undo-qualification-undo"].isEnabled)
    app.terminate()
    app.launch()
    ensureWindow(app, state: state)
    waitForState("Bread, Soup; accepted: 1", in: state)
    XCTAssertTrue(app.buttons["undo-qualification-undo"].isEnabled)
    activate(app.buttons["undo-qualification-undo"])
    waitForState("Soup, Bread; accepted: 2", in: state)
    activate(app.buttons["undo-qualification-cleanup"])
    waitForState("Removed", in: state)
    app.terminate()
  }

  @MainActor
  func testAcceptedCollectionAndNativeUndoSurviveApplicationTermination() {
    continueAfterFailure = false
    let app = XCUIApplication()
    if app.state != .notRunning { app.terminate() }
    let identifier = UUID().uuidString
    app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "--ui-testing", "--undo-qualification", identifier]
    app.launch()
    let state = app.staticTexts["undo-qualification-state"]
    ensureWindow(app, state: state)
    XCTAssertTrue(state.waitForExistence(timeout: 15))
    waitForState("Soup, Bread; accepted: 0", in: state)
    activate(app.buttons["undo-qualification-apply"])
    waitForState("Bread, Soup; accepted: 1", in: state)
    app.terminate()
    app.launch()
    ensureWindow(app, state: state)
    XCTAssertTrue(state.waitForExistence(timeout: 15))
    waitForState("Bread, Soup; accepted: 1", in: state)
    activate(app.buttons["undo-qualification-undo"])
    waitForState("Soup, Bread; accepted: 2", in: state)
    activate(app.buttons["undo-qualification-redo"])
    waitForState("Bread, Soup; accepted: 3", in: state)
    activate(app.buttons["undo-qualification-cleanup"])
    waitForState("Removed", in: state)
    app.terminate()
  }

  @MainActor
  private func waitForState(_ value: String, in element: XCUIElement) {
    expectation(for: NSPredicate(format: "label == %@ OR value == %@", value, value), evaluatedWith: element)
    waitForExpectations(timeout: 10)
  }

  @MainActor
  private func ensureWindow(_ app: XCUIApplication, state: XCUIElement) {
#if os(macOS)
    if !state.waitForExistence(timeout: 2) {
      app.activate()
      app.typeKey("n", modifierFlags: [.command, .shift])
    }
#endif
  }

  @MainActor
  private func activate(_ element: XCUIElement) {
#if os(macOS)
    element.click()
#else
    element.tap()
#endif
  }
}
