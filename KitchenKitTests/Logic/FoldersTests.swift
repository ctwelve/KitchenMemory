// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import XCTest

final class FoldersTests: XCTestCase {
  func testCreationPreservesDisplayNameAndRetryDoesNotDuplicateIdentity() throws {
    let kitchenID = Kitchen.ID()
    let folderID = Folder.ID()
    let empty = try FolderLibrary(kitchenID: kitchenID, commands: [])
    let command = try empty.prepare(.create(id: folderID, name: "  Café / Soup  ", parentID: nil))
    let library = try FolderLibrary(kitchenID: kitchenID, commands: [command, command])

    XCTAssertEqual(library.folders.map(\.id), [folderID])
    XCTAssertEqual(library.folders.map(\.name), ["Café / Soup"])
    XCTAssertNil(library.folders.first?.parentID)
  }
  func testNamesRejectInvalidInputAndCompareCanonicalCaseWithoutRemovingDiacritics() throws {
    let empty = try FolderLibrary(kitchenID: Kitchen.ID(), commands: [])
    for invalid in ["", "   ", "Soup\n", "Soup\u{0000}", String(repeating: "a", count: 257)] {
      XCTAssertThrowsError(try empty.prepare(.create(id: Folder.ID(), name: invalid, parentID: nil)))
    }
    let create = try empty.prepare(.create(id: Folder.ID(), name: "Café", parentID: nil))
    let library = try FolderLibrary(kitchenID: empty.kitchenID, commands: [create])
    XCTAssertThrowsError(try library.prepare(.create(id: Folder.ID(), name: "CAFE\u{0301}", parentID: nil)))
    XCTAssertNoThrow(try library.prepare(.create(id: Folder.ID(), name: "Cafe", parentID: nil)))
    XCTAssertNoThrow(try library.prepare(.create(id: Folder.ID(), name: "Unfiled", parentID: nil)))
    XCTAssertNoThrow(try library.prepare(.create(id: Folder.ID(), name: String(repeating: "🍲", count: 256),
                                                parentID: nil)))
  }

  func testHierarchyRejectsLocalCyclesAndRepairsProvisionalParentWhenItArrives() throws {
    let kitchenID = Kitchen.ID()
    let rootID = Folder.ID()
    let childID = Folder.ID()
    let empty = try FolderLibrary(kitchenID: kitchenID, commands: [])
    let root = try empty.prepare(.create(id: rootID, name: "Meals", parentID: nil))
    let roots = try FolderLibrary(kitchenID: kitchenID, commands: [root])
    let child = try roots.prepare(.create(id: childID, name: "Soups", parentID: rootID))
    let partial = try FolderLibrary(kitchenID: kitchenID, commands: [child])
    XCTAssertNil(partial.folders.first?.parentID)
    let complete = try FolderLibrary(kitchenID: kitchenID, commands: [child, root])
    XCTAssertEqual(complete.folders.first(where: { $0.id == childID })?.parentID, rootID)
    XCTAssertEqual(complete.subtree(of: rootID), Set([rootID, childID]))
    XCTAssertThrowsError(try complete.prepare(.move(id: rootID, parentID: childID)))
    let move = try complete.prepare(.move(id: childID, parentID: nil))
    let moved = try FolderLibrary(kitchenID: kitchenID, commands: [move, child, root])
    XCTAssertNil(moved.folders.first(where: { $0.id == childID })?.parentID)
  }

  func testConcurrentCycleRejectsClosingMoveAndPreservesEarlierParentInEveryArrivalOrder() throws {
    let kitchenID = Kitchen.ID()
    let parentID = Folder.ID()
    let leftID = Folder.ID()
    let rightID = Folder.ID()
    var commands: [FolderCommand] = []
    for (id, name, parent) in [(parentID, "Parent", nil), (leftID, "Left", nil),
                                (rightID, "Right", parentID),
    ] {
      let library = try FolderLibrary(kitchenID: kitchenID, commands: commands)
      commands.append(try library.prepare(.create(id: id, name: name, parentID: parent),
                                          at: Date(timeIntervalSince1970: 0)))
    }
    let baseline = try FolderLibrary(kitchenID: kitchenID, commands: commands)
    let left = try baseline.prepare(.move(id: leftID, parentID: rightID), at: Date(timeIntervalSince1970: 100))
    let right = try baseline.prepare(.move(id: rightID, parentID: leftID), at: Date(timeIntervalSince1970: 200))
    for tail in [[left, right], [right, left]] {
      let library = try FolderLibrary(kitchenID: kitchenID, commands: commands + tail)
      XCTAssertEqual(library.folders.first(where: { $0.id == leftID })?.parentID, rightID)
      XCTAssertEqual(library.folders.first(where: { $0.id == rightID })?.parentID, parentID)
    }
  }

  func testRecipePlacementUsesCausalMaximaBeforeConcurrentClockTieBreak() throws {
    let kitchenID = Kitchen.ID()
    let recipeID = Recipe.ID()
    let leftID = Folder.ID()
    let rightID = Folder.ID()
    var baseline: [FolderCommand] = []
    for (id, name) in [(leftID, "Left"), (rightID, "Right")] {
      let library = try FolderLibrary(kitchenID: kitchenID, commands: baseline)
      baseline.append(try library.prepare(.create(id: id, name: name, parentID: nil)))
    }
    let initial = try FolderLibrary(kitchenID: kitchenID, commands: baseline)
    let highClock = try initial.prepare(.assign(recipeID: recipeID, folderID: leftID),
                                        at: Date(timeIntervalSince1970: 100))
    let concurrent = try initial.prepare(.assign(recipeID: recipeID, folderID: rightID),
                                         at: Date(timeIntervalSince1970: 50))
    let observedLeft = try FolderLibrary(kitchenID: kitchenID, commands: baseline + [highClock])
    let lowClock = try observedLeft.prepare(.assign(recipeID: recipeID, folderID: nil),
                                            at: Date(timeIntervalSince1970: 0))
    for tail in [[highClock, concurrent, lowClock], [lowClock, concurrent, highClock]] {
      let merged = try FolderLibrary(kitchenID: kitchenID, commands: baseline + tail)
      XCTAssertEqual(merged.primaryFolder(for: recipeID), rightID)
      let deliberate = try merged.prepare(.assign(recipeID: recipeID, folderID: leftID),
                                           at: Date(timeIntervalSince1970: -1))
      let resolved = try FolderLibrary(kitchenID: kitchenID, commands: baseline + tail + [deliberate])
      XCTAssertEqual(resolved.primaryFolder(for: recipeID), leftID)
    }
  }

  func testDeletionDisposesObservedSubtreeAndConcurrentAssignmentsWithoutDeletingRecipeIdentity() throws {
    let kitchenID = Kitchen.ID()
    let parentID = Folder.ID()
    let childID = Folder.ID()
    let lateID = Folder.ID()
    let recipeID = Recipe.ID()
    var commands: [FolderCommand] = []
    for (id, name, parent) in [(parentID, "Meals", nil), (childID, "Soups", parentID)] {
      let library = try FolderLibrary(kitchenID: kitchenID, commands: commands)
      commands.append(try library.prepare(.create(id: id, name: name, parentID: parent)))
    }
    let baseline = try FolderLibrary(kitchenID: kitchenID, commands: commands)
    let deletion = try baseline.prepare(.delete(id: parentID))
    let assignment = try baseline.prepare(.assign(recipeID: recipeID, folderID: childID))
    let lateChild = try baseline.prepare(.create(id: lateID, name: "Later", parentID: parentID))
    let concurrentMove = try baseline.prepare(.move(id: childID, parentID: nil))
    let merged = try FolderLibrary(kitchenID: kitchenID,
                                  commands: commands + [assignment, lateChild, deletion, concurrentMove])
    XCTAssertEqual(merged.folders.map(\.id), [lateID])
    XCTAssertNil(merged.folders.first?.parentID)
    XCTAssertNil(merged.primaryFolder(for: recipeID))
    XCTAssertThrowsError(try merged.prepare(.create(id: parentID, name: "Again", parentID: nil)))
    XCTAssertThrowsError(try merged.prepare(.assign(recipeID: recipeID, folderID: childID)))
  }

  func testConcurrentSiblingNamesRequireRecoveryAndRenameResolvesWithoutChangingMembership() throws {
    let kitchenID = Kitchen.ID()
    let leftID = Folder.ID()
    let rightID = Folder.ID()
    let empty = try FolderLibrary(kitchenID: kitchenID, commands: [])
    let left = try empty.prepare(.create(id: leftID, name: "Soups", parentID: nil))
    let right = try empty.prepare(.create(id: rightID, name: "SOUPS", parentID: nil))
    let collided = try FolderLibrary(kitchenID: kitchenID, commands: [right, left])
    XCTAssertEqual(collided.collisions.count, 1)
    XCTAssertEqual(Set(collided.collisions.flatMap(\.folderIDs)), [leftID, rightID])
    let rename = try collided.prepare(.rename(id: rightID, name: "Stews"))
    let repaired = try FolderLibrary(kitchenID: kitchenID, commands: [rename, right, left])
    XCTAssertTrue(repaired.collisions.isEmpty)
    XCTAssertEqual(repaired.folders.first(where: { $0.id == rightID })?.name, "Stews")
  }

  func testConfirmedMergeDefaultsToOlderIdentityUnionsContentsAndLeavesNestedCollisionSeparate() throws {
    let kitchenID = Kitchen.ID()
    let oldID = Folder.ID()
    let newID = Folder.ID()
    let oldChildID = Folder.ID()
    let newChildID = Folder.ID()
    let recipeID = Recipe.ID()
    let empty = try FolderLibrary(kitchenID: kitchenID, commands: [])
    let old = try empty.prepare(.create(id: oldID, name: "Meals", parentID: nil),
                                at: Date(timeIntervalSince1970: 1))
    let new = try empty.prepare(.create(id: newID, name: "Meals", parentID: nil),
                                at: Date(timeIntervalSince1970: 2))
    let roots = try FolderLibrary(kitchenID: kitchenID, commands: [old, new])
    let oldChild = try roots.prepare(.create(id: oldChildID, name: "Soups", parentID: oldID))
    let newChild = try roots.prepare(.create(id: newChildID, name: "Soups", parentID: newID))
    let assignment = try roots.prepare(.assign(recipeID: recipeID, folderID: newID))
    let baseline = [old, new, oldChild, newChild, assignment]
    let collided = try FolderLibrary(kitchenID: kitchenID, commands: baseline)
    let merge = try collided.prepare(.merge(ids: [oldID, newID], survivorID: nil, name: "Meals"))
    let merged = try FolderLibrary(kitchenID: kitchenID, commands: [merge] + baseline.reversed())
    XCTAssertEqual(merged.canonicalFolderID(for: newID), oldID)
    XCTAssertEqual(merged.primaryFolder(for: recipeID), oldID)
    XCTAssertEqual(merged.subtree(of: oldID), [oldID, oldChildID, newChildID])
    XCTAssertEqual(merged.collisions.count, 1)
    XCTAssertEqual(Set(merged.collisions.flatMap(\.folderIDs)), [oldChildID, newChildID])
  }

  func testManualNeighborOrderSurvivesAlphabeticalModeAndNewFoldersAppend() throws {
    let kitchenID = Kitchen.ID()
    let alphaID = Folder.ID()
    let betaID = Folder.ID()
    let gammaID = Folder.ID()
    var commands: [FolderCommand] = []
    for (id, name) in [(alphaID, "Alpha"), (betaID, "Beta")] {
      let library = try FolderLibrary(kitchenID: kitchenID, commands: commands)
      commands.append(try library.prepare(.create(id: id, name: name, parentID: nil)))
    }
    var library = try FolderLibrary(kitchenID: kitchenID, commands: commands)
    XCTAssertEqual(library.children(of: nil).map(\.id), [alphaID, betaID])
    commands.append(try library.prepare(.reorder(id: betaID, afterID: nil)))
    library = try FolderLibrary(kitchenID: kitchenID, commands: commands)
    commands.append(try library.prepare(.ordering(.manual)))
    library = try FolderLibrary(kitchenID: kitchenID, commands: commands)
    XCTAssertEqual(library.children(of: nil).map(\.id), [betaID, alphaID])
    commands.append(try library.prepare(.ordering(.alphabetical)))
    library = try FolderLibrary(kitchenID: kitchenID, commands: commands)
    XCTAssertEqual(library.children(of: nil).map(\.id), [alphaID, betaID])
    commands.append(try library.prepare(.create(id: gammaID, name: "Aardvark", parentID: nil),
                                        at: Date(timeIntervalSince1970: 0)))
    library = try FolderLibrary(kitchenID: kitchenID, commands: commands)
    commands.append(try library.prepare(.ordering(.manual)))
    library = try FolderLibrary(kitchenID: kitchenID, commands: commands)
    XCTAssertEqual(library.children(of: nil).map(\.id), [betaID, alphaID, gammaID])
  }

}
