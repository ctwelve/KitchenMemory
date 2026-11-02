// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import XCTest

/// Shipping controls commit scale changes; local custom-factor edits do not.
final class SessionScalingControlTests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testScalingControlsCommitPresetsAndApplyButNotIntermediateCustomEdits() {
    let app = launchCookingSession()
    defer { app.terminate() }
    openScaling(in: app)
    waitForFactor("1×", in: app)
    let doubled = app.buttons["session-scale-preset-double"]
    activateWhenEnabled(doubled)
    waitForFactor("2×", in: app)
    // A deliberate repeated choice of the accepted value must remain a no-op.
    activateWhenEnabled(doubled)
    waitForFactor("2×", in: app)
    let increment = app.buttons["session-custom-factor-increment"]
    reveal(increment, in: app)
    activateWhenEnabled(increment)
    waitForFactor("2×", in: app)
    let numerator = app.textFields["session-custom-factor-numerator"]
    XCTAssertEqual(numerator.value as? String, "3")
    activateWhenEnabled(app.buttons["session-apply-custom-factor"])
    waitForFactor("3×", in: app)
    closeScaling(in: app)
#if os(macOS)
    assertUndoRestores("2×", in: app)
    assertUndoRestores("1×", in: app)
#endif
  }

  @MainActor
  private func launchCookingSession() -> XCUIApplication {
#if os(iOS)
    XCUIDevice.shared.orientation = .portrait
#endif
    let app = XCUIApplication()
    if app.state != .notRunning { app.terminate() }
    app.launchArguments = [
      "-ApplePersistenceIgnoreState", "YES", "--ui-testing",
      "-AppleLanguages", "(en-US)", "-AppleLocale", "en_US",
    ]
    app.launch()
    let ready = app.descendants(matching: .any)["recipe-library-ready"]
#if os(macOS)
    if !ready.waitForExistence(timeout: 2) {
      app.activate()
      app.typeKey("n", modifierFlags: [.command, .shift])
    }
#endif
    revealSidebar(in: app, exposing: ready)
    XCTAssertTrue(ready.waitForExistence(timeout: 5))
    let row = app.buttons["recipe-row-E3D10000-0000-4000-8000-000000000001"]
    revealSidebar(in: app, exposing: row)
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    activate(row)
    XCTAssertTrue(app.descendants(matching: .any)["recipe-detail"].waitForExistence(timeout: 5))
    startCooking(in: app)
    return app
  }

  @MainActor
  private func startCooking(in app: XCUIApplication) {
    var start = app.buttons["start-cooking"]
    if !start.waitForExistence(timeout: 2) {
      let overflow = app.buttons.matching(NSPredicate(format: "identifier IN %@",
        ["OverflowBarButtonItem", "TopOverflowBarButtonItem"])).firstMatch
      if overflow.exists {
        activate(overflow)
        start = app.buttons["Start Cooking"]
      }
    }
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    activate(start)
    XCTAssertTrue(app.descendants(matching: .any)["cooking-session-shell"].waitForExistence(timeout: 5))
  }

  @MainActor
  private func openScaling(in app: XCUIApplication) {
    let summary = app.buttons["session-scale-summary"]
    XCTAssertTrue(summary.waitForExistence(timeout: 5))
    activate(summary)
    XCTAssertTrue(app.staticTexts["session-scaling-factor"].waitForExistence(timeout: 5))
  }

  @MainActor
  private func closeScaling(in app: XCUIApplication) {
    let done = app.buttons["Done"].firstMatch
    XCTAssertTrue(done.waitForExistence(timeout: 5))
    activate(done)
    expectation(for: NSPredicate(format: "exists == false"),
      evaluatedWith: app.staticTexts["session-scaling-factor"])
    waitForExpectations(timeout: 5)
  }

#if os(macOS)
  @MainActor
  private func assertUndoRestores(_ factor: String, in app: XCUIApplication) {
    app.menuBars.menuBarItems["Edit"].click()
    let undo = app.menuItems["Undo Change Cooking Scale"]
    XCTAssertTrue(undo.waitForExistence(timeout: 5))
    XCTAssertTrue(undo.isEnabled)
    undo.click()
    openScaling(in: app)
    waitForFactor(factor, in: app)
    closeScaling(in: app)
  }
#endif

  @MainActor
  private func waitForFactor(_ factor: String, in app: XCUIApplication) {
    let label = app.staticTexts["session-scaling-factor"]
    expectation(for: NSPredicate(format: "label == %@ OR value == %@", "Scale: " + factor, "Scale: " + factor),
      evaluatedWith: label)
    waitForExpectations(timeout: 5)
  }

  @MainActor
  private func activateWhenEnabled(_ element: XCUIElement) {
    XCTAssertTrue(element.waitForExistence(timeout: 5))
    expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: element)
    waitForExpectations(timeout: 5)
    activate(element)
  }

  @MainActor
  private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
#if os(iOS)
    let scroll = app.scrollViews.containing(.staticText, identifier: "session-scaling-factor").firstMatch
    for _ in 0..<3 where !element.isHittable { scroll.swipeUp() }
#endif
    XCTAssertTrue(element.isHittable)
  }

  @MainActor
  private func revealSidebar(in app: XCUIApplication, exposing element: XCUIElement) {
    guard !element.waitForExistence(timeout: 2) else { return }
#if os(macOS)
    let show = app.buttons["Show Sidebar"].firstMatch
    if show.exists { activate(show) }
#else
    let back = app.buttons["BackButton"].firstMatch
    if back.exists { activate(back) }
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
