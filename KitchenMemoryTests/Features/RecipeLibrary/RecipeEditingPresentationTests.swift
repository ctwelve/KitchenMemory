// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class RecipeEditingPresentationTests: XCTestCase {
  func testClosePreservesEditingIntentWithoutChangingRecipeAndSaveCreatesRevision() throws {
    let app = try AppRuntime.testing()
    let library = app.libraryModel
    library.loadIfNeeded()
    let original = try XCTUnwrap(library.recipes.first)
    library.beginEditing(original)
    let editor = try XCTUnwrap(library.editor)
    editor.session.title = "My revised soup"
    library.closeEditor()
    XCTAssertNil(library.editor)
    XCTAssertEqual(library.recipes.first { $0.id == original.id }, original)
    library.beginEditing(original)
    XCTAssertEqual(library.editor?.session.title, "My revised soup")
    XCTAssertTrue(library.saveEditor())
    XCTAssertNil(library.editor)
    let revised = try XCTUnwrap(library.recipes.first { $0.id == original.id })
    XCTAssertEqual(revised.revision.title, "My revised soup")
    XCTAssertNotEqual(revised.revision.id, original.revision.id)
    XCTAssertTrue(try app.recipeRepository.revisions(for: original.id).contains(original.revision))
  }

  func testDiscardRequiresConfirmationAndValidationKeepsEditorOpen() throws {
    let app = try AppRuntime.testing()
    let library = app.libraryModel
    library.loadIfNeeded()
    library.beginEditing()
    let editor = try XCTUnwrap(library.editor)
    XCTAssertFalse(library.saveEditor())
    XCTAssertNotNil(library.editor)
    library.discardEditor(confirmed: false)
    XCTAssertNotNil(library.editor)
    library.discardEditor(confirmed: true)
    XCTAssertNil(library.editor)
    XCTAssertFalse(library.editingDrafts.contains { $0.id == editor.id })
  }
}
