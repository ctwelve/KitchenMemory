// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class RecipeRecoveryPresentationTests: XCTestCase {
  func testLateRecipeEvidenceAppearsInRecoveryWithoutBlockingTheLibrary() throws {
    let app = try AppRuntime.testing()
    let model = app.libraryModel
    model.loadIfNeeded()
    let command = try model.library.prepareSave(from: RecipeDraft(title: "Retained soup"),
                                                original: nil, observedSelectionIDs: [])
    try app.recipeRepository.save(command)
    let now = Date()
    try app.recipeRepository.delete(RecipeDeleteCommand(
      kitchenID: command.recipe.kitchenID, recipeID: command.recipe.id,
      deletedAt: now.addingTimeInterval(-31 * 86_400)
    ))
    _ = try app.recipeRepository.maintainDeletedRecipes(in: command.recipe.kitchenID, at: now)
    try app.recipeRepository.save(command)
    model.reloadAfterExternalStoreChange()
    XCTAssertNil(model.issue)
    XCTAssertFalse(model.recipes.contains { $0.id == command.recipe.id })
    XCTAssertEqual(model.recoveryRecipes.map(\.id), [command.recipe.id])
    let draft = try model.drafts.beginRecovery(recipeID: command.recipe.id, revisionID: command.revision.id)
    model.resumeEditingDraft(draft.id)
    XCTAssertNil(model.editor?.draft.original)
    XCTAssertTrue(model.saveEditor())
    XCTAssertNotEqual(model.selectedRecipe?.id, command.recipe.id)
    XCTAssertEqual(model.recoveryRecipes.map(\.id), [command.recipe.id])
  }
}
