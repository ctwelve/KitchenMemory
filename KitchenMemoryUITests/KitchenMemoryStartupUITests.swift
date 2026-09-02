// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if os(iOS)
import UIKit
import XCTest

extension KitchenMemoryUITests {
  @MainActor
  func testIPadSidebarSurvivesDelayedStartup() throws {
    guard UIDevice.current.userInterfaceIdiom == .pad else {
      throw XCTSkip("The persistent regular-width sidebar is an iPad contract.")
    }

    XCUIDevice.shared.orientation = .landscapeLeft
    let app = XCUIApplication()
    app.launchArguments = [
      "-ApplePersistenceIgnoreState", "YES",
      "--ui-testing", "--simulate-startup-delay",
    ]
    app.launch()

    let libraryShell = app.descendants(matching: .any)["recipe-library-shell"]
    XCTAssertTrue(libraryShell.waitForExistence(timeout: 2))
    XCTAssertTrue(app.descendants(matching: .any)["kitchen-loading"].exists)
    let newRecipe = app.buttons["new-recipe"]
    XCTAssertTrue(newRecipe.waitForExistence(timeout: 15))
    let enabled = NSPredicate(format: "isEnabled == true")
    expectation(for: enabled, evaluatedWith: newRecipe)
    waitForExpectations(timeout: 2)
    XCTAssertTrue(libraryShell.exists)
    app.terminate()
  }
}
#endif
