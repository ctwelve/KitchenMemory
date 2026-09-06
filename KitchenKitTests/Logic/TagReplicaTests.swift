// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Algorithms
import Foundation
@testable import KitchenKit
import XCTest

final class TagReplicaTests: XCTestCase {
  func testEveryArrivalPrefixAcceptsPartialEvidenceAndCompletePermutationsConverge() throws {
    let kitchenID = Kitchen.ID()
    let tagID = Tag.ID()
    let recipeID = Recipe.ID()
    var commands: [TagCommand] = []
    for intent in [TagIntent.create(id: tagID, name: "Soup"), .assign(recipeID: recipeID, tagID: tagID),
                   .rename(id: tagID, name: "Meals"), .remove(recipeID: recipeID, tagID: tagID),
    ] {
      let baseline = try TagLibrary(kitchenID: kitchenID, commands: commands)
      commands.append(try baseline.prepare(intent, at: Date(timeIntervalSince1970: Double(commands.count))))
    }
    let observed = try TagLibrary(kitchenID: kitchenID, commands: Array(commands.prefix(2)))
    commands.append(try observed.prepare(.assign(recipeID: recipeID, tagID: tagID)))
    for arrival in commands.permutations() {
      for length in 0...arrival.count {
        let partial = try TagLibrary(kitchenID: kitchenID, commands: Array(arrival.prefix(length)))
        if length == arrival.count {
          XCTAssertEqual(partial.tags.map(\.name), ["Meals"])
          XCTAssertEqual(partial.tagIDs(for: recipeID), [tagID])
        }
      }
    }
  }

  func testCheckpointRetainsObservedRemoveAndAliasesAcrossCompactionAndLateRetry() throws {
    let kitchenID = Kitchen.ID()
    let first = Tag.ID()
    let second = Tag.ID()
    let recipeID = Recipe.ID()
    var commands: [TagCommand] = []
    let intents: [TagIntent] = [
      .create(id: first, name: "A"), .create(id: second, name: "B"),
      .assign(recipeID: recipeID, tagID: second), .merge(ids: [first, second], survivorID: first, name: "Both"),
      .rename(id: first, name: "Before"), .rename(id: first, name: "After"),
      .remove(recipeID: recipeID, tagID: first), .ordering(.manual), .ordering(.alphabetical),
    ]
    for intent in intents {
      commands.append(try TagLibrary(kitchenID: kitchenID, commands: commands).prepare(
        intent, at: Date(timeIntervalSince1970: Double(commands.count))
      ))
    }
    let library = try TagLibrary(kitchenID: kitchenID, commands: commands)
    XCTAssertNil(try library.checkpoint(at: Date(timeIntervalSince1970: 29 * 86_400)))
    let checkpoint = try XCTUnwrap(library.checkpoint(at: Date(timeIntervalSince1970: 40 * 86_400)))
    XCTAssertLessThan(checkpoint.evidence.retained.count, commands.count)
    let encoded = try JSONEncoder().encode(checkpoint)
    let decoded = try JSONDecoder().decode(TagCheckpoint.self, from: encoded)
    for arrivals in [[], commands, Array(commands.reversed())] {
      let replay = try TagLibrary(kitchenID: kitchenID, commands: arrivals, checkpoints: [decoded, decoded])
      XCTAssertEqual(replay.tags, library.tags)
      XCTAssertEqual(replay.tagIDs(for: recipeID), [])
      XCTAssertEqual(replay.canonicalTagID(for: second), first)
      XCTAssertEqual(replay.orderedTags(), library.orderedTags())
      XCTAssertNil(try replay.checkpoint(at: Date(timeIntervalSince1970: 50 * 86_400)))
    }
    let oldReplica = try TagLibrary(kitchenID: kitchenID, commands: Array(commands.prefix(3)))
    let concurrent = try oldReplica.prepare(.assign(recipeID: recipeID, tagID: second))
    let merged = try TagLibrary(kitchenID: kitchenID, commands: [concurrent], checkpoints: [decoded])
    XCTAssertEqual(merged.tagIDs(for: recipeID), [first])
    let removal = try merged.prepare(.remove(recipeID: recipeID, tagID: first))
    XCTAssertTrue(try TagLibrary(kitchenID: kitchenID, commands: [removal, concurrent],
                                checkpoints: [decoded]).tagIDs(for: recipeID).isEmpty)
    let conflicting = TagCommand(kitchenID: kitchenID, action: OrganizationAction(
      id: commands[4].id, authoredAt: commands[4].action.authoredAt, observed: commands[4].action.observed,
      payload: .rename(id: first, name: "Tampered")
    ))
    XCTAssertThrowsError(try TagLibrary(kitchenID: kitchenID, commands: [conflicting],
                                         checkpoints: [decoded])) { error in
      XCTAssertEqual(error as? TagError, .actionCollision(conflicting.id))
    }
  }

  func testOppositeConcurrentMergesChooseSameExistingIdentityForEveryArrival() throws {
    let kitchenID = Kitchen.ID()
    let first = Tag.ID()
    let second = Tag.ID()
    let empty = try TagLibrary(kitchenID: kitchenID, commands: [])
    let left = try empty.prepare(.create(id: first, name: "Soup"), at: Date(timeIntervalSince1970: 0))
    let right = try empty.prepare(.create(id: second, name: "SOUP"), at: Date(timeIntervalSince1970: 1))
    let collided = try TagLibrary(kitchenID: kitchenID, commands: [left, right])
    let forward = try collided.prepare(.merge(ids: [first, second], survivorID: first, name: "Left"))
    let reverse = try collided.prepare(.merge(ids: [first, second], survivorID: second, name: "Right"))
    for arrival in [left, right, forward, reverse].permutations() {
      let result = try TagLibrary(kitchenID: kitchenID, commands: arrival)
      XCTAssertEqual(result.tags.map(\.id), [first])
      XCTAssertEqual(result.canonicalTagID(for: second), first)
    }
  }

  func testInvalidCommandsAndEvidenceAreExplicitTagErrors() throws {
    let kitchenID = Kitchen.ID()
    let tagID = Tag.ID()
    let empty = try TagLibrary(kitchenID: kitchenID, commands: [])
    let create = try empty.prepare(.create(id: tagID, name: "Soup"))
    let library = try TagLibrary(kitchenID: kitchenID, commands: [create])
    for intent in [TagIntent.rename(id: Tag.ID(), name: "Missing"), .reorder(id: tagID, afterID: tagID),
                   .merge(ids: [tagID], survivorID: nil, name: "No"),
                   .merge(ids: [tagID, tagID], survivorID: tagID, name: "No"),
    ] {
      XCTAssertThrowsError(try library.prepare(intent))
    }
    XCTAssertThrowsError(try TagLibrary(kitchenID: Kitchen.ID(), commands: [create])) { error in
      XCTAssertEqual(error as? TagError, .wrongKitchen)
    }
    let duplicate = try empty.prepare(.create(id: tagID, name: "Another"))
    XCTAssertThrowsError(try TagLibrary(kitchenID: kitchenID, commands: [create, duplicate])) { error in
      XCTAssertEqual(error as? TagError, .identityCollision(tagID))
    }
    let cyclicID = UUID()
    let cyclic = TagCommand(kitchenID: kitchenID, action: OrganizationAction(
      id: cyclicID, authoredAt: Date(), observed: [cyclicID], payload: .ordering(.manual)
    ))
    XCTAssertThrowsError(try TagLibrary(kitchenID: kitchenID, commands: [cyclic])) { error in
      XCTAssertEqual(error as? TagError, .causalCycle)
    }
    let malformed: [TagChange] = [
      .create(id: Tag.ID(), name: "#StoredHash"), .reorder(id: tagID, afterID: tagID),
      .merge(ids: [tagID], survivorID: tagID, name: "Invalid"),
      .remove(recipeID: Recipe.ID(), assignments: [create.id]),
    ]
    for payload in malformed {
      let command = TagCommand(kitchenID: kitchenID, action: OrganizationAction(
        id: UUID(), authoredAt: Date(), observed: [create.id], payload: payload
      ))
      XCTAssertThrowsError(try TagLibrary(kitchenID: kitchenID, commands: [create, command]))
    }
  }
}
