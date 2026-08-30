// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import XCTest

extension KitchenMemoryUITests {
  @MainActor
  func testDeletedItemsRestoreAndRecoveryAccessSmoke() {
    let app = launchApp(additionalArguments: ["-AppleLanguages", "(en-US)"])
    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    XCTAssertTrue(recipeRow.waitForExistence(timeout: 5))
    activate(recipeRow)
    XCTAssertTrue(app.buttons["start-cooking"].waitForExistence(timeout: 5))
    activate(app.buttons["start-cooking"])

    XCTAssertTrue(app.buttons["delete-session"].waitForExistence(timeout: 5))
    activate(app.buttons["delete-session"])
    let confirmDelete = app.buttons["confirm-delete-session"].firstMatch
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 3))
    activate(confirmDelete)

    let deletedDestination = app.descendants(matching: .any)["deleted-items-destination"]
    revealSidebar(in: app, exposing: deletedDestination)
    XCTAssertTrue(deletedDestination.waitForExistence(timeout: 5))
    activate(deletedDestination)
    XCTAssertTrue(app.descendants(matching: .any)["deleted-items"].waitForExistence(timeout: 5))
    let restore = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "restore-session-")
    ).firstMatch
    XCTAssertTrue(restore.waitForExistence(timeout: 5))
    activate(restore)
    let confirmRestore = app.buttons["confirm-restore-session"].firstMatch
    XCTAssertTrue(confirmRestore.waitForExistence(timeout: 3))
    activate(confirmRestore)

    let recoveryDestination = app.descendants(matching: .any)["recovery-destination"]
    revealSidebar(in: app, exposing: recoveryDestination)
    XCTAssertTrue(recoveryDestination.waitForExistence(timeout: 5))
    activate(recoveryDestination)
    XCTAssertTrue(app.descendants(matching: .any)["session-recovery"].waitForExistence(timeout: 5))
  }
}
