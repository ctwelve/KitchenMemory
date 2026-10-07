// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import CoreGraphics
import Foundation
import KitchenKit
import XCTest

@MainActor
final class CookingSessionReadingMotionTests: XCTestCase {
  func testCompletionMovesOnlyInvokingReaderAndReduceMotionRequiresJump() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: try XCTUnwrap(app.libraryModel.selectedRecipe)))
    let session = try XCTUnwrap(model.currentSession)
    let steps = session.snapshot.instructionSections.flatMap(\.steps)
    XCTAssertGreaterThan(steps.count, 1)
    let origin = UUID(), otherOrigin = UUID()
    let first = CookingReaderCoordinator(readingOrigin: origin, position: nil, completion: nil)
    let other = CookingReaderCoordinator(readingOrigin: otherOrigin, position: nil, completion: nil)
    var time = 0.0, firstOffset = 0.0, otherOffset = 0.0
    var scheduled: [@MainActor () -> Void] = []
    first.motion = ReadingMotionController(
      viewport: { .init(offset: firstOffset, height: 300, contentHeight: 1200) },
      move: { firstOffset = $0 }, now: { time },
      schedule: { scheduled.append($0); return {} })
    other.motion = ReadingMotionController(
      viewport: { .init(offset: otherOffset, height: 300, contentHeight: 1200) },
      move: { otherOffset = $0 }, schedule: { _ in XCTFail("Other reader moved"); return {} })
    first.isReady = { true }; other.isReady = { true }
    let frames = [steps[0].id: CGRect(x: 0, y: 20, width: 300, height: 100),
                  steps[1].id: CGRect(x: 0, y: 600, width: 300, height: 100)]
    for reader in [first, other] {
      reader.update(session: session, preference: model.readingPreference(for: session),
        completion: nil, jump: nil, reduceMotion: false)
      reader.setFrames(frames)
    }
    XCTAssertTrue(model.setInstruction(steps[0].id, to: .completed, readingOrigin: origin))
    let updated = try XCTUnwrap(model.currentSession)
    for reader in [first, other] {
      reader.update(session: updated, preference: model.readingPreference(for: updated),
        completion: model.readingCompletion, jump: nil, reduceMotion: false)
      reader.setFrames(frames)
    }
    XCTAssertEqual(scheduled.count, 1)
    time = 5; scheduled[0]()
    XCTAssertEqual(firstOffset, 412)
    XCTAssertEqual(otherOffset, 0)

    first.motion?.restore(to: 0)
    model.chooseReadingInstruction(steps[0].id, in: updated)
    XCTAssertTrue(model.setInstruction(steps[0].id, to: .open))
    XCTAssertTrue(model.setInstruction(steps[0].id, to: .completed, readingOrigin: origin))
    let reduced = try XCTUnwrap(model.currentSession)
    first.update(session: reduced, preference: model.readingPreference(for: reduced),
      completion: model.readingCompletion, jump: nil, reduceMotion: true)
    first.setFrames(frames)
    XCTAssertEqual(firstOffset, 0)
    XCTAssertEqual(scheduled.count, 1)
    first.update(session: reduced, preference: model.readingPreference(for: reduced),
      completion: model.readingCompletion, jump: UUID(), reduceMotion: true)
    first.applyGeometry()
    XCTAssertEqual(firstOffset, 412)
    XCTAssertEqual(scheduled.count, 1)
  }

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
