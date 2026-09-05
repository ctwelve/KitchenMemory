// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

@MainActor
final class RecipeDraftsTests: XCTestCase {
  func testOnlyExplicitPurgeCanReplaceAnUnreadableDraftDocument() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                                samples: EmptyDraftSamples(), importer: RecipeImportService())
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("drafts.json")
    let original = Data("incomplete document".utf8)
    try original.write(to: url)
    let drafts = RecipeDrafts(library: library, store: FileRecipeEditingStore(url: url))
    XCTAssertFalse(drafts.storageIsAvailable)
    XCTAssertNil(drafts.begin())
    XCTAssertFalse(drafts.prepareToLeave())
    XCTAssertEqual(try Data(contentsOf: url), original)
    XCTAssertTrue(drafts.purge())
    XCTAssertTrue(drafts.storageIsAvailable)
    XCTAssertTrue(try FileRecipeEditingStore(url: url).load().isEmpty)
    XCTAssertNotNil(drafts.begin())
  }

  func testImportCandidatesDeduplicateAndAcceptLocallyBeforeExplicitSave() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                                samples: EmptyDraftSamples(), importer: RecipeImportService())
    let store = VolatileRecipeEditingStore()
    let drafts = RecipeDrafts(library: library, store: store)
    let option = RecipeImportOption(id: .init(blockIndex: 0, objectIndex: 0),
                                    draft: RecipeDraft(title: "Soup"), concerns: [.missingInstructions])
    try drafts.stage([option, option])
    let candidate = try XCTUnwrap(drafts.drafts.first)
    XCTAssertEqual(drafts.drafts.count, 1)
    XCTAssertNil(drafts.save(candidate.id))
    let reopened = RecipeDrafts(library: library, store: store)
    XCTAssertTrue(reopened.accept(candidate.id))
    XCTAssertTrue(reopened.accept(candidate.id))
    XCTAssertEqual(reopened.drafts.first?.id, candidate.id)
    XCTAssertEqual(reopened.drafts.first?.concerns, option.concerns)
    XCTAssertTrue(try library.load().recipes.isEmpty)
    XCTAssertTrue(try XCTUnwrap(reopened.save(candidate.id)).removedDraft)
    XCTAssertEqual(try library.load().recipes.first?.revision.title, "Soup")
  }

  func testInvalidTextAutosavesAndRelaunchRestoresTheSameLocalDraft() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                                samples: EmptyDraftSamples(), importer: RecipeImportService())
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("drafts.json")
    let drafts = RecipeDrafts(library: library, store: FileRecipeEditingStore(url: url))
    let draft = try XCTUnwrap(drafts.begin())
    draft.session.title = "Soup in progress"
    draft.session.prepMinutes = "half an hour?"
    draft.session.sourceURL = "unfinished link"
    draft.session.equipment = [EquipmentItem(originalText: "some kind of strainer", name: "")]
    XCTAssertTrue(drafts.prepareToLeave())
    let second = try XCTUnwrap(drafts.begin())
    second.session.title = "Another recipe"
    let relaunched = RecipeDrafts(library: library, store: FileRecipeEditingStore(url: url))
    XCTAssertEqual(relaunched.drafts.count, 2)
    XCTAssertEqual(relaunched.drafts.first?.session, draft.session)
    XCTAssertEqual(relaunched.drafts.last?.session.title, "Another recipe")
    XCTAssertEqual(relaunched.drafts.first?.id, draft.id)
    XCTAssertEqual(relaunched.drafts.first?.session.prepMinutes, "half an hour?")
    XCTAssertFalse(try XCTUnwrap(relaunched.drafts.first).canSaveRevision)
    XCTAssertTrue(try library.load().recipes.isEmpty)
  }
}

@MainActor
private struct EmptyDraftSamples: SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] { [] }
}
