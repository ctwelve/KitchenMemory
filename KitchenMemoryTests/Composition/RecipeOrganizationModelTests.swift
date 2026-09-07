// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class RecipeOrganizationModelTests: XCTestCase {
  func testLocalPreferencesFilteringDropsAndExpansionSurviveRelaunch() throws {
    let fixture = try makeTestUserDefaults(suiteNamePrefix: "organization")
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try recipes.save(kitchen)
    let recipe = try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let stored = try XCTUnwrap(recipes.recipe(id: recipe.id))
    var model = RecipeOrganizationModel(repository: repository, kitchenID: kitchen.id, defaults: fixture.defaults)
    XCTAssertTrue(model.foldersEnabled); XCTAssertTrue(model.tagsEnabled)
    let folder = Folder.ID(), tag = Tag.ID()
    model.perform { try $0.prepare(folder: .create(id: folder, name: "Dinner", parentID: nil)) }
    model.perform { try $0.prepare(tag: .create(id: tag, name: "Quick")) }
    XCTAssertTrue(model.dropRecipes(["km-recipe:" + recipe.id.rawValue.uuidString], recipes: [stored], to: folder))
    XCTAssertFalse(model.dropRecipes(["https://example.com"], recipes: [stored], to: folder))
    XCTAssertFalse(model.dropRecipes(["km-recipe:" + UUID().uuidString], recipes: [stored], to: folder))
    model.classify([recipe.id], tagID: tag, adding: true)
    model.toggleTag(tag)
    model.filter.location = .folder(folder)
    XCTAssertEqual(model.recipes([stored], locale: .current).map(\.id), [recipe.id])
    model.toggleTag(tag)
    XCTAssertTrue(model.filter.tagIDs.isEmpty)
    model.expanded = [folder]
    model.foldersEnabled = false; model.tagsEnabled = false
    model = RecipeOrganizationModel(repository: repository, kitchenID: kitchen.id, defaults: fixture.defaults)
    XCTAssertFalse(model.foldersEnabled); XCTAssertFalse(model.tagsEnabled)
    XCTAssertEqual(model.expanded, [folder])
    XCTAssertEqual(model.snapshot?.folders.primaryFolder(for: recipe.id), folder)
    XCTAssertEqual(model.snapshot?.tags.tagIDs(for: recipe.id), [tag])
    model.filter.location = .unfiled
    model.perform { try $0.prepare(folder: .systemViewVisible(false)) }
    XCTAssertEqual(model.filter.location, .all)
    model.filter.untagged = true
    model.perform { try $0.prepare(tag: .systemViewVisible(false)) }
    XCTAssertFalse(model.filter.untagged)
  }

  func testHiddenNameCollisionsStayInRecoveryAndConfirmedMergeRepairsThem() throws {
    let fixture = try makeTestUserDefaults(suiteNamePrefix: "organization-collision")
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let kitchen = Kitchen(name: "Home")
    try SwiftDataRecipeRepository(modelContainer: container).save(kitchen)
    let repository = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    let observed = try repository.load(in: kitchen.id)
    try repository.accept(observed.prepare(folder: .create(id: Folder.ID(), name: "Meals", parentID: nil)))
    try repository.accept(observed.prepare(folder: .create(id: Folder.ID(), name: "meals", parentID: nil)))
    try repository.accept(observed.prepare(tag: .create(id: Tag.ID(), name: "Quick")))
    try repository.accept(observed.prepare(tag: .create(id: Tag.ID(), name: "quick")))
    let model = RecipeOrganizationModel(repository: repository, kitchenID: kitchen.id, defaults: fixture.defaults)
    model.foldersEnabled = false; model.tagsEnabled = false
    XCTAssertEqual(model.collisionCount, 2)
    XCTAssertTrue(model.requiresRecovery)
    let collision = try XCTUnwrap(model.snapshot?.folders.collisions.first)
    model.perform { try $0.prepare(folder: .merge(ids: collision.folderIDs, survivorID: nil, name: "Meals")) }
    let tags = try XCTUnwrap(model.snapshot?.tags.collisions.first)
    model.perform { try $0.prepare(tag: .merge(ids: tags.tagIDs, survivorID: nil, name: "Quick")) }
    XCTAssertEqual(model.collisionCount, 0)
    XCTAssertFalse(model.requiresRecovery)
  }

  func testAmbiguousAcceptanceRetainsOneCommandForRelaunchRetry() throws {
    let fixture = try makeTestUserDefaults(suiteNamePrefix: "organization-retry")
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let kitchen = Kitchen(name: "Home")
    try SwiftDataRecipeRepository(modelContainer: container).save(kitchen)
    let repository = UncertainOrganizationRepository(base: SwiftDataRecipeOrganizationRepository(modelContainer: container))
    var model = RecipeOrganizationModel(repository: repository, kitchenID: kitchen.id, defaults: fixture.defaults)
    model.perform { try $0.prepare(tag: .create(id: Tag.ID(), name: "Retained")) }
    let pending = try XCTUnwrap(model.pending)
    XCTAssertTrue(model.requiresRecovery)
    model.perform { try $0.prepare(tag: .create(id: Tag.ID(), name: "Must wait")) }
    XCTAssertEqual(model.pending, pending)
    model = RecipeOrganizationModel(repository: repository, kitchenID: kitchen.id, defaults: fixture.defaults)
    XCTAssertEqual(model.pending, pending)
    repository.uncertain = false
    model.retry()
    XCTAssertNil(model.pending)
    XCTAssertEqual(model.snapshot?.tags.tags.map(\.name), ["Retained"])
    model.retry()
    fixture.defaults.set(Data([0xff]), forKey: "organization." + kitchen.id.rawValue.uuidString + ".pending")
    model = RecipeOrganizationModel(repository: repository, kitchenID: kitchen.id, defaults: fixture.defaults)
    XCTAssertTrue(model.storageInvalid)
    model.retry()
    XCTAssertTrue(model.failed)
  }
}

@MainActor
private final class UncertainOrganizationRepository: RecipeOrganizationRepository {
  let base: SwiftDataRecipeOrganizationRepository
  var uncertain = true
  init(base: SwiftDataRecipeOrganizationRepository) { self.base = base }
  func load(in kitchenID: Kitchen.ID) throws -> RecipeOrganization { try base.load(in: kitchenID) }
  func accept(_ command: RecipeOrganizationCommand, firstSave: RecipeSaveCommand?) throws {
    try base.accept(command, firstSave: firstSave)
    if uncertain { throw CocoaError(.fileWriteUnknown) }
  }
}
