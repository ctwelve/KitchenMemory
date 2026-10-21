// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class OrganizationHistoryDeliveryTests: XCTestCase {
  func testDiscardDeliveredBeforeRegistryConstructionBlocksOldSceneRestoration() async throws {
    let directory: URL
    let model: RecipeOrganizationModel
    let repository: SwiftDataRecipeOrganizationRepository
    let recipe: StoredRecipe
    let folder: Folder.ID
    let sceneID = UUID()
    do {
      let prior = try OrganizationHistoryAppFixture()
      directory = prior.directory
      model = prior.model
      repository = prior.repository
      recipe = prior.recipe
      folder = prior.folder
      let history = prior.registry.presentation(for: sceneID)
      history.recordSceneSession("discarded-before-preparation")
      await history.open()
      await model.move([recipe.id], to: folder, history: history)
      XCTAssertTrue(history.canUndo)
      await history.disconnect()
    }
    defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
    OrganizationHistoryRegistry.discardSceneSessions(["discarded-before-preparation"],
      recordingAt: directory.deletingLastPathComponent())
    let reopened = try OrganizationHistoryRegistry(repository: repository, organization: model,
      ownerID: KitchenOwner.ID(rawValue: "history-owner"), storeID: "test",
      kitchenID: recipe.recipe.kitchenID, directory: directory)
    let restored = reopened.presentation(for: sceneID)
    await restored.open()
    XCTAssertFalse(restored.ready)
    XCTAssertFalse(restored.canUndo)
    XCTAssertEqual(model.snapshot?.folders.primaryFolder(for: recipe.id), folder)
  }

  func testDeliveredExternalOrganizationChangeClearsNativeUndoWithoutCompensation() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = try XCTUnwrap(app.libraryModel.organization)
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let folder = Folder.ID()
    model.perform { try $0.prepare(folder: .create(id: folder, name: "Dinner", parentID: nil)) }
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    await model.move([recipe.id], to: folder, history: history)
    let repository = SwiftDataRecipeOrganizationRepository(modelContainer: app.modelContainer)
    let observed = try repository.load(in: recipe.recipe.kitchenID)
    try repository.accept(observed.move([recipe.id], to: nil))
    app.reloadAfterExternalStoreChange()
    await app.organizationHistory.waitForReconciliation()
    XCTAssertFalse(history.canUndo)
    XCTAssertFalse(try XCTUnwrap(history.nativeUndoManager).canUndo)
    XCTAssertFalse(history.canDiscardRejectedCompensation)
    XCTAssertFalse(history.failed)
    XCTAssertNil(model.snapshot?.folders.primaryFolder(for: recipe.id))
  }

  func testAnotherSceneAcceptedMoveClearsInterferedHistoryWithoutCompensation() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = try XCTUnwrap(app.libraryModel.organization)
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let folder = Folder.ID()
    model.perform { try $0.prepare(folder: .create(id: folder, name: "Dinner", parentID: nil)) }
    let first = app.organizationHistory.presentation(for: UUID())
    let second = app.organizationHistory.presentation(for: UUID())
    await first.open()
    await second.open()
    await model.move([recipe.id], to: folder, history: first)
    await app.organizationHistory.waitForReconciliation()
    await model.move([recipe.id], to: nil, history: second)
    await app.organizationHistory.waitForReconciliation()
    XCTAssertFalse(first.canUndo)
    XCTAssertFalse(first.canDiscardRejectedCompensation)
    XCTAssertFalse(first.failed)
    XCTAssertTrue(second.canUndo)
    XCTAssertNil(model.snapshot?.folders.primaryFolder(for: recipe.id))
  }

}
