// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class RecipeReconciliationPresentationTests: XCTestCase {
  func testComparisonOpensAnUnselectedDraftAndPublishesOnlyAfterSave() throws {
    let app = try AppRuntime.testing()
    let model = app.libraryModel
    model.loadIfNeeded()
    let original = try XCTUnwrap(model.recipes.first)
    let observed = try app.recipeRepository.selectionHeads(for: original.id)
    for title in ["Bean soup", "Lentil soup"] {
      try app.recipeRepository.save(model.library.prepareSave(
        from: RecipeDraft(title: title), original: original, observedSelectionIDs: observed
      ))
    }
    model.reloadAfterExternalStoreChange()
    XCTAssertFalse(model.recipes.contains { $0.id == original.id })
    let comparison = try XCTUnwrap(model.reconciliations.first)
    model.beginReconciliation(comparison)
    let editor = try XCTUnwrap(model.editor)
    XCTAssertFalse(editor.canSaveRevision)
    XCTAssertNil(editor.draft.reconciliation?.draft)
    try editor.draft.chooseRevision(comparison.revisions[0].id)
    try editor.draft.choose(.title, from: comparison.revisions[1].id)
    XCTAssertEqual(editor.session.title, comparison.revisions[1].title)
    model.closeEditor()
    model.beginReconciliation(comparison)
    XCTAssertEqual(model.editor?.id, editor.id)
    XCTAssertTrue(model.saveEditor())
    XCTAssertTrue(model.reconciliations.isEmpty)
    XCTAssertEqual(model.selectedRecipe?.revision.title, comparison.revisions[1].title)
    XCTAssertEqual(try app.recipeRepository.revisions(for: original.id).count, 4)
  }
}
