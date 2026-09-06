// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import XCTest

final class FolderPolicyEdgeTests: XCTestCase {
  func testUnknownTargetsAndInvalidLocalRepairsAreRejected() throws {
    var fixture = FolderFixture()
    let root = Folder.ID()
    let other = Folder.ID()
    let child = Folder.ID()
    try fixture.apply(.create(id: root, name: "Root", parentID: nil))
    try fixture.apply(.create(id: other, name: "Other", parentID: nil))
    try fixture.apply(.create(id: child, name: "Child", parentID: root))
    let library = try fixture.library()
    let unknown = Folder.ID()
    XCTAssertTrue(library.subtree(of: unknown).isEmpty)
    XCTAssertNil(library.canonicalFolderID(for: unknown))
    for intent in [
      FolderIntent.rename(id: unknown, name: "Missing"), .move(id: unknown, parentID: nil),
      .create(id: Folder.ID(), name: "Orphan", parentID: unknown), .delete(id: unknown),
      .reorder(id: root, afterID: root), .reorder(id: root, afterID: child),
      .merge(ids: [root], survivorID: nil, name: "Bad"),
      .merge(ids: [root, root], survivorID: nil, name: "Bad"),
      .merge(ids: [root, child], survivorID: nil, name: "Bad"),
      .merge(ids: [root, other], survivorID: child, name: "Bad"),
    ] { XCTAssertThrowsError(try library.prepare(intent)) }
  }

  func testMergeCannotTakeAnUnselectedSiblingNameAndMultipleCollisionsStaySeparate() throws {
    var fixture = FolderFixture()
    let first = Folder.ID()
    let second = Folder.ID()
    try fixture.apply(.create(id: first, name: "A", parentID: nil))
    try fixture.apply(.create(id: second, name: "B", parentID: nil))
    try fixture.apply(.create(id: Folder.ID(), name: "Taken", parentID: nil))
    XCTAssertThrowsError(try fixture.library().prepare(.merge(ids: [first, second], survivorID: nil, name: "TAKEN")))
    let empty = try FolderLibrary(kitchenID: fixture.kitchenID, commands: [])
    let duplicates = try ["A", "a", "B", "b"].map {
      try empty.prepare(.create(id: Folder.ID(), name: $0, parentID: nil))
    }
    XCTAssertEqual(try FolderLibrary(kitchenID: fixture.kitchenID, commands: duplicates).collisions.count, 2)
  }

  func testNeighborOrderHandlesAfterAnchorAndDeletedAnchor() throws {
    var fixture = FolderFixture()
    let ids = (0..<3).map { _ in Folder.ID() }
    for (id, name) in zip(ids, ["A", "B", "C"]) { try fixture.apply(.create(id: id, name: name, parentID: nil)) }
    try fixture.apply(.ordering(.manual))
    try fixture.apply(.reorder(id: ids[0], afterID: ids[1]))
    XCTAssertEqual(try fixture.library().children(of: nil).map(\.id), [ids[1], ids[0], ids[2]])
    try fixture.apply(.delete(id: ids[1]))
    XCTAssertEqual(try fixture.library().children(of: nil).map(\.id), [ids[2], ids[0]])
  }

  func testOppositeConcurrentMergesKeepOlderExistingIdentity() throws {
    var fixture = FolderFixture()
    let older = Folder.ID()
    let newer = Folder.ID()
    try fixture.apply(.create(id: older, name: "A", parentID: nil))
    try fixture.apply(.create(id: newer, name: "B", parentID: nil))
    let baseline = try fixture.library()
    let left = try baseline.prepare(.merge(ids: [older, newer], survivorID: older, name: "Together"))
    let right = try baseline.prepare(.merge(ids: [older, newer], survivorID: newer, name: "Together"))
    let partial = try FolderLibrary(kitchenID: fixture.kitchenID, commands: [left, right])
    XCTAssertTrue(partial.folders.isEmpty)
    for tail in [[left, right], [right, left]] {
      let library = try FolderLibrary(kitchenID: fixture.kitchenID, commands: fixture.commands + tail)
      XCTAssertEqual(library.folders.map(\.id), [older])
      XCTAssertEqual(library.canonicalFolderID(for: newer), older)
    }
  }

  func testExplicitlyDeletedMissingParentStaysAtRootDespiteConcurrentMergeAlias() throws {
    var fixture = FolderFixture()
    let older = Folder.ID()
    let newer = Folder.ID()
    let late = Folder.ID()
    try fixture.apply(.create(id: older, name: "A", parentID: nil))
    try fixture.apply(.create(id: newer, name: "B", parentID: nil))
    let baseline = try fixture.library()
    let deletion = try baseline.prepare(.delete(id: newer))
    let merge = try baseline.prepare(.merge(ids: [older, newer], survivorID: older, name: "Together"))
    let child = try baseline.prepare(.create(id: late, name: "Late", parentID: newer))
    let library = try FolderLibrary(kitchenID: fixture.kitchenID, commands: fixture.commands + [merge, deletion, child])
    XCTAssertNil(library.folders.first(where: { $0.id == late })?.parentID)
  }
}

struct FolderFixture {
  let kitchenID = Kitchen.ID()
  var commands: [FolderCommand] = []

  func library() throws -> FolderLibrary { try FolderLibrary(kitchenID: kitchenID, commands: commands) }

  mutating func apply(_ intent: FolderIntent) throws {
    commands.append(try library().prepare(intent, at: Date(timeIntervalSince1970: Double(commands.count))))
  }
}
