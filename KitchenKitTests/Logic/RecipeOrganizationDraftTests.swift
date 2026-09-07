// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import XCTest

@MainActor
final class RecipeOrganizationDraftTests: XCTestCase {
  func testPendingOrganizationSurvivesDraftRelaunchAndFrozenPublicationRetry() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let container = try KitchenMemorySchema.makeContainer(storeURL: directory.appendingPathComponent("Kitchen.store"))
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let organization = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try recipes.save(kitchen)
    let folder = Folder.ID(), tag = Tag.ID(), secondTag = Tag.ID()
    try organization.accept(
      organization.load(in: kitchen.id).prepare(folder: .create(id: folder, name: "Dinner", parentID: nil)))
    try organization.accept(organization.load(in: kitchen.id).prepare(tag: .create(id: tag, name: "Quick")))
    try organization.accept(organization.load(in: kitchen.id).prepare(tag: .create(id: secondTag, name: "Family")))
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: recipes, samples: OrganizationDraftSamples(),
      importer: RecipeImportService(), organizationRepository: organization)
    let store = OrganizationDraftStore(url: directory.appendingPathComponent("Drafts.json"))
    var drafts = RecipeDrafts(library: library, store: store)
    let first = try XCTUnwrap(drafts.begin())
    first.session.title = "Soup"
    first.organization = .init(folderID: folder, tagIDs: [tag, secondTag])
    drafts = RecipeDrafts(library: library, store: store)
    let restored = try XCTUnwrap(drafts.drafts.first)
    XCTAssertEqual(restored.organization, first.organization)
    store.refusesRemoval = true
    XCTAssertFalse(try XCTUnwrap(drafts.save(restored.id)).removedDraft)
    let save = try XCTUnwrap(restored.pendingSave)
    let batch = try XCTUnwrap(restored.pendingOrganization)
    restored.organization = .init()
    XCTAssertEqual(restored.organization, first.organization)
    drafts = RecipeDrafts(library: library, store: store)
    XCTAssertEqual(drafts.drafts.first?.pendingOrganization, batch)
    store.refusesRemoval = false
    XCTAssertTrue(try XCTUnwrap(drafts.save(restored.id)).removedDraft)
    XCTAssertEqual(try organization.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id), folder)
    XCTAssertEqual(try organization.load(in: kitchen.id).tags.tagIDs(for: save.recipe.id), [tag, secondTag])
    let original = try XCTUnwrap(recipes.recipe(id: save.recipe.id))
    let editing = try XCTUnwrap(drafts.begin(original))
    editing.organization = .init(folderID: folder)
    XCTAssertEqual(editing.organization, PendingRecipeOrganization())
    try organization.accept(organization.load(in: kitchen.id).move([original.id], to: nil))
    editing.session.title = "Revised soup"
    XCTAssertNotNil(drafts.save(editing.id))
    XCTAssertNil(try organization.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id))
    XCTAssertEqual(try organization.load(in: kitchen.id).tags.tagIDs(for: save.recipe.id), [tag, secondTag])
  }

  func testAbsentAdapterCannotSilentlyDiscardPendingOrganization() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository, samples: OrganizationDraftSamples(),
                                importer: RecipeImportService())
    let save = try library.prepareSave(from: RecipeDraft(title: "Soup"), original: nil, observedSelectionIDs: [])
    XCTAssertNil(try library.prepareOrganization(.init(), for: save))
    XCTAssertThrowsError(try library.prepareOrganization(.init(folderID: Folder.ID()), for: save))
    let observed = try RecipeOrganization(folders: FolderLibrary(kitchenID: kitchen.id, commands: []),
                                          tags: TagLibrary(kitchenID: kitchen.id, commands: []))
    XCTAssertThrowsError(try library.save(save, organization: observed.move([], to: nil)))
  }
}

@MainActor
private struct OrganizationDraftSamples: SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] { [] }
}

@MainActor
private final class OrganizationDraftStore: RecipeEditingStoring {
  let file: FileRecipeEditingStore
  var refusesRemoval = false
  init(url: URL) { file = FileRecipeEditingStore(url: url) }
  func load() throws -> [RecipeEditingRecord] { try file.load() }
  func save(_ drafts: [RecipeEditingRecord]) throws {
    if refusesRemoval && drafts.isEmpty { throw CocoaError(.fileWriteUnknown) }
    try file.save(drafts)
  }
}
