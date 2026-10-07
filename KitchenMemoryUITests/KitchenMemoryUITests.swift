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
    revealSidebar(in: app, exposing: shell)
    XCTAssertTrue(shell.waitForExistence(timeout: 5))
    assertAccessibleName(shell, description: "recipe library")

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
    // A clean Kitchen has no recovery evidence requiring a destination.
    XCTAssertFalse(app.buttons["recovery-destination"].exists)

    let allRecipes = app.buttons["all-recipes-destination"]
    revealSidebar(in: app, exposing: allRecipes)
    XCTAssertTrue(allRecipes.waitForExistence(timeout: 5))
    assertAccessibleName(allRecipes, description: "All Recipes")
    activate(allRecipes)

    let recipeRow = app.buttons
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    revealSidebar(in: app, exposing: recipeRow)
    XCTAssertTrue(recipeRow.waitForExistence(timeout: 5))
    assertAccessibleName(recipeRow, description: "recipe")
    activate(recipeRow)

    let recipeDetail = app.descendants(matching: .any)["recipe-detail"]
    XCTAssertTrue(recipeDetail.waitForExistence(timeout: 5))
    assertAccessibleName(recipeDetail, description: "recipe detail")
    app.terminate()
  }

  @MainActor
  func testCookingReadingDestinationExposesNamedStructure() {
    let app = launchApp()
    // The sample fixture starts with Dirty Fried Rice selected; opening the
    // named second recipe explicitly reveals the compact detail column.
    let row = app.buttons["recipe-row-E3D10000-0000-4000-8000-000000000001"]
    revealSidebar(in: app, exposing: row)
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    activate(row)
    XCTAssertTrue(app.descendants(matching: .any)["recipe-detail"].waitForExistence(timeout: 5))
    var start = app.buttons["start-cooking"]
    if !start.waitForExistence(timeout: 2) {
      let overflow = app.buttons["OverflowBarButtonItem"]
      if overflow.exists {
        activate(overflow)
        // The system overflow menu retains the accessible name, not the toolbar identifier.
        start = app.buttons["Start Cooking"]
      }
    }
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    activate(start)
    let reading = app.descendants(matching: .any)["cooking-session-shell"]
    XCTAssertTrue(reading.waitForExistence(timeout: 5))
    assertAccessibleText(reading, description: "Cooking Session reading")
    for identifier in ["session-reading-jump", "session-reading-keep-awake", "session-lifecycle-menu", "leave-session"] {
      let control = app.descendants(matching: .any)[identifier].firstMatch
      XCTAssertTrue(control.waitForExistence(timeout: 5))
      assertAccessibleName(control, description: identifier)
    }
    app.terminate()
  }

  @MainActor
  func testRecipeEditorExposesNamedEntryAndModeControls() {
    let app = launchApp()
    let create = app.buttons["new-recipe"].firstMatch
    revealSidebar(in: app, exposing: create)
    XCTAssertTrue(create.waitForExistence(timeout: 5))
    assertAccessibleName(create, description: "New Recipe")
    activate(create)
    let title = app.textFields["recipe-editor-title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    assertAccessibleName(title, description: "Recipe title")
    let ingredients = app.textViews["simple-ingredient-text"]
    XCTAssertTrue(ingredients.waitForExistence(timeout: 5))
    assertAccessibleName(ingredients, description: "Ingredients")
    let mode = app.buttons["recipe-editor-mode"]
    XCTAssertTrue(mode.waitForExistence(timeout: 5))
    assertAccessibleName(mode, description: "Editor mode")
    activate(mode)
    let summary = app.textFields["recipe-editor-summary"]
    XCTAssertTrue(summary.waitForExistence(timeout: 5))
    assertAccessibleName(summary, description: "Recipe summary")
    app.terminate()
  }

  @MainActor
  func testOrganizationDestinationExposesAccessibleManagement() {
    let app = launchApp()
    let destination = app.buttons["organization-management"].firstMatch
    revealSidebar(in: app, exposing: destination)
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    assertAccessibleName(destination, description: "organization management")
    activate(destination)
    let content = app.descendants(matching: .any)["organization-management-content"]
    XCTAssertTrue(content.waitForExistence(timeout: 5))
    assertAccessibleName(content, description: "organization management content")
    app.terminate()
  }

  @MainActor
  func testAttentionEvidenceExposesAccessibleRecoveryNavigation() {
    let app = launchApp(additionalArguments: ["--ui-testing-recovery-fixture"])
    visitTopLevelDestination(
      "recovery-destination", revealing: "session-recovery",
      description: "Recovery", in: app
    )
    app.terminate()
  }

  @MainActor
  func testSettingsExposeAccessibleTopLevelStructure() {
    let app = launchApp(additionalArguments: ["--ui-testing-cloud-sync-disabled"])
    openSettings(in: app)

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
    assertAccessibleName(retry, description: "startup recovery action")
    app.terminate()
  }

  @MainActor
  func testLocalizedShellSurvivesDoubledTextAndRightToLeftDirection() {
    for language in ["en-US", "en-GB", "es-MX", "fr-CA", "de-DE", "it-IT"] {
      let app = launchApp(additionalArguments: [
        "-AppleLanguages", "(\(language))", "-AppleLocale", language,
        "-NSDoubleLocalizedStrings", "YES",
        "-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES",
      ], readyIdentifier: "sessions-destination")
      let sessions = app.buttons["sessions-destination"]
      assertAccessibleName(sessions, description: "localized Sessions destination")
      openSettings(in: app)
      app.terminate()
    }
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
    assertAccessibleName(destination, description: "\(description) destination")
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
  private func launchApp(
    additionalArguments: [String] = [], readyIdentifier: String = "recipe-library-ready"
  ) -> XCUIApplication {
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

    let libraryReady = app.descendants(matching: .any)[readyIdentifier]
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

  @MainActor
  private func ensurePrimaryWindow(in app: XCUIApplication, exposing element: XCUIElement) {
#if os(macOS)
    if !element.waitForExistence(timeout: 2) {
      app.activate()
      app.typeKey("n", modifierFlags: [.command, .shift])
    }
#endif
  }

  @MainActor
  private func assertAccessibleName(_ element: XCUIElement, description: String) {
    let label = element.label.trimmingCharacters(in: .whitespacesAndNewlines)
    let title = element.title.trimmingCharacters(in: .whitespacesAndNewlines)
    XCTAssertFalse(
      label.isEmpty && title.isEmpty,
      "Expected the \(description) to expose a meaningful accessibility name."
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

extension KitchenMemoryUITests {
  @MainActor
  private func openSettings(in app: XCUIApplication) {
#if os(macOS)
    app.typeKey(",", modifierFlags: .command)
#else
    let openSettings = app.buttons["open-settings"]
    XCTAssertTrue(openSettings.waitForExistence(timeout: 2))
    assertAccessibleName(openSettings, description: "Settings action")
    activate(openSettings)
#endif
    let form = app.descendants(matching: .any)["settings-form"].firstMatch
    XCTAssertTrue(form.waitForExistence(timeout: 5))
    assertAccessibleName(form, description: "Settings landmark")
#if os(iOS)
    let done = app.buttons["dismiss-settings"]
    XCTAssertTrue(done.waitForExistence(timeout: 5))
    assertAccessibleName(done, description: "Settings dismissal action")
    XCTAssertTrue(done.isEnabled)
#endif
  }
}

#if os(iOS)
extension KitchenMemoryUITests {
  @MainActor
  func testRightToLeftNavigationExposesNamedDestinations() {
    let app = launchApp(additionalArguments: [
      "-AppleLanguages", "(en-US)", "-AppleLocale", "en_US",
      "-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES",
    ])
    defer { app.terminate() }
    let allRecipes = app.buttons["all-recipes-destination"]
    revealSidebar(in: app, exposing: allRecipes)
    XCTAssertTrue(
      allRecipes.waitForExistence(timeout: 5), "RTL navigation must expose Organization destinations"
    )
    assertAccessibleName(allRecipes, description: "All Recipes in right-to-left navigation")
  }
}
#endif

#if os(macOS)
extension KitchenMemoryUITests {
  @MainActor
  func testSidebarControlsExposeNamedDestinations() {
    let app = launchApp(additionalArguments: ["-AppleLanguages", "(en-US)", "-AppleLocale", "en_US"])
    defer { app.terminate() }
    let hide = app.buttons["Hide Sidebar"]
    XCTAssertTrue(hide.waitForExistence(timeout: 5))
    assertAccessibleName(hide, description: "Hide Sidebar")
    XCTAssertTrue(hide.isEnabled)
    activate(hide)
    let show = app.buttons["Show Sidebar"]
    XCTAssertTrue(show.waitForExistence(timeout: 5))
    assertAccessibleName(show, description: "Show Sidebar")
    XCTAssertTrue(show.isEnabled)
    activate(show)
    XCTAssertTrue(hide.waitForExistence(timeout: 5))
    for identifier in ["all-recipes-destination", "sessions-destination", "deleted-items-destination"] {
      let destination = app.buttons[identifier]
      XCTAssertTrue(destination.waitForExistence(timeout: 5))
      assertAccessibleName(destination, description: identifier)
      XCTAssertTrue(destination.isEnabled)
    }
  }
}
#endif
