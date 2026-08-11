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
    activate(recipeRow)

    let detail = app.descendants(matching: .any)["recipe-detail"]
    XCTAssertTrue(detail.waitForExistence(timeout: 5))

    let title = app.descendants(matching: .any)["recipe-title"]
    XCTAssertTrue(title.waitForExistence(timeout: 2))
    XCTAssertEqual(semanticLabel(of: title), "Tuna Noodle Hotdish")

    let summary = app.descendants(matching: .any)["recipe-summary"]
    XCTAssertTrue(summary.waitForExistence(timeout: 2))
    XCTAssertTrue(semanticLabel(of: summary).contains("Midwestern tuna noodle hotdish"))

    let author = app.descendants(matching: .any)["recipe-author"]
    XCTAssertTrue(author.waitForExistence(timeout: 2))
    XCTAssertEqual(semanticLabel(of: author), "By Kitchen Memory contributors")

    let ingredients = app.descendants(matching: .any)["ingredients-section"]
    XCTAssertTrue(scroll(detail, untilVisible: ingredients))

    let ingredientSubsection = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "ingredient-subsection-"))
      .firstMatch
    XCTAssertTrue(scroll(detail, untilVisible: ingredientSubsection))
    XCTAssertEqual(semanticLabel(of: ingredientSubsection), "Hotdish")

    let instructions = app.descendants(matching: .any)["instructions-section"]
    XCTAssertTrue(scroll(detail, untilVisible: instructions))

    let instructionSubsection = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "instruction-subsection-"))
      .firstMatch
    XCTAssertTrue(scroll(detail, untilVisible: instructionSubsection))
    XCTAssertEqual(semanticLabel(of: instructionSubsection), "Noodles")

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

    activate(recipeRow)
    let detail = app.descendants(matching: .any)["recipe-detail"]
    XCTAssertTrue(detail.waitForExistence(timeout: 5))
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
    guard issue.auditType == .sufficientElementDescription,
      let element = issue.element,
      element.elementType == .group,
      element.label.isEmpty,
      isKnownIdentifierWrapper(element.identifier)
    else {
      return false
    }

    // On macOS, SwiftUI sometimes exposes an accessibility identifier on a
    // transparent Group while leaving the native Text and its spoken label on
    // a descendant. XCTest audits that automation-only wrapper as though it
    // were an unlabeled user-facing element. Accept the finding only for our
    // known identifier families and only when the wrapper actually contains a
    // labeled descendant. A genuinely unlabeled control therefore still
    // fails the audit.
    return firstLabeledDescendant(of: element).exists
#endif
  }

  @MainActor
  private func semanticLabel(of element: XCUIElement) -> String {
    if !element.label.isEmpty { return element.label }

#if os(macOS)
    // The macOS SwiftUI accessibility tree can put our stable identifier on a
    // transparent Group and the native Text label on its child. Read through
    // that wrapper without changing the app's native accessibility roles.
    let descendant = firstLabeledDescendant(of: element)
    if descendant.exists { return descendant.label }
#endif

    return element.label
  }

#if os(macOS)
  @MainActor
  private func firstLabeledDescendant(of element: XCUIElement) -> XCUIElement {
    element.descendants(matching: .any)
      .matching(NSPredicate(format: "label != %@", ""))
      .firstMatch
  }

  private func isKnownIdentifierWrapper(_ identifier: String) -> Bool {
    let exactIdentifiers = [
      "recipe-library",
      "recipe-detail",
      "recipe-title",
      "recipe-summary",
      "recipe-author",
      "equipment-section",
      "ingredients-section",
      "instructions-section",
    ]
    let identifierPrefixes = [
      "ingredient-subsection-",
      "instruction-subsection-",
      "recipe-metadata-label-",
      "recipe-metadata-value-",
    ]

    return exactIdentifiers.contains(identifier)
      || identifierPrefixes.contains { identifier.hasPrefix($0) }
  }
#endif

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
