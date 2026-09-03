// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import XCTest

/// Accessibility-oriented checks for the durable application shell.
///
/// These tests prove that top-level destinations are exposed through the
/// accessibility hierarchy with meaningful names. Product behavior belongs in
/// the domain, Logic, persistence, and hosted application suites.
final class KitchenMemoryUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testTopLevelDestinationsExposeAccessibleNavigation() {
    let app = launchApp()
    let shell = app.descendants(matching: .any)["recipe-library-shell"]
    assertAccessibleLabel(shell, description: "recipe library")

    visitTopLevelDestination(
      "sessions-destination",
      revealing: "sessions-history",
      description: "Sessions",
      in: app
    )
    visitTopLevelDestination(
      "deleted-items-destination",
      revealing: "deleted-items",
      description: "Deleted Items",
      in: app
    )
    visitTopLevelDestination(
      "recovery-destination",
      revealing: "session-recovery",
      description: "Recovery",
      in: app
    )

    let recipeRow = app.buttons
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    revealSidebar(in: app, exposing: recipeRow)
    XCTAssertTrue(recipeRow.waitForExistence(timeout: 5))
    assertAccessibleLabel(recipeRow, description: "recipe")
    activate(recipeRow)

    let recipeDetail = app.descendants(matching: .any)["recipe-detail"]
    XCTAssertTrue(recipeDetail.waitForExistence(timeout: 5))
    assertAccessibleLabel(recipeDetail, description: "recipe detail")
    app.terminate()
  }

  @MainActor
  func testSettingsExposeAccessibleTopLevelStructure() {
    let app = launchApp(additionalArguments: ["--ui-testing-cloud-sync-disabled"])
    openSettings(in: app)

    let synchronization = app.switches["settings-icloud-sync"]
    XCTAssertTrue(synchronization.waitForExistence(timeout: 5))
    assertAccessibleLabel(synchronization, description: "iCloud synchronization setting")
    app.terminate()
  }

  @MainActor
  func testStartupFailureExposesAccessibleRecoveryAction() {
    let app = XCUIApplication()
    terminateRetainedApplicationIfNeeded(app)
    app.launchArguments = [
      "-ApplePersistenceIgnoreState", "YES",
      "--ui-testing", "--simulate-startup-failure",
    ]
    app.launch()

    let retry = app.buttons["retry-startup"]
    ensurePrimaryWindow(in: app, exposing: retry)
    XCTAssertTrue(retry.waitForExistence(timeout: 5))
    assertAccessibleLabel(retry, description: "startup recovery action")
    app.terminate()
  }

  @MainActor
  private func visitTopLevelDestination(
    _ identifier: String,
    revealing detailIdentifier: String,
    description: String,
    in app: XCUIApplication
  ) {
    let destination = app.buttons[identifier]
    revealSidebar(in: app, exposing: destination)
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    assertAccessibleLabel(destination, description: "\(description) destination")
    XCTAssertTrue(
      destination.isEnabled,
      "Expected the \(description) destination to be enabled."
    )
    activate(destination)

    let detail = app.staticTexts[detailIdentifier]
    XCTAssertTrue(detail.waitForExistence(timeout: 5))
    assertAccessibleText(detail, description: "\(description) heading")
  }

  @MainActor
  private func launchApp(additionalArguments: [String] = []) -> XCUIApplication {
#if os(iOS)
    XCUIDevice.shared.orientation = .portrait
#endif

    let app = XCUIApplication()
    terminateRetainedApplicationIfNeeded(app)
    app.launchArguments = [
      "-ApplePersistenceIgnoreState", "YES",
      "--ui-testing",
    ]
    app.launchArguments.append(contentsOf: additionalArguments)
    app.launch()

    let libraryReady = app.descendants(matching: .any)["recipe-library-ready"]
    ensurePrimaryWindow(in: app, exposing: libraryReady)
    revealSidebar(in: app, exposing: libraryReady)
    XCTAssertTrue(libraryReady.waitForExistence(timeout: 5))
    return app
  }

  @MainActor
  private func terminateRetainedApplicationIfNeeded(_ app: XCUIApplication) {
#if os(macOS)
    guard app.state != .notRunning else { return }
    app.terminate()
    XCTAssertTrue(
      app.wait(for: .notRunning, timeout: 5),
      "The retained hosted-test application did not terminate before UI automation."
    )
#endif
  }

  @MainActor
  private func revealSidebar(in app: XCUIApplication, exposing element: XCUIElement) {
#if os(iOS)
    if !element.waitForExistence(timeout: 2) {
      let backButton = app.buttons["BackButton"]
      if backButton.waitForExistence(timeout: 3) {
        activate(backButton)
      }
    }
#else
    if !element.waitForExistence(timeout: 2) {
      let toggle = app.buttons["toggle-sidebar"]
      if toggle.waitForExistence(timeout: 3) {
        activate(toggle)
      }
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

  @MainActor
  private func ensurePrimaryWindow(in app: XCUIApplication, exposing element: XCUIElement) {
#if os(macOS)
    if !element.waitForExistence(timeout: 2) {
      app.activate()
      app.typeKey("n", modifierFlags: .command)
    }
#endif
  }

  @MainActor
  private func openSettings(in app: XCUIApplication) {
#if os(macOS)
    app.typeKey(",", modifierFlags: .command)
#else
    let openSettings = app.buttons["open-settings"]
    XCTAssertTrue(openSettings.waitForExistence(timeout: 2))
    assertAccessibleLabel(openSettings, description: "Settings action")
    activate(openSettings)
#endif
  }

  @MainActor
  private func assertAccessibleLabel(_ element: XCUIElement, description: String) {
    let label = element.label.trimmingCharacters(in: .whitespacesAndNewlines)
    XCTAssertFalse(
      label.isEmpty,
      "Expected the \(description) to expose a meaningful accessibility label."
    )
  }

  @MainActor
  private func assertAccessibleText(_ element: XCUIElement, description: String) {
    let label = element.label.trimmingCharacters(in: .whitespacesAndNewlines)
    let value = (element.value as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    XCTAssertFalse(
      label.isEmpty && value.isEmpty,
      "Expected the \(description) to expose meaningful accessible text."
    )
  }
}
