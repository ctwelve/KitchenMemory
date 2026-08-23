// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemory
import CloudKit
import Foundation
import XCTest

@MainActor
final class PersonalCloudStatusMonitorTests: XCTestCase {
  private final class AccountChecker: PersonalCloudAccountChecking {
    var result: PersonalCloudStatus = .available
    var checkCount = 0

    func status() async -> PersonalCloudStatus {
      checkCount += 1
      return result
    }
  }

  private final class DeferredAccountChecker: PersonalCloudAccountChecking {
    private(set) var continuations: [CheckedContinuation<PersonalCloudStatus, Never>] = []

    func status() async -> PersonalCloudStatus {
      await withCheckedContinuation { continuations.append($0) }
    }

    func resume(at index: Int, returning status: PersonalCloudStatus) {
      continuations[index].resume(returning: status)
    }
  }

  func testAccountStatusesMapToPresentationNeutralStates() {
    XCTAssertEqual(CloudKitAccountChecker.status(for: .available), .available)
    XCTAssertEqual(CloudKitAccountChecker.status(for: .noAccount), .noAccount)
    XCTAssertEqual(CloudKitAccountChecker.status(for: .restricted), .restricted)
    XCTAssertEqual(
      CloudKitAccountChecker.status(for: .temporarilyUnavailable),
      .temporarilyUnavailable
    )
    XCTAssertEqual(CloudKitAccountChecker.status(for: .couldNotDetermine), .failed)
  }

  func testCloudEventsConvergeWithoutAccountChecksMaskingActiveWork() {
    var state = PersonalCloudStatusState(accountStatus: .available)
    let eventID = UUID()

    state.recordEvent(id: eventID, type: 1, ended: false, succeeded: false)
    XCTAssertEqual(state.status, .syncing)

    state.accountStatus = .available
    XCTAssertEqual(state.status, .syncing)

    state.recordEvent(id: eventID, type: 1, ended: true, succeeded: false)
    XCTAssertEqual(state.status, .failed)

    let retryID = UUID()
    state.recordEvent(id: retryID, type: 1, ended: false, succeeded: false)
    XCTAssertEqual(state.status, .syncing)
    state.recordEvent(id: retryID, type: 1, ended: true, succeeded: true)
    XCTAssertEqual(state.status, .available)
  }

  func testStartChecksTheAccountAndPublishesItsResult() async {
    let checker = AccountChecker()
    var statuses: [PersonalCloudStatus] = []
    let monitor = PersonalCloudStatusMonitor(
      notificationCenter: NotificationCenter(),
      accountChecker: checker
    ) { statuses.append($0) }

    monitor.start()
    await Task.yield()

    XCTAssertEqual(statuses, [.checking, .available])
    XCTAssertEqual(checker.checkCount, 1)
  }

  func testAccountChangeNotificationRechecksTheAccount() async {
    let center = NotificationCenter()
    let checker = AccountChecker()
    var statuses: [PersonalCloudStatus] = []
    let monitor = PersonalCloudStatusMonitor(
      notificationCenter: center,
      accountChecker: checker
    ) { statuses.append($0) }

    monitor.start()
    await Task.yield()
    checker.result = .noAccount
    center.post(name: .CKAccountChanged, object: nil)
    await Task.yield()

    XCTAssertEqual(checker.checkCount, 2)
    XCTAssertEqual(statuses, [.checking, .available, .checking, .noAccount])
  }

  func testOlderAccountCheckCannotReplaceANewerResult() async {
    let center = NotificationCenter()
    let checker = DeferredAccountChecker()
    var statuses: [PersonalCloudStatus] = []
    let monitor = PersonalCloudStatusMonitor(
      notificationCenter: center,
      accountChecker: checker
    ) { statuses.append($0) }

    monitor.start()
    await Task.yield()
    center.post(name: .CKAccountChanged, object: nil)
    await Task.yield()
    checker.resume(at: 1, returning: .noAccount)
    await Task.yield()
    checker.resume(at: 0, returning: .available)
    await Task.yield()

    XCTAssertEqual(statuses, [.checking, .checking, .noAccount])
  }
}
