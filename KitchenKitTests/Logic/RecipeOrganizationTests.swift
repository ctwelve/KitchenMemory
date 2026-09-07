// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import XCTest

final class RecipeOrganizationTests: XCTestCase {
  func testSystemVisibilityConvergesAndSurvivesCheckpoint() throws {
    let kitchen = Kitchen.ID()
    let folders = try FolderLibrary(kitchenID: kitchen, commands: [])
    let tags = try TagLibrary(kitchenID: kitchen, commands: [])
    XCTAssertTrue(try folders.systemViewVisible)
    XCTAssertTrue(try tags.systemViewVisible)
    let date = Date(timeIntervalSince1970: 0)
    let folderCommand = try folders.prepare(.systemViewVisible(false), at: date)
    let tagCommand = try tags.prepare(.systemViewVisible(false), at: date)
    let hiddenFolders = try FolderLibrary(kitchenID: kitchen, commands: [folderCommand])
    let hiddenTags = try TagLibrary(kitchenID: kitchen, commands: [tagCommand])
    XCTAssertFalse(try hiddenFolders.systemViewVisible)
    XCTAssertFalse(try hiddenTags.systemViewVisible)
    let later = Date(timeIntervalSince1970: 40 * 86_400)
    let folderCheckpoint = try XCTUnwrap(hiddenFolders.checkpoint(at: later))
    let tagCheckpoint = try XCTUnwrap(hiddenTags.checkpoint(at: later))
    XCTAssertFalse(
      try FolderLibrary(kitchenID: kitchen, commands: [], checkpoints: [folderCheckpoint]).systemViewVisible)
    XCTAssertFalse(try TagLibrary(kitchenID: kitchen, commands: [], checkpoints: [tagCheckpoint]).systemViewVisible)
    XCTAssertTrue(try FolderLibrary(kitchenID: kitchen, commands: [folderCommand,
      hiddenFolders.prepare(.systemViewVisible(true)),
    ]).systemViewVisible)
    XCTAssertTrue(try TagLibrary(kitchenID: kitchen, commands: [tagCommand,
      hiddenTags.prepare(.systemViewVisible(true)),
    ]).systemViewVisible)
  }

  func testFolderSubtreeTagsSearchAndDisabledPresentationIntersect() throws {
    let kitchen = Kitchen.ID(), parent = Folder.ID(), child = Folder.ID(), tag = Tag.ID(), second = Tag.ID()
    let recipes = (0..<3).map { index -> StoredRecipe in
      let id = Recipe.ID(), revision = RecipeRevision(recipeID: Recipe.ID(), revisionNumber: 1, title: "Unused")
      let content = RecipeRevision(id: revision.id, recipeID: id, revisionNumber: 1,
                                   title: index == 0 ? "Crème soup" : "Rice")
      return StoredRecipe(recipe: Recipe(id: id, kitchenID: kitchen, currentRevisionID: content.id), revision: content)
    }
    var folderCommands: [FolderCommand] = []
    func folder(_ intent: FolderIntent) throws {
      folderCommands.append(try FolderLibrary(kitchenID: kitchen, commands: folderCommands).prepare(intent))
    }
    try folder(.create(id: parent, name: "Meals", parentID: nil))
    try folder(.create(id: child, name: "Soups", parentID: parent))
    try folder(.assign(recipeID: recipes[0].id, folderID: child))
    var tagCommands: [TagCommand] = []
    func classify(_ intent: TagIntent) throws {
      tagCommands.append(try TagLibrary(kitchenID: kitchen, commands: tagCommands).prepare(intent))
    }
    try classify(.create(id: tag, name: "Quick")); try classify(.create(id: second, name: "Warm"))
    try classify(.assign(recipeID: recipes[0].id, tagID: tag))
    try classify(.assign(recipeID: recipes[0].id, tagID: second))
    try classify(.assign(recipeID: recipes[1].id, tagID: tag))
    let organization = try RecipeOrganization(folders: FolderLibrary(kitchenID: kitchen, commands: folderCommands),
                                              tags: TagLibrary(kitchenID: kitchen, commands: tagCommands))
    var filter = RecipeOrganizationFilter()
    func result(folders: Bool = true, tags: Bool = true) -> [Recipe.ID] {
      filter.apply(to: recipes, organization: organization, foldersEnabled: folders, tagsEnabled: tags,
                   locale: Locale(identifier: "en_US")).map(\.id)
    }
    XCTAssertEqual(result(), recipes.map(\.id))
    filter.location = .folder(parent); filter.tagIDs = [tag, second]; filter.search = "creme"
    XCTAssertEqual(result(), [recipes[0].id])
    filter.search = "rice"; XCTAssertTrue(result().isEmpty)
    filter.search = ""; filter.location = .unfiled
    XCTAssertTrue(result().isEmpty)
    filter.tagIDs = []; XCTAssertEqual(result(), [recipes[1].id, recipes[2].id])
    filter.untagged = true; XCTAssertEqual(result(), [recipes[2].id])
    filter.location = .folder(Folder.ID()); XCTAssertTrue(result().isEmpty)
    XCTAssertEqual(result(folders: false), [recipes[2].id])
    filter.tagIDs = [Tag.ID()]; XCTAssertTrue(result(folders: false).isEmpty)
    XCTAssertEqual(result(folders: false, tags: false), recipes.map(\.id))
  }

  func testFolderDestinationsDisambiguatePathsAndKeepStableCollisionOrder() throws {
    let kitchen = Kitchen.ID()
    let empty = try FolderLibrary(kitchenID: kitchen, commands: [])
    XCTAssertTrue(empty.outline(expanded: [], locale: .current).isEmpty)
    var commands: [FolderCommand] = []
    let home = Folder.ID(), camping = Folder.ID(), homeMeals = Folder.ID(), campingMeals = Folder.ID()
    let intents: [FolderIntent] = [.create(id: home, name: "Home", parentID: nil),
      .create(id: camping, name: "Camping", parentID: nil),
      .create(id: homeMeals, name: "Meals", parentID: home),
      .create(id: campingMeals, name: "Meals", parentID: camping),
    ]
    for intent in intents {
      commands.append(try FolderLibrary(kitchenID: kitchen, commands: commands).prepare(intent))
    }
    let library = try FolderLibrary(kitchenID: kitchen, commands: commands)
    let destinations = library.destinations(locale: .current)
    XCTAssertEqual(destinations.map(\.path), ["Camping", "Camping / Meals", "Home", "Home / Meals"])
    XCTAssertEqual(destinations.map(\.id), [camping, campingMeals, home, homeMeals])
    let duplicate = Folder.ID()
    commands.append(try empty.prepare(.create(id: duplicate, name: "Home", parentID: nil)))
    let collided = try FolderLibrary(kitchenID: kitchen, commands: commands).outline(expanded: [], locale: .current)
    XCTAssertEqual(
      Array(collided.map(\.id).suffix(2)), [home, duplicate].sorted { $0.rawValue.uuidString < $1.rawValue.uuidString })
  }

  func testOutlinePreservesOrderAndHandlesDeepHierarchyIteratively() throws {
    let kitchen = Kitchen.ID()
    var commands: [FolderCommand] = []
    var parent: Folder.ID?
    var ids: Set<Folder.ID> = []
    // Build a causal chain directly so fixture construction does not dominate the traversal proof.
    for index in 0..<300 {
      let id = Folder.ID()
      let action = OrganizationAction(id: UUID(), authoredAt: Date(timeIntervalSince1970: 0),
        observed: commands.last.map { [$0.id] } ?? [],
        payload: FolderChange.create(id: id, name: "Level \(index)", parentID: parent))
      commands.append(FolderCommand(kitchenID: kitchen, action: action)); ids.insert(id); parent = id
    }
    let rootSibling = Folder.ID()
    commands.append(
      try FolderLibrary(kitchenID: kitchen, commands: commands).prepare(
        .create(id: rootSibling, name: "A", parentID: nil)))
    let library = try FolderLibrary(kitchenID: kitchen, commands: commands)
    let rows = library.outline(expanded: ids, locale: Locale(identifier: "en_US"))
    XCTAssertEqual(library.destinations(locale: .current).last?.path.components(separatedBy: " / ").count, 300)
    XCTAssertEqual(rows.count, 301)
    XCTAssertEqual(rows.first?.id, rootSibling)
    XCTAssertEqual(rows.last?.depth, 299)
    XCTAssertEqual(library.outline(expanded: [], locale: .current).count, 2)
    commands.append(try library.prepare(.ordering(.manual)))
    let manual = try FolderLibrary(kitchenID: kitchen, commands: commands)
    XCTAssertEqual(manual.outline(expanded: [], locale: .current).last?.id, rootSibling)
  }
}
