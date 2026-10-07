// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import CoreGraphics
import Foundation
import XCTest

@MainActor
final class CookingSessionReadingMotionTests: XCTestCase {
  func testExplicitJumpClampsAndDoesNotScheduleMotionOrMoveAlreadyVisibleStep() {
    var offset = 0.0
    var schedules = 0
    let motion = ReadingMotionController(
      viewport: { .init(offset: offset, height: 300, contentHeight: 1200) },
      move: { offset = $0 }, schedule: { _ in schedules += 1; return {} })
    motion.reveal(CGRect(x: 0, y: 20, width: 300, height: 100), animated: false)
    XCTAssertEqual(offset, 0)
    motion.reveal(CGRect(x: 0, y: 1150, width: 300, height: 100), animated: false)
    XCTAssertEqual(offset, 900)
    XCTAssertEqual(schedules, 0)
    motion.restore(to: -50)
    XCTAssertEqual(offset, 0)
    motion.restore(to: .infinity)
    XCTAssertEqual(offset, 0)
    motion.restore(to: 4000)
    XCTAssertEqual(offset, 900)
  }

  func testInterruptStopsAtCurrentOffsetAndOldFramesCannotRestartTravel() {
    var time = 0.0
    var offset = 0.0
    var scheduled: [@MainActor () -> Void] = []
    let motion = ReadingMotionController(
      viewport: { .init(offset: offset, height: 300, contentHeight: 1200) },
      move: { offset = $0 }, now: { time },
      schedule: { action in scheduled.append(action); return {} })
    motion.reveal(CGRect(x: 0, y: 600, width: 300, height: 100), animated: true)
    time = 0.5
    scheduled[0]()
    XCTAssertGreaterThan(offset, 0)
    XCTAssertLessThan(offset, 412)
    let interruptedOffset = offset

    motion.interrupt()
    time = 5
    scheduled[0]()

    XCTAssertEqual(offset, interruptedOffset)
    XCTAssertFalse(motion.isMoving)
    motion.reveal(CGRect(x: 0, y: 900, width: 300, height: 100), animated: true)
    time = 10
    scheduled[1]()
    XCTAssertEqual(offset, 712)
    XCTAssertFalse(motion.isMoving)
  }
}
