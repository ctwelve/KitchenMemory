// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

@MainActor
final class RecipeDraftFailureTests: XCTestCase {
  func testFailedTypingKeepsLatestTextAndVetoesLeavingPublicationDiscardAndPurge() throws {
    let library = try makeLibrary()
    let store = DraftFailureStore()
    let drafts = RecipeDrafts(library: library, store: store)
    let draft = try XCTUnwrap(drafts.begin())
    store.refusesWrites = true
    draft.session.title = "Latest text"
    XCTAssertEqual(draft.session.title, "Latest text")
    XCTAssertTrue(drafts.storageFailed)
    XCTAssertFalse(drafts.prepareToLeave())
    XCTAssertNil(drafts.save(draft.id))
    XCTAssertTrue(try library.load().recipes.isEmpty)
    XCTAssertFalse(drafts.discard(draft.id))
    XCTAssertFalse(drafts.purge())
    XCTAssertEqual(drafts.drafts.first?.id, draft.id)
    store.refusesWrites = false
    drafts.retryStorage()
    XCTAssertFalse(drafts.storageFailed)
    let reopened = RecipeDrafts(library: library, store: store)
    XCTAssertEqual(reopened.drafts.first?.session.title, "Latest text")
    XCTAssertTrue(try XCTUnwrap(reopened.save(draft.id)).removedDraft)
    XCTAssertEqual(try library.load().recipes.count, 1)
  }

  func testUnavailableStorageRetryReadsRetainedDraftsInsteadOfWritingEmptyContents() throws {
    let library = try makeLibrary()
    let store = DraftFailureStore()
    let original = RecipeDrafts(library: library, store: store)
    let draft = try XCTUnwrap(original.begin())
    draft.session.title = "Keep this"
    store.refusesReads = true
    let reopened = RecipeDrafts(library: library, store: store)
    XCTAssertFalse(reopened.storageIsAvailable)
    XCTAssertNil(reopened.begin())
    XCTAssertFalse(reopened.persist())
    XCTAssertNil(reopened.review(RecipeImportOption(
      id: .init(blockIndex: 0, objectIndex: 0), draft: RecipeDraft(title: "Do not replace retained work"), concerns: []
    )))
    reopened.dismissStorageFailure()
    XCTAssertFalse(reopened.storageFailed)
    store.refusesReads = false
    reopened.retryStorage()
    XCTAssertTrue(reopened.storageIsAvailable)
    XCTAssertEqual(reopened.drafts.first?.session.title, "Keep this")
  }

  func testStagingAndAcceptanceRollbackInMemoryButRelaunchHandlesAmbiguousWrites() throws {
    let library = try makeLibrary()
    let store = DraftFailureStore()
    let drafts = RecipeDrafts(library: library, store: store)
    let option = RecipeImportOption(id: .init(blockIndex: 0, objectIndex: 0),
                                    draft: RecipeDraft(title: "Soup"), concerns: [.missingInstructions])
    store.failsAfterWrite = true
    XCTAssertThrowsError(try drafts.stage([option]))
    XCTAssertTrue(drafts.drafts.isEmpty)
    store.failsAfterWrite = false
    let reopened = RecipeDrafts(library: library, store: store)
    let candidate = try XCTUnwrap(reopened.review(option))
    XCTAssertEqual(reopened.drafts.count, 1)
    store.failsAfterWrite = true
    XCTAssertFalse(reopened.accept(candidate.id))
    XCTAssertTrue(candidate.isImportCandidate)
    store.failsAfterWrite = false
    let accepted = RecipeDrafts(library: library, store: store)
    XCTAssertTrue(accepted.accept(candidate.id))
    XCTAssertFalse(try XCTUnwrap(accepted.drafts.first).isImportCandidate)
    XCTAssertEqual(accepted.drafts.count, 1)
    XCTAssertTrue(try library.load().recipes.isEmpty)
    XCTAssertTrue(accepted.discard(candidate.id))
    XCTAssertTrue(RecipeDrafts(library: library, store: store).drafts.isEmpty)
  }

  func testExistingDraftKeepsOriginalAncestryAcrossAnotherRevisionAndRelaunch() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                                samples: FailureSamples(), importer: RecipeImportService())
    let original = try library.create(from: RecipeDraft(title: "Original"))
    let store = DraftFailureStore()
    let drafts = RecipeDrafts(library: library, store: store)
    let draft = try XCTUnwrap(drafts.begin(original))
    draft.session.title = "Local branch"
    draft.session.equipment = [EquipmentItem(originalText: "the old skillet", name: "")]
    XCTAssertTrue(drafts.prepareToLeave())
    let elsewhere = try library.revise(recipeID: original.id, from: RecipeDraft(title: "Elsewhere"))
    let reopened = RecipeDrafts(library: library, store: store)
    let retained = try XCTUnwrap(reopened.begin(elsewhere))
    XCTAssertEqual(retained.id, draft.id)
    XCTAssertEqual(retained.original, original)
    XCTAssertEqual(retained.session.equipment, draft.session.equipment)
    XCTAssertEqual(reopened.drafts.count, 1)
    XCTAssertTrue(try XCTUnwrap(reopened.save(retained.id)).removedDraft)
    XCTAssertEqual(try repository.revisions(for: original.id).count, 3)
    guard case .recovery(.competingSelections) = try repository.recipeAuthority(id: original.id) else {
      XCTFail("Concurrent Selection evidence must remain explicit")
      return
    }
  }

  private func makeLibrary() throws -> RecipeLibrary {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    return RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                         samples: FailureSamples(), importer: RecipeImportService())
  }
}

@MainActor
private struct FailureSamples: SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] { [] }
}

@MainActor
private final class DraftFailureStore: RecipeEditingStoring {
  var refusesReads = false
  var refusesWrites = false
  var failsAfterWrite = false
  private var records: [RecipeEditingRecord] = []
  func load() throws -> [RecipeEditingRecord] {
    if refusesReads { throw CocoaError(.fileReadUnknown) }
    return records
  }
  func save(_ drafts: [RecipeEditingRecord]) throws {
    if refusesWrites { throw CocoaError(.fileWriteUnknown) }
    records = drafts
    if failsAfterWrite { throw CocoaError(.fileWriteUnknown) }
  }
}
