// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import XCTest

final class FolderCheckpointTests: XCTestCase {
  func testCheckpointReconstructsWithoutObsoletePayloadAndSuppressesLateRetry() throws {
    let kitchenID = Kitchen.ID()
    let folderID = Folder.ID()
    var commands: [FolderCommand] = []
    let empty = try FolderLibrary(kitchenID: kitchenID, commands: [])
    commands.append(try empty.prepare(.create(id: folderID, name: "Original", parentID: nil),
                                      at: Date(timeIntervalSince1970: 0)))
    for (index, name) in ["Obsolete Rename Payload", "Current"].enumerated() {
      let library = try FolderLibrary(kitchenID: kitchenID, commands: commands)
      commands.append(try library.prepare(.rename(id: folderID, name: name),
                                          at: Date(timeIntervalSince1970: Double(index + 1))))
    }
    let library = try FolderLibrary(kitchenID: kitchenID, commands: commands)
    XCTAssertNil(try library.checkpoint(at: Date(timeIntervalSince1970: 86_400)))
    let checkpoint = try XCTUnwrap(library.checkpoint(at: Date(timeIntervalSince1970: 40 * 86_400)))
    let encoded = try JSONEncoder().encode(checkpoint)
    XCTAssertFalse(try XCTUnwrap(String(data: encoded, encoding: .utf8)).contains("Obsolete Rename Payload"))
    let decoded = try JSONDecoder().decode(FolderCheckpoint.self, from: encoded)
    let reconstructed = try FolderLibrary(kitchenID: kitchenID, commands: [], checkpoints: [decoded])
    XCTAssertEqual(reconstructed.folders, library.folders)
    let retry = try FolderLibrary(kitchenID: kitchenID, commands: commands, checkpoints: [decoded])
    XCTAssertEqual(retry.folders, library.folders)
    let rename = try reconstructed.prepare(.rename(id: folderID, name: "After compaction"),
                                            at: Date(timeIntervalSince1970: -1))
    let changed = try FolderLibrary(kitchenID: kitchenID, commands: [rename], checkpoints: [decoded])
    XCTAssertEqual(changed.folders.map(\.name), ["After compaction"])
  }
  func testIndependentCheckpointsAndConcurrentMembershipMaximaConverge() throws {
    var fixture = FolderFixture()
    let firstID = Folder.ID()
    let secondID = Folder.ID()
    let recipeID = Recipe.ID()
    try fixture.apply(.create(id: firstID, name: "A", parentID: nil))
    try fixture.apply(.create(id: secondID, name: "B", parentID: nil))
    let baseline = try fixture.library()
    let left = try baseline.prepare(.assign(recipeID: recipeID, folderID: firstID),
                                    at: Date(timeIntervalSince1970: 100))
    let right = try baseline.prepare(.assign(recipeID: recipeID, folderID: secondID),
                                     at: Date(timeIntervalSince1970: 50))
    let leftLibrary = try FolderLibrary(kitchenID: fixture.kitchenID, commands: fixture.commands + [left])
    let rightLibrary = try FolderLibrary(kitchenID: fixture.kitchenID, commands: fixture.commands + [right])
    let date = Date(timeIntervalSince1970: 40 * 86_400)
    let leftCheckpoint = try XCTUnwrap(leftLibrary.checkpoint(at: date))
    let rightCheckpoint = try XCTUnwrap(rightLibrary.checkpoint(at: date))
    for checkpoints in [[leftCheckpoint, rightCheckpoint], [rightCheckpoint, leftCheckpoint]] {
      let merged = try FolderLibrary(kitchenID: fixture.kitchenID, commands: [], checkpoints: checkpoints)
      XCTAssertEqual(merged.primaryFolder(for: recipeID), firstID)
      let later = try leftLibrary.prepare(.assign(recipeID: recipeID, folderID: nil),
                                          at: Date(timeIntervalSince1970: 0))
      let resolved = try FolderLibrary(kitchenID: fixture.kitchenID, commands: [later], checkpoints: checkpoints)
      XCTAssertEqual(resolved.primaryFolder(for: recipeID), secondID)
    }
    XCTAssertThrowsError(try FolderLibrary(kitchenID: Kitchen.ID(), commands: [], checkpoints: [leftCheckpoint]))
  }

  func testCheckpointCannotDiscardRequiredReconstructiveEvidence() throws {
    var fixture = FolderFixture()
    try fixture.apply(.create(id: Folder.ID(), name: "Required", parentID: nil))
    let checkpoint = try XCTUnwrap(fixture.library().checkpoint(at: Date(timeIntervalSince1970: 40 * 86_400)))
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint)) as? [String: Any])
    var evidence = try XCTUnwrap(object["evidence"] as? [String: Any])
    evidence["retained"] = []
    object["evidence"] = evidence
    let damaged = try JSONDecoder().decode(FolderCheckpoint.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try FolderLibrary(kitchenID: fixture.kitchenID, commands: [], checkpoints: [damaged]))
  }

  func testCheckpointRetentionAndClosedCausalFrontierAreValidated() throws {
    var fixture = FolderFixture()
    try fixture.apply(.create(id: Folder.ID(), name: "Required", parentID: nil))
    let date = Date(timeIntervalSince1970: 40 * 86_400)
    let checkpoint = try XCTUnwrap(fixture.library().checkpoint(at: date))
    XCTAssertGreaterThanOrEqual(checkpoint.antiResurrectionUntil.timeIntervalSince(date), 5 * 365 * 86_400)
    let encoded = try JSONEncoder().encode(checkpoint)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object["antiResurrectionUntil"] = object["createdAt"]
    let shortPromise = try JSONDecoder().decode(FolderCheckpoint.self,
                                               from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try FolderLibrary(kitchenID: fixture.kitchenID, commands: [], checkpoints: [shortPromise]))
    object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var evidence = try XCTUnwrap(object["evidence"] as? [String: Any])
    var receipts = try XCTUnwrap(evidence["receipts"] as? [[String: Any]])
    receipts[0]["observed"] = [UUID().uuidString]
    evidence["receipts"] = receipts
    object["evidence"] = evidence
    let openFrontier = try JSONDecoder().decode(FolderCheckpoint.self,
                                               from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try FolderLibrary(kitchenID: fixture.kitchenID, commands: [], checkpoints: [openFrontier]))
  }

}
