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
    let app = launchApp()

    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    XCTAssertTrue(recipeRow.waitForExistence(timeout: 5))
    XCTAssertTrue(recipeRow.label.contains("Tuna Noodle Hotdish"))
    let detail = openRecipeDetail(in: app, from: recipeRow)

    let title = app.descendants(matching: .any)["recipe-title"]
    XCTAssertTrue(title.waitForExistence(timeout: 2))
    XCTAssertTrue(textElement(in: app, equalTo: "Tuna Noodle Hotdish").waitForExistence(timeout: 2))

    let summary = app.descendants(matching: .any)["recipe-summary"]
    XCTAssertTrue(summary.waitForExistence(timeout: 2))
    let summaryText = textElement(
      in: app,
      containing: "Midwestern tuna noodle hotdish"
    )
    XCTAssertTrue(summaryText.waitForExistence(timeout: 2))

    let author = app.descendants(matching: .any)["recipe-author"]
    XCTAssertTrue(author.waitForExistence(timeout: 2))
    XCTAssertTrue(
      textElement(in: app, equalTo: "By Kitchen Memory contributors")
        .waitForExistence(timeout: 2)
    )

    let ingredients = app.descendants(matching: .any)["ingredients-section"]
    XCTAssertTrue(scroll(detail, untilVisible: ingredients))

    let ingredientSubsection = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "ingredient-subsection-"))
      .firstMatch
    XCTAssertTrue(scroll(detail, untilVisible: ingredientSubsection))
    XCTAssertTrue(scroll(detail, untilVisible: textElement(in: app, equalTo: "Hotdish")))

    let instructions = app.descendants(matching: .any)["instructions-section"]
    XCTAssertTrue(scroll(detail, untilVisible: instructions))

    let instructionSubsection = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "instruction-subsection-"))
      .firstMatch
    XCTAssertTrue(scroll(detail, untilVisible: instructionSubsection))
    XCTAssertTrue(scroll(detail, untilVisible: textElement(in: app, equalTo: "Noodles")))

    let timedInstruction = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS[c] %@", "Duration 6 min"))
      .firstMatch
    XCTAssertTrue(scroll(detail, untilVisible: timedInstruction))
  }

  @MainActor
  func testRecipeLibraryPassesAccessibilityAudit() throws {
    let device = XCUIDevice.shared
    let originalAppearance = device.appearance
    device.appearance = .light
    defer { device.appearance = originalAppearance }

    try auditRecipeLibrary(using: launchApp())
  }

  @MainActor
  func testRecipeLibraryPassesAccessibilityAuditInDarkMode() throws {
    let device = XCUIDevice.shared
    let originalAppearance = device.appearance
    device.appearance = .dark
    defer { device.appearance = originalAppearance }

    try auditRecipeLibrary(using: launchApp())
  }

  @MainActor
  private func launchApp() -> XCUIApplication {
#if os(iOS)
    XCUIDevice.shared.orientation = .portrait
#endif

    let app = XCUIApplication()
    app.launchArguments.append("--ui-testing")
    app.launch()

    let recipeLibrary = app.descendants(matching: .any)["recipe-library"]
    if !recipeLibrary.waitForExistence(timeout: 2) {
      let backToRecipes = app.buttons["Recipes"].firstMatch
      if backToRecipes.waitForExistence(timeout: 3) {
        activate(backToRecipes)
      }
    }
    XCTAssertTrue(recipeLibrary.waitForExistence(timeout: 5))

    return app
  }

  @MainActor
  private func auditRecipeLibrary(using app: XCUIApplication) throws {
    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    XCTAssertTrue(recipeRow.waitForExistence(timeout: 5))
    try performAccessibilityAudit(on: app)

    let detail = openRecipeDetail(in: app, from: recipeRow)
    try performAccessibilityAudit(on: app)

    let instructions = app.descendants(matching: .any)["instructions-section"]
    XCTAssertTrue(scroll(detail, untilVisible: instructions))
    try performAccessibilityAudit(on: app)
  }

  @MainActor
  private func performAccessibilityAudit(on app: XCUIApplication) throws {
    try app.performAccessibilityAudit(isKnownAccessibilityAuditFalsePositive)
  }

  @MainActor
  private func isKnownAccessibilityAuditFalsePositive(
    _ issue: XCUIAccessibilityAuditIssue
  ) -> Bool {
#if os(iOS)
    // The metadata label combines an SF Symbol and native Text into one
    // VoiceOver phrase. Xcode 26's audit then reports the inner label and
    // value Text nodes as unable to resize because the combined accessibility
    // node does not expose their font relationship. Both Text views use
    // SwiftUI's unmodified Dynamic Type behavior, and the grid separately
    // adapts to accessibility sizes to prevent real clipping.
    //
    // Accept only that audit type and our two metadata identifier families.
    // Contrast, clipping, hit-region, description, trait, and Dynamic Type
    // findings for every other element must still fail the test.
    let identifier = issue.element?.identifier ?? ""
    return issue.auditType == .dynamicType
      && (
        identifier.hasPrefix("recipe-metadata-label-")
          || identifier.hasPrefix("recipe-metadata-value-")
      )
#else
    guard let element = issue.element else { return false }

    if issue.auditType == .sufficientElementDescription,
      element.elementType == .group,
      element.label.isEmpty,
      !element.isHittable
    {
      // On macOS, SwiftUI exposes non-interactive layout groups to XCTest and
      // keeps their native Text nodes separate in the query tree. Xcode 26
      // then audits those structural groups as if each needed its own spoken
      // label. Accept only an empty-labeled, non-hittable Group. A nonmatching
      // sufficient-description finding falls through to the exact recipe-row
      // exception below instead of being rejected prematurely.
      return true
    }

    // A SwiftUI NavigationLink in the macOS sidebar is exposed to XCTest as a
    // labeled, hittable Button. Xcode 26 nevertheless reports “Unknown role”
    // from a macOS-only audit category. Accept only that exact finding for our
    // recipe-row identifier family; other controls, roles, descriptions, and
    // audit categories remain fatal.
    return issue.compactDescription == "Unknown role"
      && element.elementType == .button
      && element.isHittable
      && !element.label.isEmpty
      && element.identifier.hasPrefix("recipe-row-")
#endif
  }

  @MainActor
  private func openRecipeDetail(
    in app: XCUIApplication,
    from recipeRow: XCUIElement
  ) -> XCUIElement {
    let detail = app.descendants(matching: .any)["recipe-detail"]
    activate(recipeRow)
    if detail.waitForExistence(timeout: 5) { return detail }

#if os(iOS)
    // Hosted iOS occasionally acknowledges the first NavigationLink tap
    // without completing the transition, especially immediately after an
    // appearance change. Re-resolve the row and retry exactly once so a
    // transient activation cannot masquerade as an accessibility failure.
    let refreshedRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    if refreshedRow.waitForExistence(timeout: 2) {
      activate(refreshedRow)
      if detail.waitForExistence(timeout: 5) { return detail }
    }
#endif

    XCTFail("The starter recipe detail did not open")
    return detail
  }

  @MainActor
  private func textElement(
    in app: XCUIApplication,
    equalTo label: String
  ) -> XCUIElement {
    app.staticTexts
      .matching(NSPredicate(format: "label == %@ OR value == %@", label, label))
      .firstMatch
  }

  @MainActor
  private func textElement(
    in app: XCUIApplication,
    containing label: String
  ) -> XCUIElement {
    app.staticTexts
      .matching(
        NSPredicate(
          format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@",
          label,
          label
        )
      )
      .firstMatch
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

  @MainActor
  private func activate(_ element: XCUIElement) {
#if os(macOS)
    element.click()
#else
    element.tap()
#endif
  }
}
