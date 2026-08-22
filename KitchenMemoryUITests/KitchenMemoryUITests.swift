// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import XCTest

// The UI suite keeps its shared navigation and accessibility helpers beside
// the end-to-end scenarios they support.
// swiftlint:disable file_length type_body_length

final class KitchenMemoryUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testStarterRecipeCanBeRead() throws {
    // This is a semantic reading-order smoke test, not a pixel/layout test. It
    // walks the same landmarks a screen-reader user needs: library row, recipe
    // identity, metadata, ingredient hierarchy, and ordered instructions.
    let app = launchApp()

    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .matching(NSPredicate(format: "label CONTAINS[c] %@", "Tuna Noodle Hotdish"))
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

    let recipeYield = app.descendants(matching: .any)["recipe-metadata-yield"]
    XCTAssertTrue(scroll(detail, untilVisible: recipeYield))
    // accessibilityRepresentation is exposed as `label` on iOS and commonly
    // as `value` on macOS. Both represent the same spoken phrase, so normalize
    // that platform difference before asserting the user-facing contract.
    let spokenYield = recipeYield.label.isEmpty
      ? recipeYield.value as? String
      : recipeYield.label
    XCTAssertEqual(spokenYield, "Yield, Serves 8 generously")

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
  func testStarterRecipeCanBeScaledForReading() throws {
    let app = launchApp()
    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS[c] %@", "Tuna Noodle Hotdish"))
      .firstMatch
    XCTAssertTrue(recipeRow.waitForExistence(timeout: 5))
    let detail = openRecipeDetail(in: app, from: recipeRow)

    let scalingSection = app.descendants(matching: .any)["recipe-scaling-section"]
    XCTAssertTrue(scroll(detail, untilVisible: scalingSection))
    let workingYield = app.descendants(matching: .any)["recipe-working-yield"]
    XCTAssertTrue(scroll(detail, untilVisible: workingYield))
    let decrement = app.buttons["recipe-working-yield-decrement"]
    XCTAssertTrue(decrement.waitForExistence(timeout: 2))
    activate(decrement)
    XCTAssertTrue(
      NSPredicate(format: "value CONTAINS[c] %@", "7 servings")
        .evaluate(with: workingYield)
    )

    let scaledTuna = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS[c] %@", "3 1/2 (5-ounce) cans"))
      .firstMatch
    XCTAssertTrue(scroll(detail, untilVisible: scaledTuna))

    let equipmentHelp = app.descendants(matching: .any)["equipment-scaling-help"]
    XCTAssertTrue(scroll(detail, untilVisible: equipmentHelp))
    let equipmentHelpText = [equipmentHelp.label, equipmentHelp.value as? String]
      .compactMap { $0 }
      .joined(separator: " ")
    XCTAssertTrue(equipmentHelpText.contains("does not scale automatically"))

    let manualReview = app.descendants(matching: .any)
      .matching(NSPredicate(
        format: "label CONTAINS[c] %@",
        "Check this amount manually"
      ))
      .firstMatch
    XCTAssertTrue(scroll(detail, untilVisible: manualReview))
  }

  @MainActor
  func testTextOnlyYieldCanBeMadeScalableAndRefreshesAfterSave() throws {
    let app = launchApp()
    let dirtyFriedRice = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS[c] %@", "Dirty Fried Rice"))
      .firstMatch
    XCTAssertTrue(dirtyFriedRice.waitForExistence(timeout: 5))
    let detail = openRecipeDetail(in: app, from: dirtyFriedRice)

    let edit = app.buttons["edit-recipe"]
    XCTAssertTrue(edit.waitForExistence(timeout: 2))
    activate(edit)

    let editor = app.descendants(matching: .any)["recipe-editor-scroll"]
    let scalingToggle = app.descendants(matching: .any)["recipe-editor-yield-scaling"]
    XCTAssertTrue(scroll(editor, untilVisible: scalingToggle))

    #if os(iOS)
    let switchControl = scalingToggle.descendants(matching: .switch).firstMatch
    XCTAssertTrue(switchControl.waitForExistence(timeout: 2))
    activate(switchControl)
    XCTAssertEqual(switchControl.value as? String, "1")
    #else
    activate(scalingToggle)
    #endif

    let increment = app.buttons["recipe-editor-yield-quantity-lower-increment"]
    XCTAssertTrue(scroll(editor, untilHittable: increment))
    let numerator = app.textFields["recipe-editor-yield-quantity-lower-numerator"]
    XCTAssertTrue(numerator.waitForExistence(timeout: 2))
    for _ in 1..<8 { activate(increment) }
    XCTAssertEqual(numerator.value as? String, "8")

    let save = app.buttons["recipe-editor-save"]
    XCTAssertTrue(save.waitForExistence(timeout: 2))
    activate(save)
    XCTAssertTrue(save.waitForNonExistence(timeout: 5))

    let workingYield = app.descendants(matching: .any)["recipe-working-yield"]
    XCTAssertTrue(scroll(detail, untilVisible: workingYield))
    XCTAssertTrue(
      NSPredicate(format: "value CONTAINS[c] %@", "8")
        .evaluate(with: workingYield)
    )

    let decrement = app.buttons["recipe-working-yield-decrement"]
    XCTAssertTrue(decrement.waitForExistence(timeout: 2))
    activate(decrement)
    XCTAssertTrue(
      NSPredicate(format: "value CONTAINS[c] %@", "7")
        .evaluate(with: workingYield)
    )

    let scaledEggs = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS[c] %@", "2 5/8 large eggs"))
      .firstMatch
    XCTAssertTrue(scroll(detail, untilVisible: scaledEggs))
  }

  @MainActor
  func testCanCreateARecipeFromTheEditor() throws {
    let app = launchApp()
    let newRecipe = app.buttons["new-recipe"]
    XCTAssertTrue(newRecipe.waitForExistence(timeout: 2))
    activate(newRecipe)

    let title = app.descendants(matching: .any)["recipe-editor-title"]
    XCTAssertTrue(title.waitForExistence(timeout: 2))
    activate(title)
    title.typeText("Sunday Tomato Soup")

    let save = app.buttons["recipe-editor-save"]
    XCTAssertTrue(save.waitForExistence(timeout: 2))
    activate(save)

    XCTAssertTrue(textElement(in: app, equalTo: "Sunday Tomato Soup").waitForExistence(timeout: 5))
  }

  @MainActor
  func testSettingsResetRequiresExplicitDestructiveConfirmation() throws {
    let app = launchApp()
#if os(macOS)
    app.typeKey(",", modifierFlags: .command)
#else
    let openSettings = app.buttons["open-settings"]
    XCTAssertTrue(openSettings.waitForExistence(timeout: 2))
    activate(openSettings)
#endif

    let reset = app.buttons["settings-reset-kitchen"]
    XCTAssertTrue(reset.waitForExistence(timeout: 5))
    activate(reset)
    assertResetWarning(in: app)
  }

#if os(macOS)
  @MainActor
  func testKitchenMenuResetRequiresExplicitDestructiveConfirmation() throws {
    let app = launchApp()
    let kitchenMenu = app.menuBars.menuBarItems["Kitchen"]
    XCTAssertTrue(kitchenMenu.waitForExistence(timeout: 2))
    activate(kitchenMenu)

    let reset = app.menuItems["Reset Kitchen…"]
    XCTAssertTrue(reset.waitForExistence(timeout: 2))
    activate(reset)
    assertResetWarning(in: app)
  }
#endif

  @MainActor
  func testRecipeEditorCanScrollToItsLastSection() throws {
    let app = launchApp()
    let newRecipe = app.buttons["new-recipe"]
    XCTAssertTrue(newRecipe.waitForExistence(timeout: 2))
    activate(newRecipe)

    let editor = app.descendants(matching: .any)["recipe-editor-scroll"]
    XCTAssertTrue(editor.waitForExistence(timeout: 2))
    let addInstructionSection = app.descendants(matching: .any)["add-instruction-section"]
    XCTAssertTrue(scroll(editor, untilVisible: addInstructionSection))
  }

  @MainActor
  func testRecipeEditorKeepsIngredientAndInstructionSectionsDistinct() throws {
    let app = launchApp()
    let recipeRow = app.descendants(matching: .any)
      .matching(
        NSPredicate(
          format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@",
          "recipe-row-",
          "Tuna Noodle Hotdish"
        )
      )
      .firstMatch
    let detail = openRecipeDetail(in: app, from: recipeRow)
    let edit = app.buttons["edit-recipe"]
    XCTAssertTrue(edit.waitForExistence(timeout: 2))
    activate(edit)

    let editor = app.descendants(matching: .any)["recipe-editor-scroll"]
    let ingredientSection = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "ingredient-editor-section-"))
      .firstMatch
    XCTAssertTrue(scroll(editor, untilHittable: ingredientSection))
    activate(ingredientSection)

    let addIngredient = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "add-ingredient-"))
      .firstMatch
    XCTAssertTrue(addIngredient.waitForExistence(timeout: 2))

    let ingredient = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "ingredient-editor-row-"))
      .firstMatch
    XCTAssertTrue(ingredient.waitForExistence(timeout: 2))
    XCTAssertTrue(ingredient.label.contains("4 (5-ounce) cans chunk light tuna"))

    let instructionSection = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "instruction-editor-section-"))
      .firstMatch
    XCTAssertTrue(scroll(editor, untilHittable: instructionSection))
    XCTAssertEqual(instructionSection.value as? String, "Collapsed")
    _ = detail
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
    // The app uses this argument to select deterministic, disposable sample
    // data. UI tests must never depend on or modify a developer's local store.
    app.launchArguments.append("--ui-testing")
    app.launch()

    let recipeLibrary = app.descendants(matching: .any)["recipe-library"]
    if !recipeLibrary.waitForExistence(timeout: 2) {
      // macOS can restore the previous NavigationSplitView selection between
      // launches. Return to the library when that system restoration wins the
      // race, then require our normal launch landmark below.
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
    // Audit three meaningful states rather than only the launch viewport:
    // library, recipe header/metadata, and the scrolled instruction region.
    // ScrollView laziness means the last state can contain a different set of
    // realized accessibility elements from the top of the recipe.
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
    // Xcode 26 samples wholly offscreen ScrollView text against unrelated
    // onscreen pixels on macOS, producing repeatable false contrast failures.
    // Kitchen Memory uses semantic text colors and defined light/dark color
    // assets; keep every structural audit while testing contrast separately.
    let auditTypes = XCUIAccessibilityAuditType.all.subtracting(.contrast)
#if os(macOS)
    let fullScreenButton = app.buttons["_XCUI:FullScreenWindow"]
    let systemFullScreenButtonFrame = fullScreenButton.exists
      ? fullScreenButton.frame
      : CGRect.null
#else
    let systemFullScreenButtonFrame = CGRect.null
#endif
    try app.performAccessibilityAudit(for: auditTypes) { issue in
      self.isKnownAccessibilityAuditFalsePositive(
        issue,
        systemFullScreenButtonFrame: systemFullScreenButtonFrame
      )
    }
  }

  @MainActor
  // The platform-specific audit workarounds are kept together so removing one
  // when Xcode is fixed remains straightforward.
  // swiftlint:disable:next function_body_length
  private func isKnownAccessibilityAuditFalsePositive(
    _ issue: XCUIAccessibilityAuditIssue,
    systemFullScreenButtonFrame: CGRect
  ) -> Bool {
#if os(iOS)
    guard issue.auditType == .dynamicType, let element = issue.element else {
      return false
    }

    // The metadata card uses native Dynamic Type Text views and switches to a
    // single-column grid at accessibility sizes. Xcode 26 cannot trace those
    // fonts through accessibilityRepresentation and may report either the
    // identified Text or its same-sized, system-created wrapper.
    if element.identifier.hasPrefix("recipe-metadata-") {
      return true
    }

    let metadataDescendants = element.descendants(matching: .staticText)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-metadata-"))
    if element.identifier.isEmpty,
      metadataDescendants.count == 1,
      metadataDescendants.firstMatch.frame == element.frame {
      return true
    }
    return false
#else
    guard let element = issue.element else { return false }

    if issue.auditType == .sufficientElementDescription,
      element.elementType == .touchBar,
      element.identifier.isEmpty,
      element.label.isEmpty {
      // Xcode 26 injects an empty, system-owned TouchBar element into the
      // macOS application hierarchy and screenshots the menu bar when it
      // reports the issue. Kitchen Memory does not create Touch Bar content;
      // accept only that unlabeled, unidentified system element.
      return true
    }

    if issue.auditType == .parentChild,
      element.elementType == .group,
      element.identifier.isEmpty,
      element.label.isEmpty,
      systemFullScreenButtonFrame.contains(element.frame) {
      // Xcode 26 audits the private Group inside AppKit's green full-screen
      // traffic-light button and reports its system-owned parent relationship
      // as invalid. Accept only an unlabeled Group physically contained by
      // the explicitly identified _XCUI:FullScreenWindow system control.
      return true
    }

    if element.elementType == .other,
      element.identifier.isEmpty,
      element.label.isEmpty {
      let metadataDescendants = element.descendants(matching: .any)
        .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-metadata-"))

      if metadataDescendants.count == 1 {
        let metadataElement = metadataDescendants.firstMatch
        let metadataValue = metadataElement.value as? String ?? ""
        let isMetadataGridCellWrapper = metadataElement.exists
          && (!metadataElement.label.isEmpty || !metadataValue.isEmpty)
          && metadataElement.frame == element.frame

        if isMetadataGridCellWrapper,
          issue.auditType == .sufficientElementDescription
            || issue.compactDescription == "Parent/Child mismatch" {
          // LazyVGrid creates an extra macOS accessibility element around each
          // cell. It has the same frame as its single, fully labeled child but
          // cannot inherit that child's description. Xcode 26 reports the wrapper
          // as either “Element has no description” or “Parent/Child mismatch,”
          // depending on the macOS runner. Accept only that exact wrapper around
          // one of our tested recipe-metadata elements.
          return true
        }
      }
    }

    if isKnownMacOSLayoutGroup(issue, element: element) {
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

#if os(macOS)
  @MainActor
  private func isKnownMacOSLayoutGroup(
    _ issue: XCUIAccessibilityAuditIssue,
    element: XCUIElement
  ) -> Bool {
    guard issue.auditType == .sufficientElementDescription,
      element.elementType == .group,
      element.identifier.isEmpty,
      element.label.isEmpty
    else { return false }

    if !element.isHittable {
      // SwiftUI exposes non-interactive layout groups separately from their
      // native Text children, then Xcode 26 audits each structural wrapper as
      // if it needed its own spoken label.
      return true
    }

    let libraryDescendants = element.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier == %@", "recipe-library"))
    guard libraryDescendants.count == 1 else { return false }

    let library = libraryDescendants.firstMatch
    guard library.exists, library.label == "Recipe library" else { return false }

    let wrapperFrame = element.frame
    let libraryFrame = library.frame
    let tolerance: CGFloat = 2
    let isSystemSidebarWrapper = [
      abs(wrapperFrame.minX - libraryFrame.minX) <= tolerance,
      abs(wrapperFrame.width - libraryFrame.width) <= tolerance,
      wrapperFrame.minY <= libraryFrame.minY + tolerance,
      wrapperFrame.maxY + tolerance >= libraryFrame.maxY,
    ].allSatisfy { $0 }

    // macOS 26.6 exposes the private NavigationSplitView sidebar wrapper as
    // an empty, hittable Group even though its only content region is our
    // labeled recipe-library outline. Accept only that width-aligned system
    // wrapper around exactly one known, fully described outline.
    return isSystemSidebarWrapper
  }
#endif

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
    // Native SwiftUI Text appears as a label on iOS but may be surfaced as a
    // value by the macOS XCTest bridge. Query both without weakening equality.
    app.staticTexts
      .matching(NSPredicate(format: "label == %@ OR value == %@", label, label))
      .firstMatch
  }

  @MainActor
  private func textElement(
    in app: XCUIApplication,
    containing label: String
  ) -> XCUIElement {
    // Keep partial-text matching in one helper so cross-platform label/value
    // handling is identical to the exact-text query above.
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
  private func assertResetWarning(in app: XCUIApplication) {
#if os(macOS)
    // SwiftUI presents alerts as AppKit sheets. XCTest exposes the sheet's
    // generic accessibility label, while the visible title remains a child.
    let confirmation = app.sheets["alert"]
#else
    let confirmation = app.alerts["Reset Kitchen?"]
#endif
    XCTAssertTrue(confirmation.waitForExistence(timeout: 3))

    let title = confirmation.descendants(matching: .any)
      .matching(
        NSPredicate(
          format: "label == %@ OR value == %@",
          "Reset Kitchen?",
          "Reset Kitchen?"
        )
      )
      .firstMatch
    XCTAssertTrue(title.waitForExistence(timeout: 2))

    let warning = confirmation.descendants(matching: .any)
      .matching(
        NSPredicate(
          format: "label CONTAINS[c] %@ OR value CONTAINS[c] %@",
          "permanently deleted",
          "permanently deleted"
        )
      )
      .firstMatch
    XCTAssertTrue(warning.waitForExistence(timeout: 2))
    XCTAssertTrue(confirmation.buttons["Reset Kitchen"].exists)

    let cancel = confirmation.buttons["Cancel"]
    XCTAssertTrue(cancel.exists)
    activate(cancel)
    XCTAssertTrue(confirmation.waitForNonExistence(timeout: 2))
  }

  @MainActor
  private func scroll(
    _ container: XCUIElement,
    untilVisible element: XCUIElement,
    attempts: Int = 6
  ) -> Bool {
    // Waiting before every swipe handles elements that exist but are realized
    // asynchronously. The bounded loop prevents a missing landmark from
    // turning into an unbounded gesture sequence with an opaque timeout.
    if element.waitForExistence(timeout: 1) { return true }

    for _ in 0..<attempts {
      container.swipeUp()
      if element.waitForExistence(timeout: 1) { return true }
    }

    return false
  }

  @MainActor
  private func scroll(
    _ container: XCUIElement,
    untilHittable element: XCUIElement,
    attempts: Int = 6
  ) -> Bool {
    // AppKit can expose an offscreen disclosure control as existing. Require
    // it to be interactive before clicking so the test proves the section was
    // actually expanded instead of silently sending a click outside the view.
    if element.waitForExistence(timeout: 1), element.isHittable { return true }

    for _ in 0..<attempts {
#if os(macOS)
      // A fixed wheel delta avoids the momentum of swipeUp(), which can jump
      // past a nearby target in a macOS ScrollView.
      container.scroll(byDeltaX: 0, deltaY: -400)
#else
      container.swipeUp()
#endif
      if element.waitForExistence(timeout: 1), element.isHittable { return true }
    }

    return false
  }

  @MainActor
  private func activate(_ element: XCUIElement) {
    // XCTest models the same user action with different APIs on AppKit and
    // UIKit. Centralizing the distinction keeps navigation tests shared.
#if os(macOS)
    element.click()
#else
    element.tap()
#endif
  }
}

// swiftlint:enable file_length type_body_length
