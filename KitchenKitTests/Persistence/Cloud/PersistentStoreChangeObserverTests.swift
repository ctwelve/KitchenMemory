// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import CoreData
import Foundation
import XCTest

@MainActor
final class PersistentStoreChangeObserverTests: XCTestCase {
  func testRemoteStoreChangeFromPersistenceQueueRunsRefreshWorkOnMainActor() async {
    let center = NotificationCenter()
    var refreshCount = 0
    let refreshed = expectation(description: "Refresh crossed to the main actor")
    let observer = PersistentStoreChangeObserver(notificationCenter: center) {
      refreshCount += 1
      refreshed.fulfill()
    }

    DispatchQueue.global().async {
      center.post(name: .NSPersistentStoreRemoteChange, object: nil)
    }

    await fulfillment(of: [refreshed], timeout: 1)
    XCTAssertEqual(refreshCount, 1)
    withExtendedLifetime(observer) {}
  }
}
