// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryPersistence
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
    var onRequest: ((Int) -> Void)?

    func status() async -> PersonalCloudStatus {
      await withCheckedContinuation {
        continuations.append($0)
        onRequest?(continuations.count)
      }
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
    let initialCheckFinished = expectation(description: "Initial account check finished")
    let backgroundCheckFinished = expectation(description: "Background notification handled")
    let monitor = PersonalCloudStatusMonitor(
      notificationCenter: center,
      accountChecker: checker
    ) { status in
      statuses.append(status)
      if status == .available { initialCheckFinished.fulfill() }
      if status == .noAccount { backgroundCheckFinished.fulfill() }
    }

    monitor.start()
    await fulfillment(of: [initialCheckFinished], timeout: 1)
    checker.result = .noAccount
    DispatchQueue.global().async {
      center.post(name: .CKAccountChanged, object: nil)
    }
    await fulfillment(of: [backgroundCheckFinished], timeout: 1)

    XCTAssertEqual(checker.checkCount, 2)
    XCTAssertEqual(statuses, [.checking, .available, .checking, .noAccount])
  }

  func testCloudEventFromPersistenceQueuePublishesOnMainActor() async {
    let center = NotificationCenter()
    let checker = AccountChecker()
    let accountAvailable = expectation(description: "Account check finished")
    let syncStarted = expectation(description: "Cloud event crossed to the main actor")
    let monitor = PersonalCloudStatusMonitor(
      notificationCenter: center,
      accountChecker: checker
    ) { status in
      if status == .available { accountAvailable.fulfill() }
      if status == .syncing { syncStarted.fulfill() }
    }

    monitor.start()
    await fulfillment(of: [accountAvailable], timeout: 1)
    let event = PersonalCloudEventSnapshot(
      id: UUID(),
      type: 1,
      ended: false,
      succeeded: false
    )

    DispatchQueue.global().async {
      monitor.receiveCloudEvent(event)
    }

    await fulfillment(of: [syncStarted], timeout: 1)
  }

  func testOlderAccountCheckCannotReplaceANewerResult() async {
    let center = NotificationCenter()
    let checker = DeferredAccountChecker()
    var statuses: [PersonalCloudStatus] = []
    let firstCheckStarted = expectation(description: "Initial account check started")
    let secondCheckStarted = expectation(description: "Replacement account check started")
    let newerResultPublished = expectation(description: "Newer account result published")
    let staleResultPublished = expectation(description: "Stale account result was ignored")
    staleResultPublished.isInverted = true
    checker.onRequest = { count in
      if count == 1 { firstCheckStarted.fulfill() }
      if count == 2 { secondCheckStarted.fulfill() }
    }
    let monitor = PersonalCloudStatusMonitor(
      notificationCenter: center,
      accountChecker: checker
    ) { status in
      statuses.append(status)
      if status == .noAccount { newerResultPublished.fulfill() }
      if status == .available { staleResultPublished.fulfill() }
    }

    monitor.start()
    await fulfillment(of: [firstCheckStarted], timeout: 1)
    center.post(name: .CKAccountChanged, object: nil)
    await fulfillment(of: [secondCheckStarted], timeout: 1)
    checker.resume(at: 1, returning: .noAccount)
    await fulfillment(of: [newerResultPublished], timeout: 1)
    checker.resume(at: 0, returning: .available)
    await fulfillment(of: [staleResultPublished], timeout: 0.1)

    XCTAssertEqual(statuses, [.checking, .checking, .noAccount])
  }
}
