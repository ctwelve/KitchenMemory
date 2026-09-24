// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
@testable import KitchenMemory
import SwiftUI
import XCTest

@MainActor
final class RecipeSimpleEditingTests: XCTestCase {
  func testPrecisionBindingReconcilesImmediatelyAndIgnoresRemovedIdentities() throws {
    let salt = IngredientLineParser.parse("1 tsp salt")
    let draft = RecipeEditingDraft(draft: RecipeDraft(title: "Soup", ingredientSections: [
      IngredientSection(ingredients: [salt]),
    ]))
    let editor = RecipeEditingModel(draft: draft)
    let binding = editor.ingredientBinding(salt)

    binding.wrappedValue.note = "A precise adjustment"

    XCTAssertEqual(editor.session.ingredientText?.sections, editor.session.ingredientSections)
    XCTAssertEqual(editor.session.ingredientText?.text, "1 tsp salt")
    XCTAssertEqual(editor.session.ingredientText?.sections.first?.ingredients.first?.note, "A precise adjustment")
    editor.setAdvancedEditor(true, locale: Locale(identifier: "en_US"))
    editor.setAdvancedEditor(false, locale: Locale(identifier: "en_US"))
    XCTAssertEqual(binding.wrappedValue.note, "A precise adjustment")
    XCTAssertTrue(draft.removeIngredient(salt.id))
    binding.wrappedValue.note = "An obsolete control must not recreate a row"
    XCTAssertTrue(editor.session.ingredientSections[0].ingredients.isEmpty)
    XCTAssertEqual(editor.session.ingredientText?.sections, editor.session.ingredientSections)
  }

  func testTextUndoRestoresSectionIdentityAndModesShareTheDraft() throws {
    let draft = RecipeEditingDraft(draft: RecipeDraft(title: "Soup"))
    let editor = RecipeEditingModel(draft: draft)
    let input = draft.beginIngredientTextEditing()
    let paste = "# Sauce\n2 cups tomatoes\n"
    input.replaceCharacters(in: NSRange(location: 0, length: 0), with: paste, source: "",
                            locale: Locale(identifier: "en_US"))
    let sectionID = try XCTUnwrap(editor.session.ingredientSections.first?.id)
    let ingredientID = try XCTUnwrap(editor.session.ingredientSections.first?.ingredients.first?.id)
    input.observeNativeUndo(text: "", redoing: false)
    XCTAssertTrue(editor.session.ingredientSections.isEmpty)
    input.observeNativeUndo(text: paste, redoing: true)
    XCTAssertEqual(editor.session.ingredientSections.first?.id, sectionID)
    XCTAssertEqual(editor.session.ingredientSections.first?.ingredients.first?.id, ingredientID)
    editor.setAdvancedEditor(true, locale: Locale(identifier: "en_US"))
    XCTAssertTrue(editor.usesAdvancedEditor)
    editor.ingredientBinding(editor.session.ingredientSections[0].ingredients[0])
      .wrappedValue.note = "A precise adjustment"
    editor.setAdvancedEditor(false, locale: Locale(identifier: "en_US"))
    XCTAssertFalse(editor.usesAdvancedEditor)
    XCTAssertEqual(editor.session.ingredientText?.sections[0].ingredients[0].note, "A precise adjustment")
    XCTAssertEqual(editor.session.ingredientText?.text, paste)
    XCTAssertIdentical(editor.draft, draft)
  }
}
