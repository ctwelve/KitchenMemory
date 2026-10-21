// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class OrganizationHistoryPresentationTests: XCTestCase {
  func testSingleRecipeMoveAndRestoredSceneUndoPreserveNavigation() async throws {
    let app = try AppRuntime.testing()
    let library = app.libraryModel
    library.loadIfNeeded()
    let organization = try XCTUnwrap(library.organization)
    let recipe = try XCTUnwrap(library.recipes.first)
    let folder = Folder.ID()
    organization.perform { try $0.prepare(folder: .create(id: folder, name: "Dinner", parentID: nil)) }
    let sceneID = UUID()
    let history = app.organizationHistory.presentation(for: sceneID)
    history.updateLocale(Locale(identifier: "en-US"))
    await history.open()
    let destination = library.navigation.destination
    await organization.move([recipe.id], to: folder, history: history)
    XCTAssertEqual(organization.snapshot?.folders.primaryFolder(for: recipe.id), folder)
    XCTAssertTrue(history.canUndo)
    XCTAssertEqual(history.nativeUndoManager?.undoActionName, "Move Recipe")
    await organization.move([recipe.id], to: folder, history: history)
    await history.undo()
    XCTAssertNil(organization.snapshot?.folders.primaryFolder(for: recipe.id))
    XCTAssertFalse(history.canUndo, "A repeated placement must not create an extra Undo group")
    XCTAssertEqual(library.navigation.destination, destination)
    await history.disconnect()
    history.updateLocale(Locale(identifier: "fr-CA"))
    await history.open()
    XCTAssertTrue(history.canRedo)
    XCTAssertEqual(history.nativeUndoManager?.redoActionName, "Déplacer la recette")
    await history.redo()
    XCTAssertEqual(organization.snapshot?.folders.primaryFolder(for: recipe.id), folder)
    XCTAssertEqual(library.navigation.destination, destination)
  }

  func testBulkDropUsesPluralNativeNameAndOneUndoRestoresBothPriorPlacements() async throws {
    let fixture = try OrganizationHistoryAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory.deletingLastPathComponent()) }
    let secondID = try RecipeEditor(repository: fixture.recipes)
      .create(in: fixture.kitchenID, from: RecipeDraft(title: "Bread")).id
    let second = try XCTUnwrap(fixture.recipes.recipe(id: secondID))
    let priorFolder = Folder.ID()
    fixture.model.perform { try $0.prepare(folder: .create(id: priorFolder, name: "Other", parentID: nil)) }
    fixture.model.perform { try $0.move([second.id], to: priorFolder) }
    XCTAssertNil(fixture.model.snapshot?.folders.primaryFolder(for: fixture.recipe.id))
    XCTAssertEqual(fixture.model.snapshot?.folders.primaryFolder(for: second.id), priorFolder)

    let history = fixture.registry.presentation(for: UUID())
    history.updateLocale(Locale(identifier: "en-US"))
    await history.open()
    let dragged = [fixture.recipe, second]
    let values = dragged.map { "km-recipe:" + $0.id.rawValue.uuidString }
    XCTAssertTrue(fixture.model.dropRecipes(values, recipes: dragged, to: fixture.folder, history: history))
    await history.waitForPendingOperation()
    XCTAssertEqual(fixture.model.snapshot?.folders.primaryFolder(for: fixture.recipe.id), fixture.folder)
    XCTAssertEqual(fixture.model.snapshot?.folders.primaryFolder(for: second.id), fixture.folder)
    XCTAssertEqual(history.nativeUndoManager?.undoActionName, "Move Recipes")

    await history.undo()
    XCTAssertNil(fixture.model.snapshot?.folders.primaryFolder(for: fixture.recipe.id))
    XCTAssertEqual(fixture.model.snapshot?.folders.primaryFolder(for: second.id), priorFolder)
    XCTAssertFalse(history.canUndo)
    await history.disconnect()
  }

  func testUndoLeavesEditingFocusAndNavigationVetoIntact() async throws {
    let app = try AppRuntime.testing()
    let model = try XCTUnwrap(app.libraryModel.organization)
    let store = HistoryNavigationDraftStore()
    let library = RecipeLibraryModel(library: app.libraryModel.library,
      samplePreferences: VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted),
      kitchenWasCreated: false, editingStore: store, organization: model)
    library.loadIfNeeded()
    let recipe = try XCTUnwrap(library.recipes.first)
    let folder = Folder.ID()
    model.perform { try $0.prepare(folder: .create(id: folder, name: "Dinner", parentID: nil)) }
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    await model.move([recipe.id], to: folder, history: history)
    library.beginEditing()
    let editor = try XCTUnwrap(library.editor)
    editor.session.title = "Keep this draft"
    store.refusesWrites = true
    let destination = library.navigation.destination
    let focus = library.navigation.focus
    XCTAssertFalse(library.navigation.browseRecipes {})
    await history.undo()
    XCTAssertNil(model.snapshot?.folders.primaryFolder(for: recipe.id))
    XCTAssertEqual(library.navigation.destination, destination)
    XCTAssertEqual(library.navigation.focus, focus)
    XCTAssertIdentical(library.editor, editor)
    XCTAssertEqual(editor.session.title, "Keep this draft")
    XCTAssertFalse(library.navigation.browseRecipes {})
  }

  func testUnavailableSceneNeverFallsBackToLegacySingleRecipeAcceptance() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = try XCTUnwrap(app.libraryModel.organization)
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let folder = Folder.ID()
    model.perform { try $0.prepare(folder: .create(id: folder, name: "Dinner", parentID: nil)) }
    await model.move([recipe.id], to: folder, history: nil)
    XCTAssertTrue(model.failed)
    XCTAssertNil(model.pending)
    XCTAssertNil(model.snapshot?.folders.primaryFolder(for: recipe.id))
    XCTAssertFalse(model.dropRecipes(["km-recipe:" + recipe.id.rawValue.uuidString], recipes: [recipe], to: folder))
    XCTAssertNil(model.snapshot?.folders.primaryFolder(for: recipe.id))
    let tag = Tag.ID()
    model.perform { try $0.prepare(tag: .create(id: tag, name: "Dinner")) }
    await model.classify([recipe.id], tagID: tag, adding: true, history: nil)
    XCTAssertEqual(model.snapshot?.tags.tagIDs(for: recipe.id).contains(tag), false)
    XCTAssertFalse(model.dropTag(["km-recipe:" + recipe.id.rawValue.uuidString], recipes: [recipe], onto: tag))
    XCTAssertNil(model.pending)

  }

  func testResetRetiresActiveAndRestoredSceneHistoryBeforeChangingKitchen() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = try XCTUnwrap(app.libraryModel.organization)
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let folder = Folder.ID(), sceneID = UUID()
    model.perform { try $0.prepare(folder: .create(id: folder, name: "Dinner", parentID: nil)) }
    let history = app.organizationHistory.presentation(for: sceneID)
    await history.open()
    await model.move([recipe.id], to: folder, history: history)
    XCTAssertTrue(history.canUndo)
    XCTAssertTrue(app.libraryModel.resetKitchen())
    XCTAssertFalse(history.canUndo)
    XCTAssertNil(history.nativeUndoManager)
    await history.undo()
    let restored = app.organizationHistory.presentation(for: sceneID)
    await restored.open()
    XCTAssertFalse(restored.canUndo)
    XCTAssertFalse(restored.canRedo)
  }

  func testSceneDisconnectionRestoresHistoryButExplicitDiscardRetiresIt() async throws {
    let fixture = try OrganizationHistoryAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory.deletingLastPathComponent()) }
    let sceneID = UUID()
    let history = fixture.registry.presentation(for: sceneID)
    history.recordSceneSession("saved-scene-session")
    await history.open()
    await fixture.model.move([fixture.recipe.id], to: fixture.folder, history: history)
    await history.disconnect()
    let reopened = try fixture.makeRegistry()
    let restored = reopened.presentation(for: sceneID)
    await restored.open()
    XCTAssertTrue(restored.canUndo)
    OrganizationHistoryRegistry.discardSceneSessions(["saved-scene-session"],
      recordingAt: fixture.directory.deletingLastPathComponent())
    XCTAssertFalse(restored.canUndo)
    await restored.disconnect()
    let afterDiscard = try fixture.makeRegistry()
    let disposed = afterDiscard.presentation(for: sceneID)
    await disposed.open()
    XCTAssertFalse(disposed.ready)
    XCTAssertFalse(disposed.canUndo)
    XCTAssertEqual(fixture.model.snapshot?.folders.primaryFolder(for: fixture.recipe.id), fixture.folder)
  }

  func testRejectedInverseOffersExactRetryAndExplicitRetirementWithoutFalseRedo() async throws {
    let fixture = try OrganizationHistoryAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory.deletingLastPathComponent()) }
    let history = fixture.registry.presentation(for: UUID())
    await history.open()
    await fixture.model.move([fixture.recipe.id], to: fixture.folder, history: history)
    let other = Folder.ID()
    fixture.model.perform { try $0.prepare(folder: .create(id: other, name: "Elsewhere", parentID: nil)) }
    fixture.model.perform { try $0.move([fixture.recipe.id], to: other) }
    await history.undo()
    XCTAssertTrue(history.failed)
    XCTAssertTrue(history.canDiscardRejectedCompensation)
    XCTAssertFalse(history.canRedo)
    XCTAssertEqual(fixture.model.snapshot?.folders.primaryFolder(for: fixture.recipe.id), other)
    await history.retry()
    XCTAssertTrue(history.canDiscardRejectedCompensation)
    XCTAssertFalse(history.canRedo)
    await history.discardRejectedCompensation()
    XCTAssertFalse(history.failed)
    XCTAssertFalse(history.canDiscardRejectedCompensation)
    XCTAssertFalse(history.canRedo)
    await fixture.model.move([fixture.recipe.id], to: fixture.folder, history: history)
    XCTAssertEqual(fixture.model.snapshot?.folders.primaryFolder(for: fixture.recipe.id), fixture.folder)
    XCTAssertTrue(history.canUndo)
  }

  func testStoreChangeRetiresOldScopeBeforeReturningToIt() async throws {
    let fixture = try OrganizationHistoryAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory.deletingLastPathComponent()) }
    let sceneID = UUID()
    let history = fixture.registry.presentation(for: sceneID)
    await history.open()
    await fixture.model.move([fixture.recipe.id], to: fixture.folder, history: history)
    let otherScope = try fixture.makeRegistry(storeID: "other", directory:
      fixture.directory.deletingLastPathComponent().appendingPathComponent(String(repeating: "b", count: 64)))
    XCTAssertFalse(history.canUndo)
    await history.disconnect()
    let other = otherScope.presentation(for: sceneID)
    await other.open()
    XCTAssertFalse(other.canUndo)
    await other.disconnect()
    let returned = try fixture.makeRegistry()
    let restored = returned.presentation(for: sceneID)
    await restored.open()
    XCTAssertFalse(restored.canUndo)
    XCTAssertEqual(fixture.model.snapshot?.folders.primaryFolder(for: fixture.recipe.id), fixture.folder)
  }

  func testFailedResetMarkerWriteBlocksRestorationAndLeavesRecipesUntouched() async throws {
    let fixture = try OrganizationHistoryAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory.deletingLastPathComponent()) }
    let sceneID = UUID()
    let history = fixture.registry.presentation(for: sceneID)
    await history.open()
    await fixture.model.move([fixture.recipe.id], to: fixture.folder, history: history)
    XCTAssertTrue(history.canUndo)
    let marker = fixture.directory.appendingPathComponent("Generation.json")
    let original = try Data(contentsOf: marker)
    try FileManager.default.removeItem(at: marker)
    try FileManager.default.createDirectory(at: marker, withIntermediateDirectories: false)
    XCTAssertThrowsError(try fixture.registry.prepareForReset())
    XCTAssertFalse(history.canUndo)
    XCTAssertEqual(fixture.model.snapshot?.folders.primaryFolder(for: fixture.recipe.id), fixture.folder)
    try FileManager.default.removeItem(at: marker)
    try original.write(to: marker, options: .atomic)
    await history.disconnect()
    let reopened = try fixture.makeRegistry()
    let restored = reopened.presentation(for: sceneID)
    await restored.open()
    XCTAssertFalse(restored.ready)
    XCTAssertFalse(restored.canUndo)
    await fixture.model.move([fixture.recipe.id], to: nil, history: restored)
    XCTAssertEqual(fixture.model.snapshot?.folders.primaryFolder(for: fixture.recipe.id), fixture.folder)
  }
}

extension OrganizationHistoryPresentationTests {
  func testTagSelectionNativeNamesAndReopenPreserveNavigationAndFilters() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let library = app.libraryModel
    let model = try XCTUnwrap(library.organization)
    let ids = Set(library.recipes.prefix(2).map(\.id))
    XCTAssertEqual(ids.count, 2)
    let tag = Tag.ID()
    model.perform { try $0.prepare(tag: .create(id: tag, name: "Dinner")) }
    let history = app.organizationHistory.presentation(for: UUID())
    history.updateLocale(Locale(identifier: "en-US"))
    await history.open()
    model.filter.search = "retained query"
    let destination = library.navigation.destination
    let focus = library.navigation.focus
    await model.classify(ids, tagID: tag, adding: true, history: history)
    XCTAssertEqual(history.nativeUndoManager?.undoActionName, "Add Tag")
    for id in ids { XCTAssertEqual(model.snapshot?.tags.tagIDs(for: id).contains(tag), true) }
    await model.classify(ids, tagID: tag, adding: false, history: history)
    XCTAssertEqual(history.nativeUndoManager?.undoActionName, "Remove Tag")
    await history.undo()
    for id in ids { XCTAssertEqual(model.snapshot?.tags.tagIDs(for: id).contains(tag), true) }
    await history.disconnect()
    history.updateLocale(Locale(identifier: "fr-CA"))
    await history.open()
    XCTAssertEqual(history.nativeUndoManager?.redoActionName, "Retirer une étiquette")
    await history.redo()
    for id in ids { XCTAssertEqual(model.snapshot?.tags.tagIDs(for: id).contains(tag), false) }
    await history.undo()
    await history.undo()
    for id in ids { XCTAssertEqual(model.snapshot?.tags.tagIDs(for: id).contains(tag), false) }
    XCTAssertEqual(library.navigation.destination, destination)
    XCTAssertEqual(library.navigation.focus, focus)
    XCTAssertEqual(model.filter.search, "retained query")
    await history.disconnect()
  }

}

@MainActor
struct OrganizationHistoryAppFixture {
  let directory: URL
  let repository: SwiftDataRecipeOrganizationRepository
  let recipes: SwiftDataRecipeRepository
  let model: RecipeOrganizationModel
  let recipe: StoredRecipe
  let folder: Folder.ID
  let registry: OrganizationHistoryRegistry
  let kitchenID: Kitchen.ID
  private let ownerID = KitchenOwner.ID(rawValue: "history-owner")

  init() throws {
    let ownerID = KitchenOwner.ID(rawValue: "history-owner")
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathComponent(String(repeating: "a", count: 64))
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    self.recipes = recipes
    let kitchen = Kitchen(ownerID: ownerID, name: "Home")
    kitchenID = kitchen.id
    try recipes.save(kitchen)
    let saved = try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    recipe = try XCTUnwrap(recipes.recipe(id: saved.id))
    repository = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    guard let defaults = UserDefaults(suiteName: "history-app." + UUID().uuidString) else {
      throw CocoaError(.fileWriteUnknown)
    }
    model = RecipeOrganizationModel(repository: repository, kitchenID: kitchen.id, scope: "history-owner",
      preferences: DefaultsKitchenPreferencesStore(defaults: defaults)
        .organizationPreferences(scope: "history-owner", kitchenID: kitchen.id), defaults: defaults)
    let folder = Folder.ID()
    self.folder = folder
    model.perform { try $0.prepare(folder: .create(id: folder, name: "Dinner", parentID: nil)) }
    registry = try OrganizationHistoryRegistry(repository: repository, organization: model, ownerID: ownerID,
      storeID: "test", kitchenID: kitchen.id, directory: directory)
  }

  func makeRegistry(storeID: String = "test", directory: URL? = nil) throws -> OrganizationHistoryRegistry {
    try OrganizationHistoryRegistry(repository: repository, organization: model, ownerID: ownerID,
      storeID: storeID, kitchenID: kitchenID, directory: directory ?? self.directory)
  }
}

@MainActor
private final class HistoryNavigationDraftStore: RecipeEditingStoring {
  var refusesWrites = false
  private var records: [RecipeEditingRecord] = []
  func load() throws -> [RecipeEditingRecord] { records }
  func save(_ records: [RecipeEditingRecord]) throws {
    if refusesWrites { throw CocoaError(.fileWriteUnknown) }
    self.records = records
  }
}
