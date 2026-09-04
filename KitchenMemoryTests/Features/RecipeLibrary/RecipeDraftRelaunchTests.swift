// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

@MainActor
final class RecipeDraftRelaunchTests: XCTestCase {
  func testRetryRecoversTransientReadFailureWithoutOverwritingRetainedWork() throws {
    let app = try AppRuntime.testing()
    let store = FailingRecipeEditingStore()
    let original = try library(app, store: store)
    original.beginEditing()
    original.editor?.session.title = "Keep this draft"
    store.refusesReads = true
    let relaunched = try library(app, store: store)
    XCTAssertFalse(relaunched.editingStorageIsAvailable)
    store.refusesReads = false
    relaunched.retryEditingStorage()
    XCTAssertTrue(relaunched.editingStorageIsAvailable)
    XCTAssertEqual(relaunched.editingDrafts.first?.session.title, "Keep this draft")
    relaunched.retryEditingStorage()
    XCTAssertFalse(relaunched.editingStorageFailed)
  }

  func testDraftSaveKeepsObservedAncestryWhenAnotherRevisionArrives() throws {
    let app = try AppRuntime.testing()
    let model = try library(app, store: VolatileRecipeEditingStore())
    let original = try XCTUnwrap(model.recipes.first)
    model.beginEditing(original)
    model.editor?.session.title = "Local branch"
    let elsewhere = try RecipeEditor(repository: app.recipeRepository).revise(
      recipeID: original.id, from: RecipeDraft(title: "Another branch")
    )
    XCTAssertTrue(model.saveEditor())
    let revisions = try app.recipeRepository.revisions(for: original.id)
    XCTAssertTrue(revisions.contains(original.revision))
    XCTAssertTrue(revisions.contains(elsewhere.revision))
    XCTAssertTrue(revisions.contains { $0.title == "Local branch" })
    guard case .recovery(.competingSelections) = try app.recipeRepository.recipeAuthority(id: original.id)
    else { return XCTFail("Concurrent selection must remain explicit") }
  }

  func testExistingRecipeReusesOneDraftAcrossCloseAndRelaunch() throws {
    let app = try AppRuntime.testing()
    let store = VolatileRecipeEditingStore()
    let model = try library(app, store: store)
    let recipe = try XCTUnwrap(model.recipes.first)
    model.beginEditing(recipe)
    let draft = try XCTUnwrap(model.editor)
    draft.session.summary = "Retained change"
    draft.session.equipment = [EquipmentItem(originalText: "the old skillet", name: "")]
    model.closeEditor()
    let relaunched = try library(app, store: store)
    relaunched.beginEditing(recipe)
    XCTAssertEqual(relaunched.editor?.id, draft.id)
    XCTAssertEqual(relaunched.editor?.session.summary, "Retained change")
    XCTAssertEqual(relaunched.editor?.session.equipment, draft.session.equipment)
    XCTAssertEqual(relaunched.editingDrafts.count, 1)
    relaunched.discardEditor(confirmed: true)
    XCTAssertTrue(try store.load().isEmpty)
  }

  func testDraftWriteFailurePreventsPublicationAndKeepsEditorOpen() throws {
    let app = try AppRuntime.testing()
    let store = FailingRecipeEditingStore()
    let model = try library(app, store: store)
    let initialCount = model.recipes.count
    model.beginEditing()
    store.refusesWrites = true
    model.editor?.session.title = "Still only local"
    model.editor?.session.equipment = [EquipmentItem(originalText: "a broad pan", name: "")]
    XCTAssertTrue(model.editingStorageFailed)
    model.closeEditor()
    XCTAssertNotNil(model.editor)
    XCTAssertFalse(model.selectRecipeForReading(model.recipes.first?.id))
    XCTAssertNotNil(model.editor)
    XCTAssertFalse(model.saveEditor())
    XCTAssertEqual(try app.recipeRepository.recipes(in: kitchenID(app)).count, initialCount)
    store.refusesWrites = false
    XCTAssertTrue(model.saveEditor())
    XCTAssertEqual(model.recipes.first { $0.revision.title == "Still only local" }?
      .revision.equipment.first?.originalText, "a broad pan")
    XCTAssertFalse(model.editingStorageFailed)
    XCTAssertTrue(try store.load().isEmpty)
  }

  func testUnreadableDraftDocumentIsRetainedAndNeverOverwrittenAsEmpty() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("drafts.json")
    let original = Data("incomplete document".utf8)
    try original.write(to: url)
    let app = try AppRuntime.testing()
    let model = try library(app, store: FileRecipeEditingStore(url: url))
    XCTAssertTrue(model.editingStorageFailed)
    model.beginEditing()
    XCTAssertNil(model.editor)
    XCTAssertFalse(model.persistEditingDrafts())
    XCTAssertEqual(try Data(contentsOf: url), original)
    XCTAssertTrue(model.resetKitchen(), "An explicit reset must also clear unreadable local editing data")
    XCTAssertTrue(try FileRecipeEditingStore(url: url).load().isEmpty)
    model.beginEditing()
    XCTAssertNotNil(model.editor)
  }

  func testKitchenResetClearsLocalDraftsAlongWithSharedContents() throws {
    let app = try AppRuntime.testing()
    let store = VolatileRecipeEditingStore()
    let model = try library(app, store: store)
    model.beginEditing()
    model.editor?.session.title = "Reset should discard this"
    XCTAssertTrue(model.resetKitchen())
    XCTAssertNil(model.editor)
    XCTAssertTrue(model.editingDrafts.isEmpty)
    XCTAssertTrue(try store.load().isEmpty)
  }

  func testRelaunchRetriesCommittedSaveAfterDraftCleanupFailureWithoutDuplicatingRecipe() throws {
    let app = try AppRuntime.testing()
    let store = FailingRecipeEditingStore()
    let model = try library(app, store: store)
    let initialCount = model.recipes.count
    model.beginEditing()
    let draft = try XCTUnwrap(model.editor)
    draft.session.title = "One durable new recipe"
    store.refusesRemoval = true
    XCTAssertFalse(model.saveEditor())
    XCTAssertNotNil(model.editor)
    XCTAssertEqual(try app.recipeRepository.recipes(in: kitchenID(app)).count, initialCount + 1)

    let relaunched = try library(app, store: store)
    relaunched.resumeEditingDraft(draft.id)
    store.refusesRemoval = false
    XCTAssertTrue(relaunched.saveEditor())
    XCTAssertTrue(relaunched.editingDrafts.isEmpty)
    XCTAssertEqual(try app.recipeRepository.recipes(in: kitchenID(app)).count, initialCount + 1)
  }

  func testAtomicAutosaveRestoresIndependentNewDraftsIncludingInvalidText() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("drafts.json")
    let app = try AppRuntime.testing()
    let model = try library(app, store: FileRecipeEditingStore(url: url))
    model.beginEditing()
    let first = try XCTUnwrap(model.editor)
    first.session.title = "Soup in progress"
    first.session.prepMinutes = "half an hour?"
    first.session.sourceURL = "unfinished link"
    first.session.equipment = [EquipmentItem(originalText: "some kind of strainer", name: "")]
    model.closeEditor()
    model.beginEditing()
    let second = try XCTUnwrap(model.editor)
    second.session.title = "Another recipe"

    let relaunched = try library(app, store: FileRecipeEditingStore(url: url))
    XCTAssertEqual(relaunched.editingDrafts.count, 2)
    relaunched.resumeEditingDraft(first.id)
    XCTAssertEqual(relaunched.editor?.session, first.session)
    XCTAssertFalse(try XCTUnwrap(relaunched.editor).session.canSave)
    relaunched.resumeEditingDraft(second.id)
    XCTAssertEqual(relaunched.editor?.session.title, "Another recipe")
    XCTAssertEqual(try app.recipeRepository.recipes(in: kitchenID(app)).count, model.recipes.count)
  }

  private func kitchenID(_ app: PreparedApp) throws -> Kitchen.ID {
    try XCTUnwrap(app.recipeRepository.kitchens().first?.id)
  }

  private func library(_ app: PreparedApp, store: any RecipeEditingStoring) throws -> RecipeLibraryModel {
    let model = RecipeLibraryModel(
      library: RecipeLibrary(
        kitchenID: try kitchenID(app), repository: app.recipeRepository,
        samples: BundledSampleRecipeProvider(), importer: RecipeImportService()
      ),
      samplePreferences: VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted),
      kitchenWasCreated: false,
      editingStore: store
    )
    model.loadIfNeeded()
    return model
  }
}

@MainActor
private final class FailingRecipeEditingStore: RecipeEditingStoring {
  var refusesReads = false
  var refusesRemoval = false
  var refusesWrites = false
  private var drafts: [RecipeEditingRecord] = []
  func load() throws -> [RecipeEditingRecord] {
    if refusesReads { throw CocoaError(.fileReadUnknown) }
    return drafts
  }
  func save(_ drafts: [RecipeEditingRecord]) throws {
    if refusesWrites { throw CocoaError(.fileWriteUnknown) }
    if refusesRemoval, drafts.count < self.drafts.count {
      throw CocoaError(.fileWriteUnknown)
    }
    self.drafts = drafts
  }
}
