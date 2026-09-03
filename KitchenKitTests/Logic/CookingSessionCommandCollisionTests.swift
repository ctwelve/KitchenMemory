// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
final class CookingSessionCommandCollisionTests: XCTestCase {
  func testConflictingRootAndClosureRemainRecoveryWithoutAppendingCommands() throws {
    let rootFixture = try SessionLogicFixture(seed: 7_000)
    let root = try XCTUnwrap(rootFixture.repository.evidence(
      id: rootFixture.sessionID
    )?.roots.first)
    try rootFixture.repository.append(.start(CookingSessionRootEvidence(
      id: root.id,
      kitchenID: root.kitchenID,
      recipeID: root.recipeID,
      recipeRevisionID: root.recipeRevisionID,
      startedAt: rootFixture.date(999),
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotData: root.snapshotData,
      snapshotDigest: root.snapshotDigest,
      sourceSessionID: root.sourceSessionID,
      sourceClosureID: root.sourceClosureID
    )))
    try assertRecovery(rootFixture.logic.perform(.stop(rootFixture.fact(6, at: 120))))
    XCTAssertTrue(try XCTUnwrap(rootFixture.repository.evidence(
      id: rootFixture.sessionID
    )).facts.isEmpty)

    let closureFixture = try SessionLogicFixture(seed: 8_000)
    let closureID = try closureFixture.finish(id: 6, at: 120)
    let closure = try XCTUnwrap(closureFixture.repository.evidence(
      id: closureFixture.sessionID
    )?.closures.first)
    try closureFixture.repository.append(.finish(SessionClosureEvidence(
      id: closure.id,
      sessionID: closure.sessionID,
      kitchenID: closure.kitchenID,
      finishedAt: closureFixture.date(999),
      causalHeadsFormatVersion: closure.causalHeadsFormatVersion,
      causalHeadsData: closure.causalHeadsData,
      snapshotFormatVersion: closure.snapshotFormatVersion,
      snapshotDigest: closure.snapshotDigest,
      projectionFormatVersion: closure.projectionFormatVersion,
      projectionDigest: closure.projectionDigest,
      outcomeFormatVersion: closure.outcomeFormatVersion,
      outcomeData: closure.outcomeData
    )))
    try assertRecovery(closureFixture.logic.perform(.delete(DeleteCookingSessionIntention(
      deletionID: .init(rawValue: closureFixture.id(7)),
      sessionID: closureFixture.sessionID,
      deletedAt: closureFixture.date(130)
    ))))
    XCTAssertEqual(closure.id, closureID)
    XCTAssertTrue(try XCTUnwrap(closureFixture.repository.evidence(
      id: closureFixture.sessionID
    )).deletions.isEmpty)
  }

  func testConflictingDeleteRemainsRecoveryWithoutAppendingRestore() throws {
    let deletionFixture = try SessionLogicFixture(seed: 9_000)
    let deletionID = SessionDeletion.ID(rawValue: deletionFixture.id(6))
    _ = try deletionFixture.logic.perform(.delete(DeleteCookingSessionIntention(
      deletionID: deletionID,
      sessionID: deletionFixture.sessionID,
      deletedAt: deletionFixture.date(120)
    )))
    let retainedDeletion = try XCTUnwrap(deletionFixture.repository.evidence(
      id: deletionFixture.sessionID
    )?.deletions.first)
    try deletionFixture.repository.append(.delete(SessionDeletionEvidence(
      id: retainedDeletion.id,
      sessionID: retainedDeletion.sessionID,
      kitchenID: retainedDeletion.kitchenID,
      deletedAt: deletionFixture.date(999),
      sessionHeadsFormatVersion: retainedDeletion.sessionHeadsFormatVersion,
      sessionHeadsData: retainedDeletion.sessionHeadsData,
      dispositionHeadsFormatVersion: retainedDeletion.dispositionHeadsFormatVersion,
      dispositionHeadsData: retainedDeletion.dispositionHeadsData
    )))
    try assertRecovery(deletionFixture.logic.perform(.restore(
      RestoreCookingSessionIntention(
        id: .init(rawValue: deletionFixture.id(7)),
        sessionID: deletionFixture.sessionID,
        restoredAt: deletionFixture.date(130),
        observedDeletionIDs: [deletionID]
      )
    )))
    XCTAssertTrue(try XCTUnwrap(deletionFixture.repository.evidence(
      id: deletionFixture.sessionID
    )).restorations.isEmpty)
  }

  func testConflictingRestoreRemainsRecoveryWithoutAppendingDelete() throws {
    let restoreFixture = try SessionLogicFixture(seed: 10_000)
    let restoreDeletionID = SessionDeletion.ID(rawValue: restoreFixture.id(6))
    _ = try restoreFixture.logic.perform(.delete(DeleteCookingSessionIntention(
      deletionID: restoreDeletionID,
      sessionID: restoreFixture.sessionID,
      deletedAt: restoreFixture.date(120)
    )))
    _ = try restoreFixture.logic.perform(.restore(RestoreCookingSessionIntention(
      id: .init(rawValue: restoreFixture.id(7)),
      sessionID: restoreFixture.sessionID,
      restoredAt: restoreFixture.date(130),
      observedDeletionIDs: [restoreDeletionID]
    )))
    let resolution = try XCTUnwrap(restoreFixture.repository.evidence(
      id: restoreFixture.sessionID
    )?.restorations.first)
    try restoreFixture.repository.append(.restore([
      SessionDeletionResolutionEvidence(
        id: resolution.id,
        deletionID: resolution.deletionID,
        sessionID: resolution.sessionID,
        kitchenID: resolution.kitchenID,
        restoredAt: restoreFixture.date(999),
        dispositionHeadsFormatVersion: resolution.dispositionHeadsFormatVersion,
        dispositionHeadsData: resolution.dispositionHeadsData
      ),
    ]))
    try assertRecovery(restoreFixture.logic.perform(.delete(DeleteCookingSessionIntention(
      deletionID: .init(rawValue: restoreFixture.id(8)),
      sessionID: restoreFixture.sessionID,
      deletedAt: restoreFixture.date(140)
    ))))
    XCTAssertEqual(try restoreFixture.repository.evidence(
      id: restoreFixture.sessionID
    )?.deletions.count, 1)
  }

  private func assertRecovery(
    _ result: @autoclosure () throws -> CookingSessionCommandResult,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    guard case .attention(.recovery) = try result() else {
      XCTFail("Expected Recovery attention", file: file, line: line)
      return
    }
  }
}
