// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

@MainActor
final class RecipeDraftPublicationTests: XCTestCase {
  func testCleanupFailureRetainsFrozenSaveForExactRetryAcrossRealStoreRelaunch() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(storeURL: directory.appendingPathComponent("kitchen.store"))
    )
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                                samples: PublicationSamples(), importer: RecipeImportService())
    let store = RemovalFailingDraftStore(url: directory.appendingPathComponent("drafts.json"))
    let drafts = RecipeDrafts(library: library, store: store)
    let draft = try XCTUnwrap(drafts.begin())
    draft.session.title = "Exactly one soup"
    draft.session.media = [RecipeMedia(role: .hero, imageData: Data([1, 2, 3]))]
    store.refusesRemoval = true
    XCTAssertFalse(try XCTUnwrap(drafts.save(draft.id)).removedDraft)
    XCTAssertEqual(try library.load().recipes.count, 1)
    let command = try XCTUnwrap(draft.pendingSave)
    draft.session.title = "Must not change a frozen intention"
    XCTAssertEqual(draft.session.title, "Exactly one soup")
    let reopened = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(storeURL: directory.appendingPathComponent("kitchen.store"))
    )
    let reopenedLibrary = RecipeLibrary(kitchenID: kitchen.id, repository: reopened,
                                        samples: PublicationSamples(), importer: RecipeImportService())
    let restored = RecipeDrafts(library: reopenedLibrary, store: FileRecipeEditingStore(url: store.file.url))
    XCTAssertEqual(restored.drafts.first?.pendingSave, command)
    XCTAssertTrue(try XCTUnwrap(restored.save(draft.id)).removedDraft)
    XCTAssertTrue(restored.drafts.isEmpty)
    XCTAssertEqual(try reopenedLibrary.load().recipes.count, 1)
    XCTAssertEqual(try reopened.revisions(for: command.recipe.id), [command.revision])
    XCTAssertEqual(try reopened.selectionHeads(for: command.recipe.id), [command.selection.id])
  }
}

@MainActor
private struct PublicationSamples: SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] { [] }
}

@MainActor
private final class RemovalFailingDraftStore: RecipeEditingStoring {
  let file: FileRecipeEditingStore
  var refusesRemoval = false
  init(url: URL) { file = FileRecipeEditingStore(url: url) }
  func load() throws -> [RecipeEditingRecord] { try file.load() }
  func save(_ drafts: [RecipeEditingRecord]) throws {
    if refusesRemoval && drafts.isEmpty { throw CocoaError(.fileWriteUnknown) }
    try file.save(drafts)
  }
}
