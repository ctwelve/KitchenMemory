// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import SwiftUI
import XCTest

@MainActor
final class LibraryNavigationPolicyTests: XCTestCase {
  func testInitialVisibilityShowsMacSidebarAndKeepsIOSAdaptive() {
#if os(macOS)
    XCTAssertEqual(LibraryNavigationPolicy.initialVisibility, .all)
#else
    XCTAssertEqual(LibraryNavigationPolicy.initialVisibility, .automatic)
#endif
  }

  func testDestinationSelectionPreservesRegularShellAndFocusesCompactDetail() {
    XCTAssertEqual(
      LibraryNavigationPolicy.destinationSelectionVisibility(
        current: .all,
        preservesSidebar: true
      ),
      .all
    )
    XCTAssertEqual(
      LibraryNavigationPolicy.destinationSelectionVisibility(
        current: .automatic,
        preservesSidebar: false
      ),
      .detailOnly
    )
  }
}
