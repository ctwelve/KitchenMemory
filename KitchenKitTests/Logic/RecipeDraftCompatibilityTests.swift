// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import SwiftData
import XCTest

@MainActor
final class RecipeDraftCompatibilityTests: XCTestCase {
  func testUnreadableSelectionContextCannotBeginAnUnanchoredExistingRecipeDraft() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let original = try RecipeEditor(repository: repository).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let context = ModelContext(container)
    let selection = try XCTUnwrap(try context.fetch(FetchDescriptor<RecipeSelectionRecord>()).first)
    selection.frontierFormatVersion = -1
    try context.save()
    let reopened = SwiftDataRecipeRepository(modelContainer: container)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: reopened,
                                samples: CompatibilitySamples(), importer: RecipeImportService())
    let store = VolatileRecipeEditingStore()
    let drafts = RecipeDrafts(library: library, store: store)
    XCTAssertNil(drafts.begin(original))
    XCTAssertTrue(drafts.storageFailed)
    XCTAssertTrue(drafts.drafts.isEmpty)
    XCTAssertTrue(try store.load().isEmpty)
  }

  func testLegacyPhasesAndMissingEquipmentRestoreWithoutLosingFrozenIntention() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                                samples: CompatibilitySamples(), importer: RecipeImportService())
    let original = try library.create(from: RecipeDraft(
      title: "Soup", equipment: [EquipmentItem(originalText: "Pot", name: "Pot")]
    ))
    var session = RecipeEditSession(draft: RecipeDraft(revision: original.revision))
    session.equipment = nil
    let command = try library.prepareSave(from: RecipeDraft(title: "Frozen"), original: nil,
                                          observedSelectionIDs: [])
    let store = VolatileRecipeEditingStore()
    let records = [
      RecipeEditingRecord(id: UUID(), original: original, concerns: [], session: session, observedSelectionIDs: []),
      RecipeEditingRecord(id: UUID(), original: nil, concerns: [], session: session, observedSelectionIDs: [],
                          pendingSave: command, isImportCandidate: true),
      RecipeEditingRecord(id: UUID(), original: nil, concerns: [], session: session, observedSelectionIDs: [],
                          isImportCandidate: true),
      RecipeEditingRecord(id: UUID(), original: nil, concerns: [], session: session, observedSelectionIDs: [],
                          pendingSave: command, isImportCandidate: true, phase: .editing),
    ]
    try store.save(records)
    let drafts = RecipeDrafts(library: library, store: store)
    XCTAssertEqual(drafts.drafts.map(\.phase), [.editing, .saving(command), .importCandidate, .editing])
    XCTAssertEqual(drafts.drafts.first?.session.equipment, original.revision.equipment)
    XCTAssertEqual(drafts.drafts.last?.session.equipment, [])
    XCTAssertTrue(drafts.persist())
    XCTAssertEqual(try store.load().map(\.phase), drafts.drafts.map(\.phase))
  }

  func testInvalidFileIdentityAndVersionNeverBecomeAnEmptyWritableCollection() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                                samples: CompatibilitySamples(), importer: RecipeImportService())
    let original = try library.create(from: RecipeDraft(title: "Soup"))
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileRecipeEditingStore(url: directory.appendingPathComponent("drafts.json"))
    let record = RecipeEditingRecord(id: UUID(), original: original, concerns: [],
                                    session: RecipeEditSession(draft: RecipeDraft()), observedSelectionIDs: [])
    let other = RecipeEditingRecord(id: UUID(), original: original, concerns: [],
                                   session: record.session, observedSelectionIDs: [])
    for records in [[record, record], [record, other]] {
      try store.save(records)
      let bytes = try Data(contentsOf: store.url)
      let drafts = RecipeDrafts(library: library, store: store)
      XCTAssertFalse(drafts.storageIsAvailable)
      XCTAssertFalse(drafts.persist())
      XCTAssertEqual(try Data(contentsOf: store.url), bytes)
    }
    try Data(#"{"version":2,"drafts":[]}"#.utf8).write(to: store.url)
    XCTAssertThrowsError(try store.load())
  }

  func testRejectedPublicationRetainsTheCommandUntilRepositoryCanAcceptIt() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Not yet present")
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                                samples: CompatibilitySamples(), importer: RecipeImportService())
    let store = VolatileRecipeEditingStore()
    let drafts = RecipeDrafts(library: library, store: store)
    let draft = try XCTUnwrap(drafts.begin())
    XCTAssertNil(drafts.save(draft.id), "Invalid text remains editable")
    XCTAssertNil(draft.pendingSave)
    draft.session.title = "Soup"
    XCTAssertNil(drafts.save(draft.id), "Missing Kitchen must reject publication")
    let command = try XCTUnwrap(draft.pendingSave)
    XCTAssertTrue(draft.canSaveRevision)
    try repository.save(kitchen)
    let reopened = RecipeDrafts(library: library, store: store)
    XCTAssertEqual(reopened.drafts.first?.pendingSave, command)
    XCTAssertTrue(try XCTUnwrap(reopened.save(draft.id)).removedDraft)
    XCTAssertEqual(try repository.selectionHeads(for: command.recipe.id), [command.selection.id])
    XCTAssertNil(reopened.save(draft.id))
    XCTAssertFalse(reopened.accept(draft.id))
    XCTAssertFalse(reopened.discard(draft.id))
  }
}

@MainActor
private struct CompatibilitySamples: SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] { [] }
}
