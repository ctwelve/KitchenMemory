// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import XCTest

final class RecipeIngredientTextDraftTests: XCTestCase {
  func testCompletedTextKeepsPrecisionAndRecoversUnresolvedProposal() throws {
    var salt = IngredientLineParser.parse("1 tsp salt")
    salt.parseState = .reviewed
    salt.note = "Use the fine salt"
    let section = IngredientSection(title: nil, ingredients: [salt])
    var text = RecipeIngredientTextDraft(sections: [section])
    XCTAssertEqual(text.sections, [section], "Opening the simple surface is lossless")
    text.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2")
    text.finishEditing(locale: Locale(identifier: "en_US"))
    XCTAssertEqual(text.sections[0].ingredients[0].quantity, salt.quantity)
    XCTAssertEqual(text.conflicts.count, 1)
    var recovered = try JSONDecoder().decode(RecipeIngredientTextDraft.self, from: JSONEncoder().encode(text))
    recovered.finishEditing(locale: Locale(identifier: "en_US"))
    XCTAssertEqual(recovered.conflicts.count, 1, "Leaving twice cannot silently accept a proposal")
    recovered.resolve(salt.id, acceptingInterpretation: true)
    XCTAssertEqual(recovered.sections[0].ingredients[0].quantity?.lowerBound?.numerator, 2)
    XCTAssertEqual(recovered.sections[0].ingredients[0].note, salt.note)
    XCTAssertEqual(recovered.sections[0].ingredients[0].id, salt.id)
  }
  func testPastedHeadingAndReversalPreserveSurvivingLineAndSectionIdentities() {
    let salt = IngredientLineParser.parse("1 tsp salt")
    let section = IngredientSection(title: nil, ingredients: [salt])
    var text = RecipeIngredientTextDraft(sections: [section])
    text.replaceCharacters(in: NSRange(location: 0, length: 0), with: "# Sauce\n2 cups tomatoes\n")
    text.finishEditing()
    XCTAssertEqual(text.sections.map(\.title), [nil, "Sauce"])
    XCTAssertEqual(text.sections.last?.ingredients.map(\.originalText), ["2 cups tomatoes", "1 tsp salt"])
    XCTAssertEqual(text.sections.last?.ingredients.last?.id, salt.id)
    text.replaceCharacters(in: NSRange(location: 0, length: 2), with: "")
    text.finishEditing()
    XCTAssertEqual(text.sections.count, 1)
    XCTAssertEqual(text.sections[0].id, section.id)
    XCTAssertEqual(text.sections[0].ingredients.first?.originalText, "Sauce")
  }

  func testLocalDraftRecoversActiveTextAndPublishesOnlyAfterExplicitConflictChoice() throws {
    var ingredient = IngredientLineParser.parse("1 tsp salt")
    ingredient.parseState = .reviewed
    var session = RecipeEditSession(draft: RecipeDraft(title: "Soup", ingredientSections: [
      IngredientSection(title: "Main", ingredients: [ingredient])
    ], instructionSections: [InstructionSection(title: "Cook", steps: [InstructionStep(text: "Stir")])]))
    let steps = session.instructionSections
    session.prepareIngredientText()
    var text = try XCTUnwrap(session.ingredientText)
    let range = (text.text as NSString).range(of: "1 tsp")
    text.replaceCharacters(in: NSRange(location: range.location, length: 1), with: "2")
    session.updateIngredientText(text)
    var recovered = try JSONDecoder().decode(RecipeEditSession.self, from: JSONEncoder().encode(session))
    XCTAssertEqual(recovered.ingredientSections[0].ingredients[0].originalText, "2 tsp salt")
    XCTAssertThrowsError(try recovered.validatedDraft())
    recovered.finishIngredientText()
    recovered.ingredientText?.resolve(ingredient.id, acceptingInterpretation: false)
    recovered.finishIngredientText()
    let published = try recovered.validatedDraft()
    XCTAssertEqual(published.ingredientSections[0].ingredients[0].quantity, ingredient.quantity)
    XCTAssertEqual(published.instructionSections, steps)
    // A precise edit in Advanced is reflected when returning to simple editing.
    recovered.ingredientSections[0].ingredients[0].note = "Advanced adjustment"
    recovered.prepareIngredientText()
    XCTAssertEqual(recovered.ingredientText?.sections[0].ingredients[0].note, "Advanced adjustment")
  }

  func testDeletingCompleteLeadingLineKeepsSurvivingPreciseRow() {
    let oil = IngredientLineParser.parse("oil")
    var salt = IngredientLineParser.parse("1 tsp salt")
    salt.parseState = .reviewed
    salt.note = "Keep this precision"
    var text = RecipeIngredientTextDraft(sections: [IngredientSection(ingredients: [oil, salt])])
    text.replaceCharacters(in: NSRange(location: 0, length: 4), with: "")
    text.finishEditing()
    XCTAssertEqual(text.sections[0].ingredients, [salt])
    XCTAssertTrue(text.conflicts.isEmpty)
  }

}
