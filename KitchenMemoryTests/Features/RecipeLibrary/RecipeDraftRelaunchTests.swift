// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import Observation
import XCTest

@MainActor
final class RecipeDraftRelaunchTests: XCTestCase {
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

  func testFailedLocalPurgeLeavesSharedKitchenUntouchedUntilResetRetry() throws {
    let app = try AppRuntime.testing()
    let store = FailingRecipeEditingStore()
    let model = try library(app, store: store)
    let custom = try RecipeEditor(repository: app.recipeRepository).create(
      in: kitchenID(app), from: RecipeDraft(title: "Must remain if reset cannot start")
    )
    model.reload()
    model.beginEditing(custom)
    model.editor?.session.title = "Unsaved change"
    store.refusesWrites = true
    XCTAssertFalse(model.resetKitchen())
    XCTAssertNotNil(try app.recipeRepository.recipe(id: custom.id))
    XCTAssertEqual(model.editor?.session.title, "Unsaved change")
    store.refusesWrites = false
    XCTAssertTrue(model.resetKitchen())
    XCTAssertNil(try app.recipeRepository.recipe(id: custom.id))
    XCTAssertTrue(try store.load().isEmpty)
  }

  func testNativeBindingsObserveAndEditTheSameKitchenKitDraft() throws {
    let app = try AppRuntime.testing()
    let model = app.libraryModel
    model.beginEditing()
    let editor = try XCTUnwrap(model.editor)
    let draft = try XCTUnwrap(model.drafts.drafts.first)
    XCTAssertIdentical(editor.draft, draft)
    let changed = expectation(description: "Native binding observes KitchenKit contents")
    withObservationTracking {
      _ = editor.session.title
    } onChange: {
      changed.fulfill()
    }
    draft.session.title = "Direct module edit"
    XCTAssertEqual(editor.session.title, "Direct module edit")
    editor.session.summary = "Native binding edit"
    XCTAssertEqual(draft.session.summary, "Native binding edit")
    XCTAssertIdentical(model.authoringItems.first, editor)
    wait(for: [changed], timeout: 1)
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
