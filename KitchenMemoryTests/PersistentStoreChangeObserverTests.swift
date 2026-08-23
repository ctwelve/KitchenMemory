// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemory
import CoreData
import Foundation
import XCTest

@MainActor
final class PersistentStoreChangeObserverTests: XCTestCase {
  func testRemoteStoreChangeRunsRefreshWork() {
    let center = NotificationCenter()
    var refreshCount = 0
    let observer = PersistentStoreChangeObserver(notificationCenter: center) {
      refreshCount += 1
    }

    center.post(name: .NSPersistentStoreRemoteChange, object: nil)

    XCTAssertEqual(refreshCount, 1)
    withExtendedLifetime(observer) {}
  }
}
