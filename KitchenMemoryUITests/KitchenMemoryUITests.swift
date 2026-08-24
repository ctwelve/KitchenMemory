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
    let toggle = sidebarToggle(in: app)

    XCTAssertTrue(toggle.waitForExistence(timeout: 2))
    activate(toggle)
    let hiddenToggle = sidebarToggle(in: app)
    XCTAssertTrue(hiddenToggle.waitForExistence(timeout: 2))
    activate(hiddenToggle)
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
  func testEnglishInterfaceLaunchesTheLocalizedShell() {
    assertLocalizedShell(localeIdentifier: "en-US")
  }

  @MainActor
  func testCanadianFrenchInterfaceLaunchesTheLocalizedShell() {
    assertLocalizedShell(localeIdentifier: "fr-CA")
  }

  @MainActor
  func testMexicanSpanishInterfaceLaunchesTheLocalizedShell() {
    assertLocalizedShell(localeIdentifier: "es-MX")
  }

  @MainActor
  func testDoubleLocalizationLaunchesTheDurableShell() {
    assertDurableShell(arguments: ["-NSDoubleLocalizedStrings", "YES"])
  }

  @MainActor
  func testRightToLeftLocalizationLaunchesTheDurableShell() {
    assertDurableShell(arguments: ["-NSForceRightToLeftWritingDirection", "YES"])
  }

  @MainActor
  func testStartupFailureOffersAStableRecoverySurface() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-ApplePersistenceIgnoreState", "YES",
      "--ui-testing", "--simulate-startup-failure",
    ]
    app.launch()

    // The actionable child is the stable cross-platform signal that the
    // privacy-safe recovery surface is present.
    let retryButton = app.buttons["retry-startup"]
    ensurePrimaryWindow(in: app, exposing: retryButton)
    XCTAssertTrue(
      retryButton.waitForExistence(timeout: 5),
      "Expected the startup recovery action."
    )
    app.terminate()
  }

  @MainActor
  private func launchApp(additionalArguments: [String] = []) -> XCUIApplication {
#if os(iOS)
    XCUIDevice.shared.orientation = .portrait
#endif

    let app = XCUIApplication()
    // UI automation always uses disposable sample data and must never touch a
    // developer's local Kitchen. Ignoring persisted window state also makes a
    // macOS launch deterministic after somebody quits with no windows open.
    app.launchArguments.append(contentsOf: ["-ApplePersistenceIgnoreState", "YES"])
    app.launchArguments.append("--ui-testing")
    app.launchArguments.append(contentsOf: additionalArguments)
    app.launch()

    let recipeLibrary = app.descendants(matching: .any)["recipe-library"]
    ensurePrimaryWindow(in: app, exposing: recipeLibrary)
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
  private func ensurePrimaryWindow(in app: XCUIApplication, exposing element: XCUIElement) {
#if os(macOS)
    if !element.waitForExistence(timeout: 2) {
      // XCUITest can relaunch a WindowGroup app into a retained no-window
      // lifecycle even when persisted restoration state is disabled. Command-N
      // exercises the public New Window path without depending on localized UI.
      app.activate()
      app.typeKey("n", modifierFlags: .command)
    }
#endif
  }

#if os(macOS)
  @MainActor
  private func sidebarToggle(in app: XCUIApplication) -> XCUIElement {
    let toggle = app.descendants(matching: .any)["toggle-sidebar"]
    if !toggle.exists {
      // The compact default test window can place trailing toolbar actions in
      // AppKit's overflow menu. Open it without coupling the smoke to a label.
      let toolbarOverflow = app.popUpButtons.firstMatch
      if toolbarOverflow.waitForExistence(timeout: 2) {
        activate(toolbarOverflow)
        let overflowActions = toolbarOverflow.menuItems
        if overflowActions.count > 1 {
          // The sidebar action trails the other overflowed primary actions.
          return overflowActions.element(boundBy: overflowActions.count - 1)
        }
      }
    }
    return toggle
  }
#endif

  @MainActor
  private func assertLocalizedShell(localeIdentifier: String) {
    let app = launchApp(additionalArguments: [
      "-AppleLanguages", "(\(localeIdentifier))",
      "-AppleLocale", localeIdentifier,
    ])
    openSettings(in: app)

    let privacy = app.descendants(matching: .any)["settings-privacy"]
    XCTAssertTrue(
      privacy.waitForExistence(timeout: 5),
      "Missing localized Privacy row for \(localeIdentifier)"
    )
    activate(privacy)
    XCTAssertTrue(
      app.descendants(matching: .any)["privacy-display"].waitForExistence(timeout: 3),
      "Missing localized Privacy display for \(localeIdentifier)"
    )
  }

  @MainActor
  private func assertDurableShell(arguments: [String]) {
    let app = launchApp(additionalArguments: arguments)
    XCTAssertTrue(
      app.descendants(matching: .any)["recipe-library"].exists,
      "The durable shell failed under localization arguments: \(arguments)"
    )
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
