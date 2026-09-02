// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import XCTest

extension KitchenMemoryUITests {
  @MainActor
  func testCookingSessionProgressAndScaleSmoke() {
    let app = launchApp(additionalArguments: ["-AppleLanguages", "(en-US)"])
    let progress = recordSessionProgress(in: app)

#if os(iOS)
    assertSessionSurvivesRotation(in: app)
#endif

    activate(app.buttons["leave-session"])
    reopenFirstSession(in: app)
    assertSessionProgress(progress, survivesIn: app)
  }

  @MainActor
  private func recordSessionProgress(in app: XCUIApplication) -> RecordedSessionProgress {
    let recipeRow = app.descendants(matching: .any)[
      "recipe-row-95781805-F5D3-46B0-B685-A660F8AC69F2"
    ]
    revealRecipeRow(recipeRow, in: app)
    XCTAssertTrue(
      recipeRow.waitForExistence(timeout: 5),
      "Expected the scalable sample recipe before starting a Cooking Session."
    )
    activate(recipeRow)
    let start = app.buttons["start-cooking"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    activate(start)

    let adjustedWorkingYield = adjustWorkingYield(in: app)

    let ingredient = firstSessionElement(in: app, identifierPrefix: "session-ingredient-")
    XCTAssertTrue(
      ingredient.waitForExistence(timeout: 5),
      "Expected a session ingredient before recording progress."
    )
    activate(ingredient)
    XCTAssertTrue(ingredient.isSelected, "Ingredient progress was not recorded.")

    let instruction = firstSessionElement(
      in: app,
      identifierPrefix: "session-instruction-step-"
    )
    XCTAssertTrue(
      instruction.waitForExistence(timeout: 5),
      "Expected a session instruction before recording progress."
    )
    activate(instruction)
    XCTAssertTrue(instruction.isSelected, "Instruction progress was not recorded.")

    return RecordedSessionProgress(
      ingredientIdentifier: ingredient.identifier,
      instructionIdentifier: instruction.identifier,
      adjustedWorkingYield: adjustedWorkingYield
    )
  }

  @MainActor
  private func adjustWorkingYield(in app: XCUIApplication) -> String? {
    let increase = app.buttons["session-working-yield-increment"]
    XCTAssertTrue(
      increase.waitForExistence(timeout: 5),
      "Expected the session working-yield control."
    )
    let workingYield = app.descendants(matching: .any)["session-working-yield"]
    XCTAssertTrue(
      workingYield.waitForExistence(timeout: 5),
      "Expected the current session working yield."
    )
    let originalWorkingYield = workingYield.value as? String
    activate(increase)
    let adjustedWorkingYield = workingYield.value as? String
    XCTAssertNotEqual(
      adjustedWorkingYield,
      originalWorkingYield,
      "Increasing the session working yield did not update its accessible value."
    )
    return adjustedWorkingYield
  }

  @MainActor
  private func revealRecipeRow(_ recipeRow: XCUIElement, in app: XCUIApplication) {
#if os(iOS)
    if !recipeRow.waitForExistence(timeout: 2) {
      app.descendants(matching: .any)["recipe-library-shell"].swipeUp()
    }
#endif
  }

  @MainActor
  private func assertSessionProgress(
    _ progress: RecordedSessionProgress,
    survivesIn app: XCUIApplication
  ) {
#if os(iOS)
    assertWorkingYield(progress.adjustedWorkingYield, survivesIn: app)
#endif

    let restoredIngredient = app.descendants(matching: .any)[progress.ingredientIdentifier]
    XCTAssertTrue(
      restoredIngredient.waitForExistence(timeout: 5),
      "The recorded ingredient was unavailable after reopening the session."
    )
    XCTAssertTrue(
      restoredIngredient.isSelected,
      "Ingredient progress did not survive reopening."
    )
    let restoredInstruction = app.descendants(matching: .any)[progress.instructionIdentifier]
    XCTAssertTrue(
      restoredInstruction.waitForExistence(timeout: 5),
      "The recorded instruction was unavailable after reopening the session."
    )
    XCTAssertTrue(
      restoredInstruction.isSelected,
      "Instruction progress did not survive reopening."
    )

#if os(macOS)
    assertWorkingYield(progress.adjustedWorkingYield, survivesIn: app)
#endif
  }

  @MainActor
  private func assertWorkingYield(
    _ expectedWorkingYield: String?,
    survivesIn app: XCUIApplication
  ) {
    let restoredWorkingYield = app.descendants(matching: .any)["session-working-yield"]
    XCTAssertTrue(
      restoredWorkingYield.waitForExistence(timeout: 5),
      "The working yield was unavailable after reopening the session."
    )
    XCTAssertEqual(
      restoredWorkingYield.value as? String,
      expectedWorkingYield,
      "The adjusted working yield did not survive reopening."
    )
  }

  @MainActor
  private func firstSessionElement(
    in app: XCUIApplication,
    identifierPrefix: String
  ) -> XCUIElement {
    app.descendants(matching: .any).matching(
      NSPredicate(format: "identifier BEGINSWITH %@", identifierPrefix)
    ).firstMatch
  }

#if os(iOS)
  @MainActor
  private func assertSessionSurvivesRotation(in app: XCUIApplication) {
    XCUIDevice.shared.orientation = .landscapeLeft
    let sessionSurvivedLandscape = app.descendants(matching: .any)[
      "cooking-session-shell"
    ].waitForExistence(timeout: 5)
    // Restore the shared simulator before recording a failure so the next
    // smoke never inherits landscape state from an aborted assertion.
    XCUIDevice.shared.orientation = .portrait
    XCTAssertTrue(
      sessionSurvivedLandscape,
      "The active Cooking Session did not survive rotation to landscape."
    )
  }
#endif
}

private struct RecordedSessionProgress {
  let ingredientIdentifier: String
  let instructionIdentifier: String
  let adjustedWorkingYield: String?
}
