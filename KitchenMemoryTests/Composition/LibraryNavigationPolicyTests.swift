// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import SwiftUI
import XCTest

@MainActor
final class LibraryNavigationPolicyTests: XCTestCase {
  func testCompactStartupKeepsTheSampleDecisionReachable() {
    XCTAssertEqual(LibraryNavigationPolicy.initialColumn(startup: .loading, focus: .content), .detail)
    XCTAssertEqual(LibraryNavigationPolicy.initialColumn(startup: .choosingSamples, focus: .content), .detail)
    XCTAssertEqual(LibraryNavigationPolicy.initialColumn(startup: .ready, focus: .content), .content)
    XCTAssertEqual(LibraryNavigationPolicy.initialColumn(startup: .ready, focus: .detail), .detail)
    XCTAssertEqual(LibraryNavigationPolicy.column(for: .content), .content)
    XCTAssertEqual(LibraryNavigationPolicy.column(for: .detail), .detail)
  }

  func testInitialVisibilityShowsMacSidebarAndKeepsIOSAdaptive() {
#if os(macOS)
    XCTAssertEqual(LibraryNavigationPolicy.initialVisibility, .all)
#else
    XCTAssertEqual(LibraryNavigationPolicy.initialVisibility, .automatic)
#endif
  }

}
