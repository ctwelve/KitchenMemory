// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import SwiftUI
import XCTest

@MainActor
final class LibraryNavigationPolicyTests: XCTestCase {
  func testCompactStartupKeepsTheSampleDecisionReachable() {
    XCTAssertEqual(LibraryNavigationPolicy.initialColumn(startup: .loading, destination: .recipe), .detail)
    XCTAssertEqual(LibraryNavigationPolicy.initialColumn(startup: .choosingSamples, destination: .recipe), .detail)
    XCTAssertEqual(LibraryNavigationPolicy.initialColumn(startup: .ready, destination: .recipe), .content)
  }

  func testInitialVisibilityShowsMacSidebarAndKeepsIOSAdaptive() {
#if os(macOS)
    XCTAssertEqual(LibraryNavigationPolicy.initialVisibility, .all)
#else
    XCTAssertEqual(LibraryNavigationPolicy.initialVisibility, .automatic)
#endif
  }

}
