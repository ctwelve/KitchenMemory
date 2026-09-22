// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
@testable import KitchenMemory
import SwiftUI
import XCTest

@MainActor
final class RecipeSimpleEditingTests: XCTestCase {
  func testTextUndoRestoresSectionIdentityAndModesShareTheDraft() throws {
    let draft = RecipeEditingDraft(draft: RecipeDraft(title: "Soup"))
    let editor = RecipeEditingModel(draft: draft)
    editor.session.prepareIngredientText()
    let binding = Binding<RecipeIngredientTextDraft>(
      get: { editor.session.ingredientText! }, set: { editor.session.updateIngredientText($0) })
    let input = IngredientTextCoordinator(document: binding, locale: Locale(identifier: "en_US"))
    let paste = "# Sauce\n2 cups tomatoes\n"
    input.replace(NSRange(location: 0, length: 0), with: paste, undoing: false)
    let sectionID = try XCTUnwrap(editor.session.ingredientSections.first?.id)
    let ingredientID = try XCTUnwrap(editor.session.ingredientSections.first?.ingredients.first?.id)
    input.replace(NSRange(location: 0, length: (paste as NSString).length), with: "", undoing: true)
    XCTAssertTrue(editor.session.ingredientSections.isEmpty)
    input.replace(NSRange(location: 0, length: 0), with: paste, undoing: false, redoing: true)
    XCTAssertEqual(editor.session.ingredientSections.first?.id, sectionID)
    XCTAssertEqual(editor.session.ingredientSections.first?.ingredients.first?.id, ingredientID)
    editor.setAdvancedEditor(true, locale: Locale(identifier: "en_US"))
    XCTAssertTrue(editor.usesAdvancedEditor)
    editor.session.ingredientSections[0].ingredients[0].note = "A precise adjustment"
    editor.setAdvancedEditor(false, locale: Locale(identifier: "en_US"))
    XCTAssertFalse(editor.usesAdvancedEditor)
    XCTAssertEqual(editor.session.ingredientText?.sections[0].ingredients[0].note, "A precise adjustment")
    XCTAssertEqual(editor.session.ingredientText?.text, paste)
    XCTAssertTrue(editor.draft === draft)
  }
  func testTextUndoPreservesLaterPrecisionForEditedAndUntouchedIngredients() throws {
    let salt = IngredientLineParser.parse("1 tsp salt")
    let oil = IngredientLineParser.parse("oil")
    let editor = RecipeEditingModel(draft: RecipeEditingDraft(draft: RecipeDraft(title: "Soup", ingredientSections: [
      IngredientSection(ingredients: [salt, oil])
    ])))
    editor.session.prepareIngredientText()
    let input = IngredientTextCoordinator(document: Binding(
      get: { editor.session.ingredientText! }, set: { editor.session.updateIngredientText($0) }), locale: .current)
    input.replace(NSRange(location: 0, length: 1), with: "2", undoing: false)
    input.finish()
    editor.session.ingredientSections[0].ingredients[0].note = "New precise note"
    editor.session.ingredientSections[0].ingredients[1].isOptional = true
    input.replace(NSRange(location: 0, length: 1), with: "1", undoing: true)
    let ingredients = editor.session.ingredientSections[0].ingredients
    XCTAssertEqual(ingredients[0].id, salt.id)
    XCTAssertEqual(ingredients[0].quantity?.lowerBound?.numerator, 1)
    XCTAssertEqual(ingredients[0].note, "New precise note")
    XCTAssertTrue(ingredients[1].isOptional)
    input.replace(NSRange(location: 0, length: 1), with: "2", undoing: false, redoing: true)
    XCTAssertEqual(editor.session.ingredientSections[0].ingredients[0].quantity?.lowerBound?.numerator, 2)
    XCTAssertEqual(editor.session.ingredientSections[0].ingredients[0].note, "New precise note")
  }

}
