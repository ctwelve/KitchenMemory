// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import XCTest

/// Smoke tests for the durable application shell.
///
/// Product behavior belongs in the domain, logic, import, and persistence
/// suites. Keep this suite small and independent of provisional editor layout,
/// visible copy, and accessibility-tree details while the interface evolves.
final class KitchenMemoryUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testRecipeSidebarLaunchesAndOpensARecipe() {
    let app = launchApp()
    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch

    XCTAssertTrue(recipeRow.waitForExistence(timeout: 5))
    activate(recipeRow)
    XCTAssertTrue(
      app.descendants(matching: .any)["recipe-detail"].waitForExistence(timeout: 5)
    )
  }

#if os(macOS)
  @MainActor
  func testSidebarCanBeHiddenAndShown() {
    let app = launchApp()
    let toggle = app.buttons["toggle-sidebar"]

    XCTAssertTrue(toggle.waitForExistence(timeout: 2))
    activate(toggle)
    XCTAssertTrue(app.buttons["toggle-sidebar"].waitForExistence(timeout: 2))
    activate(app.buttons["toggle-sidebar"])
    XCTAssertTrue(
      app.descendants(matching: .any)["recipe-library"].waitForExistence(timeout: 2)
    )
  }
#endif

  @MainActor
  func testSettingsPresentsDestructiveResetConfirmation() {
    let app = launchApp()
    openSettings(in: app)

    let reset = app.buttons["settings-reset-kitchen"]
    XCTAssertTrue(reset.waitForExistence(timeout: 5))
    activate(reset)
    XCTAssertTrue(app.buttons["confirm-reset-kitchen"].waitForExistence(timeout: 3))
  }

  @MainActor
  func testSettingsPresentsPrivacyDisplay() {
    let app = launchApp()
    openSettings(in: app)

    let privacy = app.descendants(matching: .any)["settings-privacy"]
    XCTAssertTrue(privacy.waitForExistence(timeout: 5))
    activate(privacy)
    XCTAssertTrue(
      app.descendants(matching: .any)["privacy-display"].waitForExistence(timeout: 3)
    )
  }

  @MainActor
  private func launchApp() -> XCUIApplication {
#if os(iOS)
    XCUIDevice.shared.orientation = .portrait
#endif

    let app = XCUIApplication()
    // UI automation always uses disposable sample data and must never touch a
    // developer's local Kitchen.
    app.launchArguments.append("--ui-testing")
    app.launch()

    let recipeLibrary = app.descendants(matching: .any)["recipe-library"]
#if os(iOS)
    if !recipeLibrary.waitForExistence(timeout: 2) {
      // A compact split view may present the selected recipe first. Return to
      // the durable sidebar before exercising either application-shell smoke.
      let backButton = app.buttons["BackButton"]
      if backButton.waitForExistence(timeout: 3) {
        activate(backButton)
      }
    }
#else
    if !recipeLibrary.waitForExistence(timeout: 2) {
      // macOS may restore a previous split-view selection between launches.
      let toggle = app.buttons["toggle-sidebar"]
      if toggle.waitForExistence(timeout: 3) {
        activate(toggle)
      }
    }
#endif
    XCTAssertTrue(recipeLibrary.waitForExistence(timeout: 5))
    return app
  }

  @MainActor
  private func activate(_ element: XCUIElement) {
#if os(macOS)
    element.click()
#else
    element.tap()
#endif
  }

  @MainActor
  private func openSettings(in app: XCUIApplication) {
#if os(macOS)
    app.typeKey(",", modifierFlags: .command)
#else
    let openSettings = app.buttons["open-settings"]
    XCTAssertTrue(openSettings.waitForExistence(timeout: 2))
    activate(openSettings)
#endif
  }
}
