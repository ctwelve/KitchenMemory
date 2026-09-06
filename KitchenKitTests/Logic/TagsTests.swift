// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import XCTest

final class TagsTests: XCTestCase {
  func testNamesPreserveUnicodeAndTreatLeadingHashAsPresentation() throws {
    let empty = try TagLibrary(kitchenID: Kitchen.ID(), commands: [])
    let tagID = Tag.ID()
    let create = try empty.prepare(.create(id: tagID, name: "  #Café / Soup  "))
    let library = try TagLibrary(kitchenID: empty.kitchenID, commands: [create, create])
    XCTAssertEqual(library.tags.map(\.name), ["Café / Soup"])
    XCTAssertEqual(library.tags.map(\.displayName), ["#Café / Soup"])
    XCTAssertEqual(library.canonicalTagID(for: tagID), tagID)
    XCTAssertNil(library.canonicalTagID(for: Tag.ID()))
    for name in ["CAFE\u{0301} / SOUP", "#café / soup"] {
      XCTAssertThrowsError(try library.prepare(.create(id: Tag.ID(), name: name))) { error in
        XCTAssertEqual(error as? TagError, .duplicateName)
      }
    }
    XCTAssertNoThrow(try library.prepare(.create(id: Tag.ID(), name: "Cafe / Soup")))
    XCTAssertNoThrow(try library.prepare(.create(id: Tag.ID(), name: "#" + String(repeating: "🍲", count: 256))))
    for name in ["", "  ", "#", "###", "Soup\n", "\u{0000}Soup", "A\u{2028}B", String(repeating: "a", count: 257)] {
      XCTAssertThrowsError(try empty.prepare(.create(id: Tag.ID(), name: name))) { error in
        XCTAssertEqual(error as? TagError, .invalidName)
      }
    }
  }

  func testManyToManyAssignmentsAndObservedRemovalLeaveConcurrentAddition() throws {
    let kitchenID = Kitchen.ID()
    let first = Tag.ID()
    let second = Tag.ID()
    let recipe = Recipe.ID()
    let otherRecipe = Recipe.ID()
    var commands: [TagCommand] = []
    func append(_ intent: TagIntent) throws {
      commands.append(try TagLibrary(kitchenID: kitchenID, commands: commands).prepare(intent))
    }
    try append(.create(id: first, name: "Weeknight"))
    try append(.create(id: second, name: "Soup"))
    try append(.assign(recipeID: recipe, tagID: first))
    try append(.assign(recipeID: recipe, tagID: second))
    try append(.assign(recipeID: otherRecipe, tagID: first))
    let baseline = try TagLibrary(kitchenID: kitchenID, commands: commands)
    XCTAssertEqual(baseline.tagIDs(for: recipe), [first, second])
    XCTAssertEqual(baseline.recipeIDs(for: first), [recipe, otherRecipe])
    XCTAssertTrue(baseline.tagIDs(for: Recipe.ID()).isEmpty)
    XCTAssertTrue(baseline.recipeIDs(for: Tag.ID()).isEmpty)
    let removal = try baseline.prepare(.remove(recipeID: recipe, tagID: first))
    let concurrent = try baseline.prepare(.assign(recipeID: recipe, tagID: first))
    let removed = try TagLibrary(kitchenID: kitchenID, commands: commands + [removal])
    XCTAssertEqual(removed.tagIDs(for: recipe), [second])
    XCTAssertEqual(removed.tagIDs(for: otherRecipe), [first])
    for tail in [[removal, concurrent], [concurrent, removal]] {
      let merged = try TagLibrary(kitchenID: kitchenID, commands: commands + tail)
      XCTAssertEqual(merged.tagIDs(for: recipe), [first, second])
      let deliberate = try merged.prepare(.remove(recipeID: recipe, tagID: first))
      let final = try TagLibrary(kitchenID: kitchenID, commands: commands + tail + [deliberate])
      XCTAssertEqual(final.tagIDs(for: recipe), [second])
    }
  }

  func testMergeUnionsAssignmentDotsAndRemovalCanRetractObservedAliasAssignments() throws {
    let kitchenID = Kitchen.ID()
    let first = Tag.ID()
    let second = Tag.ID()
    let recipe = Recipe.ID()
    let other = Recipe.ID()
    let empty = try TagLibrary(kitchenID: kitchenID, commands: [])
    let left = try empty.prepare(.create(id: first, name: "Soup"), at: Date(timeIntervalSince1970: 0))
    let right = try empty.prepare(.create(id: second, name: "SOUP"), at: Date(timeIntervalSince1970: 1))
    var commands = [left, right]
    var library = try TagLibrary(kitchenID: kitchenID, commands: commands)
    XCTAssertEqual(Set(library.collisions.flatMap(\.tagIDs)), [first, second])
    commands.append(try library.prepare(.assign(recipeID: recipe, tagID: first)))
    commands.append(try library.prepare(.assign(recipeID: other, tagID: second)))
    library = try TagLibrary(kitchenID: kitchenID, commands: commands)
    let merge = try library.prepare(.merge(ids: [second, first], survivorID: nil, name: "#Soups"))
    let late = try library.prepare(.assign(recipeID: recipe, tagID: second))
    commands.append(merge)
    library = try TagLibrary(kitchenID: kitchenID, commands: commands)
    XCTAssertEqual(library.tags.map(\.name), ["Soups"])
    XCTAssertTrue(library.collisions.isEmpty)
    XCTAssertEqual(library.canonicalTagID(for: second), first)
    XCTAssertEqual(library.recipeIDs(for: second), [recipe, other])
    commands.append(try library.prepare(.remove(recipeID: other, tagID: first)))
    commands.append(try library.prepare(.remove(recipeID: recipe, tagID: first)))
    commands.append(late)
    library = try TagLibrary(kitchenID: kitchenID, commands: commands)
    XCTAssertTrue(library.tagIDs(for: other).isEmpty)
    XCTAssertEqual(library.tagIDs(for: recipe), [first])
  }

  func testDeletionWinsConcurrentRenameAssignmentAndMergeWithoutResurrection() throws {
    let kitchenID = Kitchen.ID()
    let first = Tag.ID()
    let second = Tag.ID()
    let recipe = Recipe.ID()
    var commands: [TagCommand] = []
    for (id, name) in [(first, "First"), (second, "Second")] {
      commands.append(try TagLibrary(kitchenID: kitchenID, commands: commands).prepare(.create(id: id, name: name)))
    }
    let baseline = try TagLibrary(kitchenID: kitchenID, commands: commands)
    let deletion = try baseline.prepare(.delete(id: first))
    let rename = try baseline.prepare(.rename(id: first, name: "New"))
    let assignment = try baseline.prepare(.assign(recipeID: recipe, tagID: first))
    let merge = try baseline.prepare(.merge(ids: [first, second], survivorID: second, name: "Second"))
    let library = try TagLibrary(kitchenID: kitchenID, commands: commands + [merge, rename, deletion, assignment])
    XCTAssertEqual(library.tags.map(\.id), [second])
    XCTAssertTrue(library.tagIDs(for: recipe).isEmpty)
    XCTAssertNil(library.canonicalTagID(for: first))
    XCTAssertThrowsError(try library.prepare(.create(id: first, name: "Reuse"))) { error in
      XCTAssertEqual(error as? TagError, .identityCollision(first))
    }
    XCTAssertThrowsError(try library.prepare(.assign(recipeID: recipe, tagID: first)))
  }

  func testCausalRenameBeatsHigherClockAndCollisionCanBeRenamed() throws {
    let kitchenID = Kitchen.ID()
    let first = Tag.ID()
    let second = Tag.ID()
    let empty = try TagLibrary(kitchenID: kitchenID, commands: [])
    let create = try empty.prepare(.create(id: first, name: "Soup"))
    let duplicate = try empty.prepare(.create(id: second, name: "SOUP"))
    let baseline = try TagLibrary(kitchenID: kitchenID, commands: [create, duplicate])
    let rename = try baseline.prepare(.rename(id: second, name: "Stew"), at: Date(timeIntervalSince1970: 100))
    let observed = try TagLibrary(kitchenID: kitchenID, commands: [create, duplicate, rename])
    let deliberate = try observed.prepare(.rename(id: second, name: "#Meals"), at: Date(timeIntervalSince1970: 0))
    let result = try TagLibrary(kitchenID: kitchenID, commands: [deliberate, rename, duplicate, create])
    XCTAssertTrue(result.collisions.isEmpty)
    XCTAssertEqual(result.tags.first(where: { $0.id == second })?.name, "Meals")
    XCTAssertThrowsError(try result.prepare(.rename(id: second, name: "Soup")))
  }

  func testManualSequenceSurvivesModeChangesAndNewTagsAppend() throws {
    let kitchenID = Kitchen.ID()
    let alpha = Tag.ID()
    let beta = Tag.ID()
    let newer = Tag.ID()
    var commands: [TagCommand] = []
    func append(_ intent: TagIntent) throws {
      commands.append(try TagLibrary(kitchenID: kitchenID, commands: commands).prepare(
        intent, at: Date(timeIntervalSince1970: Double(-commands.count))
      ))
    }
    try append(.create(id: alpha, name: "Alpha"))
    try append(.create(id: beta, name: "Beta"))
    try append(.reorder(id: beta, afterID: nil))
    try append(.ordering(.manual))
    XCTAssertEqual(try TagLibrary(kitchenID: kitchenID, commands: commands).orderedTags().map(\.id), [beta, alpha])
    try append(.ordering(.alphabetical))
    XCTAssertEqual(try TagLibrary(kitchenID: kitchenID, commands: commands).orderedTags().map(\.id), [alpha, beta])
    try append(.create(id: newer, name: "Aardvark"))
    try append(.ordering(.manual))
    XCTAssertEqual(try TagLibrary(kitchenID: kitchenID, commands: commands).orderedTags().map(\.id),
                   [beta, alpha, newer])
    try append(.reorder(id: beta, afterID: newer))
    XCTAssertEqual(try TagLibrary(kitchenID: kitchenID, commands: commands).orderedTags().map(\.id),
                   [alpha, newer, beta])
  }
}
