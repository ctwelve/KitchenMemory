// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if os(iOS)
import UIKit
#endif
import XCTest

extension KitchenMemoryUITests {
  @MainActor
  func testRegularLibraryShellSurvivesDestinationAndSessionChanges() throws {
#if os(iOS)
    guard UIDevice.current.userInterfaceIdiom == .pad else {
      throw XCTSkip("Persistent regular-width navigation is an iPad contract.")
    }
#endif

    let app = launchApp(prefersRegularWidth: true)

    let shell = app.descendants(matching: .any)["recipe-library-shell"]
    XCTAssertTrue(shell.waitForExistence(timeout: 5))
    assertRegularLibraryChrome(in: app, shell: shell)

    visit(
      app.descendants(matching: .any)["sessions-destination"],
      revealing: app.descendants(matching: .any)["sessions-history"],
      in: app,
      shell: shell
    )
    visit(
      app.descendants(matching: .any)["deleted-items-destination"],
      revealing: app.descendants(matching: .any)["deleted-items"],
      in: app,
      shell: shell
    )
    visit(
      app.descendants(matching: .any)["recovery-destination"],
      revealing: app.descendants(matching: .any)["session-recovery"],
      in: app,
      shell: shell
    )

    let recipeRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipe-row-"))
      .firstMatch
    visit(
      recipeRow,
      revealing: app.descendants(matching: .any)["recipe-detail"],
      in: app,
      shell: shell
    )

    let start = app.buttons["start-cooking"]
    XCTAssertTrue(start.waitForExistence(timeout: 5))
    activate(start)
    XCTAssertTrue(
      app.descendants(matching: .any)["cooking-session-shell"].waitForExistence(timeout: 5)
    )
    assertRegularLibraryChrome(in: app, shell: shell)

    let leave = app.buttons["leave-session"]
    XCTAssertTrue(leave.waitForExistence(timeout: 5))
    activate(leave)
    XCTAssertTrue(app.descendants(matching: .any)["recipe-detail"].waitForExistence(timeout: 5))
    assertRegularLibraryChrome(in: app, shell: shell)

    app.terminate()
  }

  @MainActor
  private func visit(
    _ destination: XCUIElement,
    revealing detail: XCUIElement,
    in app: XCUIApplication,
    shell: XCUIElement
  ) {
    XCTAssertTrue(destination.waitForExistence(timeout: 5))
    activate(destination)
    XCTAssertTrue(detail.waitForExistence(timeout: 5))
    assertRegularLibraryChrome(in: app, shell: shell)
  }

  @MainActor
  private func assertRegularLibraryChrome(in app: XCUIApplication, shell: XCUIElement) {
    XCTAssertTrue(shell.exists)
#if os(macOS)
    let sidebarToggle = app.descendants(matching: .any)["toggle-sidebar"]
    XCTAssertTrue(sidebarToggle.exists)
#else
    XCTAssertTrue(app.buttons["toggle-sidebar"].exists)
#endif
  }
}
