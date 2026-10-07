// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class CookingSessionScreenAwakeTests: XCTestCase {
  func testAwakeOwnershipRequiresVisibleForegroundActiveCookAndReleasesOnEveryExit() {
    var leases = 0
    let controller = ScreenAwakeController(acquire: {
      leases += 1
      return { leases -= 1 }
    })
    controller.update(isVisible: true, isForeground: true, lifecycle: .active, keepsAwake: true)
    XCTAssertEqual(leases, 1)
    controller.update(isVisible: true, isForeground: true, lifecycle: .active, keepsAwake: true)
    XCTAssertEqual(leases, 1)
    controller.update(isVisible: true, isForeground: true, lifecycle: .stopped, keepsAwake: true)
    XCTAssertEqual(leases, 0)
    controller.update(isVisible: true, isForeground: true, lifecycle: .active, keepsAwake: true)
    controller.update(isVisible: true, isForeground: false, lifecycle: .active, keepsAwake: true)
    XCTAssertEqual(leases, 0)
    controller.update(isVisible: true, isForeground: true, lifecycle: .active, keepsAwake: false)
    XCTAssertEqual(leases, 0)
    controller.update(isVisible: true, isForeground: true, lifecycle: .active, keepsAwake: true)
    controller.update(isVisible: false, isForeground: true, lifecycle: .active, keepsAwake: true)
    XCTAssertEqual(leases, 0)
    controller.update(isVisible: true, isForeground: true, lifecycle: .finished, keepsAwake: true)
    XCTAssertEqual(leases, 0)
  }
}
