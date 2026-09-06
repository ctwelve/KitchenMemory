// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class RecipeDispositionPresentationTests: XCTestCase {
  func testDeleteAndRestoreRouteThroughDeletedItemsWithoutDiscardingDraft() throws {
    let app = try AppRuntime.testing()
    let model = app.libraryModel
    model.loadIfNeeded()
    let original = try XCTUnwrap(model.recipes.first)
    model.beginEditing(original)
    let editor = try XCTUnwrap(model.editor)
    editor.session.title = "Local soup"
    model.closeEditor()
    model.deleteRecipe(model.library.prepareDeletion(of: original.id))
    XCTAssertNil(model.pendingDisposition)
    XCTAssertEqual(model.navigation.destination, .deletedItems)
    XCTAssertFalse(model.recipes.contains { $0.id == original.id })
    XCTAssertTrue(model.editingDrafts.contains { $0.id == editor.id })
    let deleted = try XCTUnwrap(model.deletedRecipes.first { $0.id == original.id })
    model.restoreRecipe(try model.library.prepareRestoration(of: deleted))
    XCTAssertNil(model.pendingDisposition)
    XCTAssertTrue(model.deletedRecipes.isEmpty)
    XCTAssertTrue(model.recipes.contains { $0.id == original.id })
    model.beginEditing(original)
    XCTAssertEqual(model.editor?.session.title, "Local soup")
  }

  func testFailedDispositionKeepsRetryIdentityAcrossRefresh() throws {
    let app = try AppRuntime.testing()
    let model = app.libraryModel
    model.loadIfNeeded()
    let command = model.library.prepareDeletion(of: Recipe.ID())
    model.deleteRecipe(command)
    XCTAssertEqual(model.issue, .disposition)
    model.reloadAfterExternalStoreChange()
    XCTAssertEqual(model.issue, .disposition)
    model.retryCurrentIssue()
    guard case let .delete(pending) = model.pendingDisposition else {
      XCTFail("Failed command must remain available for retry")
      return
    }
    XCTAssertEqual(pending, command)
  }
}
