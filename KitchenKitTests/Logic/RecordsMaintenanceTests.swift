// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

final class RecordsMaintenanceTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 1_700_000_000)

  func testInterruptedJobsRemainDueAfterRelaunchWithoutStarvingOtherJobs() throws {
    var schedule = RecordsMaintenanceSchedule()
    XCTAssertEqual(schedule.next(at: start), .deletedRecipes)
    schedule.record(.deletedRecipes, at: start, completed: false)
    schedule = try JSONDecoder().decode(RecordsMaintenanceSchedule.self,
      from: JSONEncoder().encode(schedule))
    for job in RecordsMaintenanceJob.allCases.dropFirst() {
      XCTAssertEqual(schedule.next(at: start), job)
      schedule.record(job, at: start, completed: true)
    }
    XCTAssertEqual(schedule.next(at: start), .deletedRecipes)
    schedule.record(.deletedRecipes, at: start, completed: true)
    XCTAssertNil(schedule.next(at: start))
    XCTAssertEqual(schedule.next(at: start.addingTimeInterval(6 * 3_600)), .folders)
  }

  func testClockCorrectionDoesNotStrandMaintenance() {
    var schedule = RecordsMaintenanceSchedule()
    for job in RecordsMaintenanceJob.allCases {
      schedule.record(job, at: start, completed: true)
    }
    XCTAssertNotNil(schedule.next(at: start.addingTimeInterval(-1)))
  }

  func testObservationBecomesStaleAtAWeekAndRecoversOnlyWithSuccess() throws {
    var observation = SynchronizationObservation(beganObservingAt: start)
    XCTAssertFalse(observation.isStale(at: start.addingTimeInterval(7 * 86_400 - 1)))
    let week = start.addingTimeInterval(7 * 86_400)
    XCTAssertTrue(observation.isStale(at: week))
    observation = try JSONDecoder().decode(SynchronizationObservation.self,
      from: JSONEncoder().encode(observation))
    XCTAssertTrue(observation.isStale(at: week))
    observation.recordSuccess(at: week)
    observation.recordSuccess(at: start)
    XCTAssertEqual(observation.lastSuccessfulEventAt, week)
    XCTAssertFalse(observation.isStale(at: week))
    XCTAssertTrue(observation.isStale(at: week.addingTimeInterval(7 * 86_400)))
  }
}
