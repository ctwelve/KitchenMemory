// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import XCTest

final class FolderReplicaTests: XCTestCase {
  func testDeepHierarchyConvergesAcrossReversedAndRotatedArrival() throws {
    let kitchenID = Kitchen.ID()
    var commands: [FolderCommand] = []
    var ids: [Folder.ID] = []
    for index in 0..<512 {
      let partial = try FolderLibrary(kitchenID: kitchenID, commands: Array(commands.suffix(1)))
      let id = Folder.ID()
      commands.append(try partial.prepare(.create(id: id, name: "Level \(index)", parentID: ids.last),
                                          at: Date(timeIntervalSince1970: Double(index))))
      ids.append(id)
    }
    let rootID = try XCTUnwrap(ids.first)
    let expected = Set(ids)
    for arrival in [commands, Array(commands.reversed()), Array(commands[256...] + commands[..<256])] {
      let library = try FolderLibrary(kitchenID: kitchenID, commands: arrival)
      XCTAssertEqual(library.subtree(of: rootID), expected)
      XCTAssertEqual(library.children(of: nil).map(\.id), [rootID])
    }
  }

  func testDistinctCreationsCannotReuseOneFolderIdentity() throws {
    let kitchenID = Kitchen.ID()
    let folderID = Folder.ID()
    let empty = try FolderLibrary(kitchenID: kitchenID, commands: [])
    let first = try empty.prepare(.create(id: folderID, name: "One", parentID: nil))
    let second = try empty.prepare(.create(id: folderID, name: "Two", parentID: nil))
    XCTAssertThrowsError(try FolderLibrary(kitchenID: kitchenID, commands: [first, second])) { error in
      XCTAssertEqual(error as? FolderError, .identityCollision(folderID))
    }
  }
  func testDecodedEvidenceRejectsInvalidNamesAndSelfCausality() throws {
    let kitchenID = Kitchen.ID()
    let empty = try FolderLibrary(kitchenID: kitchenID, commands: [])
    let command = try empty.prepare(.create(id: Folder.ID(), name: "Good", parentID: nil))
    let invalidName = try altering(command) { action in
      var payload = try XCTUnwrap(action["payload"] as? [String: Any])
      var create = try XCTUnwrap(payload["create"] as? [String: Any])
      create["name"] = "Bad\nName"
      payload["create"] = create
      action["payload"] = payload
    }
    XCTAssertThrowsError(try FolderLibrary(kitchenID: kitchenID, commands: [invalidName]))
    let selfCycle = try altering(command) { $0["observed"] = [command.id.uuidString] }
    XCTAssertThrowsError(try FolderLibrary(kitchenID: kitchenID, commands: [selfCycle])) { error in
      XCTAssertEqual(error as? FolderError, .causalCycle)
    }
    XCTAssertThrowsError(try FolderLibrary(kitchenID: Kitchen.ID(), commands: [command]))
    let reusedAction = try empty.prepare(.create(id: Folder.ID(), name: "Other", parentID: nil), id: command.id)
    XCTAssertThrowsError(try FolderLibrary(kitchenID: kitchenID, commands: [command, reusedAction]))
  }

  func testDecodedMergeCannotNameAnEmptyIdentitySet() throws {
    var fixture = FolderFixture()
    let first = Folder.ID()
    let second = Folder.ID()
    try fixture.apply(.create(id: first, name: "A", parentID: nil))
    try fixture.apply(.create(id: second, name: "B", parentID: nil))
    let command = try fixture.library().prepare(.merge(ids: [first, second], survivorID: nil, name: "Together"))
    let invalid = try altering(command) { action in
      var payload = try XCTUnwrap(action["payload"] as? [String: Any])
      var merge = try XCTUnwrap(payload["merge"] as? [String: Any])
      merge["ids"] = []
      payload["merge"] = merge
      action["payload"] = payload
    }
    XCTAssertThrowsError(try FolderLibrary(kitchenID: fixture.kitchenID, commands: fixture.commands + [invalid]))
  }

  private func altering(
    _ command: FolderCommand, action change: (inout [String: Any]) throws -> Void
  ) throws -> FolderCommand {
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(command)) as? [String: Any])
    var action = try XCTUnwrap(object["action"] as? [String: Any])
    try change(&action)
    object["action"] = action
    return try JSONDecoder().decode(FolderCommand.self, from: JSONSerialization.data(withJSONObject: object))
  }

}
