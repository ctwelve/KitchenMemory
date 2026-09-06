// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import XCTest

final class TagPartialRemovalTests: XCTestCase {
  func testRemovalPreparedWithMissingMergeRemainsValidWhenMergeArrives() throws {
    let fixture = try baseline()
    let merge = try fixture.library.prepare(.merge(ids: [fixture.first, fixture.second],
                                                   survivorID: fixture.first, name: "Both"), at: fixture.date)
    let complete = try TagLibrary(kitchenID: fixture.kitchenID, commands: fixture.commands + [merge])
    let descendant = try complete.prepare(.ordering(.manual), at: fixture.date)
    let partialCommands = fixture.commands + [descendant]
    let partial = try TagLibrary(kitchenID: fixture.kitchenID, commands: partialCommands)
    let remove = try partial.prepare(.remove(recipeID: fixture.recipeID, tagID: fixture.second), at: fixture.date)
    try assertRemoved(fixture, commands: partialCommands + [remove, merge], survivor: fixture.first)
  }

  func testRemovalPreparedWithoutAncestorDeletionSurvivesItsArrival() throws {
    let fixture = try baseline()
    let merge = try fixture.library.prepare(.merge(ids: [fixture.first, fixture.second],
                                                   survivorID: fixture.first, name: "Both"), at: fixture.date)
    let deletion = try fixture.library.prepare(.delete(id: fixture.second), at: fixture.date)
    let complete = try TagLibrary(kitchenID: fixture.kitchenID, commands: fixture.commands + [merge, deletion])
    let descendant = try complete.prepare(.ordering(.manual), at: fixture.date)
    let partialCommands = fixture.commands + [merge, descendant]
    let partial = try TagLibrary(kitchenID: fixture.kitchenID, commands: partialCommands)
    let remove = try partial.prepare(.remove(recipeID: fixture.recipeID, tagID: fixture.first), at: fixture.date)
    try assertRemoved(fixture, commands: partialCommands + [remove, deletion], survivor: fixture.first)
  }

  func testRemovalPreparedWithoutWinningCompetingMergeSurvivesRedirection() throws {
    let fixture = try baseline()
    let firstMerge = try fixture.library.prepare(.merge(ids: [fixture.first, fixture.second],
                                                        survivorID: fixture.first, name: "First"), at: fixture.date)
    let competing = try fixture.library.prepare(.merge(ids: [fixture.second, fixture.third],
                                                       survivorID: fixture.third, name: "Third"),
                                                at: fixture.date.addingTimeInterval(1))
    let complete = try TagLibrary(kitchenID: fixture.kitchenID, commands: fixture.commands + [firstMerge, competing])
    let descendant = try complete.prepare(.ordering(.manual), at: fixture.date)
    let partialCommands = fixture.commands + [firstMerge, descendant]
    let partial = try TagLibrary(kitchenID: fixture.kitchenID, commands: partialCommands)
    let remove = try partial.prepare(.remove(recipeID: fixture.recipeID, tagID: fixture.first), at: fixture.date)
    try assertRemoved(fixture, commands: partialCommands + [remove, competing], survivor: fixture.third)
  }

  func testMultipleCollisionGroupsAndInvalidCheckpointPromisesRequireStableRecovery() throws {
    let kitchenID = Kitchen.ID()
    let empty = try TagLibrary(kitchenID: kitchenID, commands: [])
    let commands = try ["Soup", "SOUP", "Meals", "MEALS"].map {
      try empty.prepare(.create(id: Tag.ID(), name: $0), at: Date(timeIntervalSince1970: 0))
    }
    let library = try TagLibrary(kitchenID: kitchenID, commands: commands)
    let reversed = try TagLibrary(kitchenID: kitchenID, commands: commands.reversed())
    XCTAssertEqual(library.collisions.count, 2)
    XCTAssertEqual(library.collisions, reversed.collisions)
    XCTAssertEqual(library.orderedTags(), reversed.orderedTags())
    let checkpoint = try XCTUnwrap(library.checkpoint(at: Date(timeIntervalSince1970: 40 * 86_400)))
    let truncated = TagCheckpoint(id: checkpoint.id, kitchenID: kitchenID, createdAt: checkpoint.createdAt,
                                  antiResurrectionUntil: checkpoint.createdAt, evidence: checkpoint.evidence)
    XCTAssertThrowsError(try TagLibrary(kitchenID: kitchenID, commands: [], checkpoints: [truncated]))
    let conflicting = TagCheckpoint(id: checkpoint.id, kitchenID: kitchenID, createdAt: checkpoint.createdAt,
                                    antiResurrectionUntil: checkpoint.antiResurrectionUntil.addingTimeInterval(1),
                                    evidence: checkpoint.evidence)
    XCTAssertThrowsError(try TagLibrary(kitchenID: kitchenID, commands: [], checkpoints: [checkpoint, conflicting]))
  }

  func testRemovalRetractsEveryObservedDotAndOverlappingCheckpointsCoalesce() throws {
    let fixture = try baseline()
    let secondAssignment = try fixture.library.prepare(
      .assign(recipeID: fixture.recipeID, tagID: fixture.second), at: fixture.date
    )
    let assigned = try TagLibrary(kitchenID: fixture.kitchenID, commands: fixture.commands + [secondAssignment])
    let removal = try assigned.prepare(.remove(recipeID: fixture.recipeID, tagID: fixture.second), at: fixture.date)
    let commands = fixture.commands + [secondAssignment, removal]
    let removed = try TagLibrary(kitchenID: fixture.kitchenID, commands: commands)
    XCTAssertTrue(removed.tagIDs(for: fixture.recipeID).isEmpty)
    let date = fixture.date.addingTimeInterval(40 * 86_400)
    let first = try XCTUnwrap(removed.checkpoint(at: date))
    let second = try XCTUnwrap(removed.checkpoint(at: date))
    let replay = try TagLibrary(kitchenID: fixture.kitchenID, commands: [], checkpoints: [first, second])
    XCTAssertTrue(replay.tagIDs(for: fixture.recipeID).isEmpty)
    XCTAssertEqual(replay.tags, removed.tags)
  }

  private struct Fixture {
    let kitchenID: Kitchen.ID
    let first: Tag.ID
    let second: Tag.ID
    let third: Tag.ID
    let recipeID: Recipe.ID
    let date: Date
    let commands: [TagCommand]
    let library: TagLibrary
  }

  private func baseline() throws -> Fixture {
    let kitchenID = Kitchen.ID()
    let first = Tag.ID()
    let second = Tag.ID()
    let third = Tag.ID()
    let recipeID = Recipe.ID()
    let date = Date(timeIntervalSince1970: 0)
    var commands: [TagCommand] = []
    for intent in [TagIntent.create(id: first, name: "A"), .create(id: second, name: "B"),
                   .create(id: third, name: "C"), .assign(recipeID: recipeID, tagID: second),
    ] {
      commands.append(try TagLibrary(kitchenID: kitchenID, commands: commands).prepare(intent, at: date))
    }
    return Fixture(kitchenID: kitchenID, first: first, second: second, third: third, recipeID: recipeID,
                   date: date, commands: commands, library: try TagLibrary(kitchenID: kitchenID, commands: commands))
  }

  private func assertRemoved(_ fixture: Fixture, commands: [TagCommand], survivor: Tag.ID) throws {
    let complete = try TagLibrary(kitchenID: fixture.kitchenID, commands: commands)
    XCTAssertTrue(complete.tagIDs(for: fixture.recipeID).isEmpty)
    let checkpoint = try XCTUnwrap(complete.checkpoint(at: fixture.date.addingTimeInterval(40 * 86_400)))
    let replay = try TagLibrary(kitchenID: fixture.kitchenID, commands: commands.reversed(), checkpoints: [checkpoint])
    XCTAssertTrue(replay.tagIDs(for: fixture.recipeID).isEmpty)
    let newAssignment = try replay.prepare(.assign(recipeID: fixture.recipeID, tagID: survivor))
    let assigned = try TagLibrary(kitchenID: fixture.kitchenID, commands: [newAssignment], checkpoints: [checkpoint])
    XCTAssertEqual(assigned.tagIDs(for: fixture.recipeID), [survivor])
  }
}
