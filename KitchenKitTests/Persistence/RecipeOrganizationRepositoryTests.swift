// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class RecipeOrganizationRepositoryTests: XCTestCase {
  func testFirstSaveAndOrganizationRollbackTogetherAndRetryIsExact() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let repository = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try recipes.save(kitchen)
    let folderID = Folder.ID()
    let tagID = Tag.ID()
    try repository.accept(
      repository.load(in: kitchen.id).prepare(folder: .create(id: folderID, name: "Meals", parentID: nil)))
    try repository.accept(repository.load(in: kitchen.id).prepare(tag: .create(id: tagID, name: "Quick")))
    let save = try RecipeEditor(repository: recipes).prepareSave(in: kitchen.id, from: RecipeDraft(title: "Soup"),
                                                               original: nil, observedSelectionIDs: [])
    let observed = try repository.load(in: kitchen.id)
    let batch = try observed.prepare(.init(folderID: folderID, tagIDs: [tagID]), for: save.recipe.id,
                                     id: save.id.rawValue, at: save.savedAt)
    let foreign = Kitchen(name: "Away")
    try recipes.save(foreign)
    let badTag = try observed.tags.prepare(.assign(recipeID: Recipe.ID(), tagID: tagID))
    let invalid = RecipeOrganizationCommand(id: UUID(), kitchenID: kitchen.id, authoredAt: Date(),
                                           folders: batch.folders, tags: [badTag])
    XCTAssertThrowsError(try repository.accept(invalid, firstSave: save))
    XCTAssertNil(try recipes.recipe(id: save.recipe.id))
    XCTAssertNil(try repository.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id))
    try repository.accept(batch, firstSave: save)
    try repository.accept(batch, firstSave: save)
    XCTAssertEqual(try recipes.recipe(id: save.recipe.id)?.revision.title, "Soup")
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id), folderID)
    XCTAssertEqual(try repository.load(in: kitchen.id).tags.tagIDs(for: save.recipe.id), [tagID])
    let changed = RecipeOrganizationCommand(id: batch.id, kitchenID: kitchen.id, authoredAt: batch.authoredAt,
                                           folders: [], tags: [])
    XCTAssertThrowsError(try repository.accept(changed, firstSave: save))
    XCTAssertThrowsError(try repository.accept(batch))
    let wrong = RecipeOrganizationCommand(id: UUID(), kitchenID: foreign.id, authoredAt: Date(),
                                         folders: batch.folders, tags: batch.tags)
    XCTAssertThrowsError(try repository.accept(wrong))
    let wrongSave = RecipeOrganizationCommand(
      id: UUID(), kitchenID: foreign.id, authoredAt: Date(), folders: [], tags: [])
    XCTAssertThrowsError(try repository.accept(wrongSave, firstSave: save))
  }

  func testBulkClassificationMoveRemovalAndStableBatchIdentity() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let repository = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try recipes.save(kitchen)
    let folder = Folder.ID(), tag = Tag.ID()
    try repository.accept(
      repository.load(in: kitchen.id).prepare(folder: .create(id: folder, name: "Meals", parentID: nil)))
    try repository.accept(repository.load(in: kitchen.id).prepare(tag: .create(id: tag, name: "Weeknight")))
    var ids: Set<Recipe.ID> = []
    for index in 0..<20 {
      let save = try RecipeEditor(repository: recipes).prepareSave(in: kitchen.id,
        from: RecipeDraft(title: "Meal \(index)"), original: nil, observedSelectionIDs: [])
      try recipes.save(save); ids.insert(save.recipe.id)
    }
    let observed = try repository.load(in: kitchen.id)
    let root = UUID(), date = Date()
    let batch = try observed.move(ids, to: folder, id: root, at: date)
    XCTAssertEqual(batch, try observed.move(Set(ids.reversed()), to: folder, id: root, at: date))
    try repository.accept(batch)
    let invalid = try observed.move(ids.union([Recipe.ID()]), to: nil)
    XCTAssertThrowsError(try repository.accept(invalid))
    let moved = try repository.load(in: kitchen.id)
    for id in ids { XCTAssertEqual(moved.folders.primaryFolder(for: id), folder) }
    let classified = try moved.classify(ids, tagID: tag, adding: true)
    try repository.accept(classified)
    try repository.accept(classified)
    let tagged = try repository.load(in: kitchen.id)
    for id in ids { XCTAssertEqual(tagged.tags.tagIDs(for: id), [tag]) }
    try repository.accept(tagged.classify(ids, tagID: tag, adding: false))
    let removed = try repository.load(in: kitchen.id)
    for id in ids { XCTAssertTrue(removed.tags.tagIDs(for: id).isEmpty) }
    XCTAssertThrowsError(try RecipeOrganization(folders: observed.folders,
      tags: TagLibrary(kitchenID: Kitchen.ID(), commands: [])))
  }
}
