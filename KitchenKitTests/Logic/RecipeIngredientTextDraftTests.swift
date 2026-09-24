// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
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

  func testLocalDraftRecoversActiveTextAndPublishesRetainedPrecisionWithoutConflictChoice() throws {
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
    XCTAssertTrue(recovered.canSave)
    let retained = try recovered.validatedDraft()
    XCTAssertEqual(retained.ingredientSections[0].ingredients[0].originalText, "2 tsp salt")
    XCTAssertEqual(retained.ingredientSections[0].ingredients[0].quantity, ingredient.quantity)
    XCTAssertEqual(retained.instructionSections, steps)
    recovered.finishIngredientText()
    XCTAssertEqual(recovered.ingredientText?.conflicts.count, 1)
    var resolved = try XCTUnwrap(recovered.ingredientText)
    resolved.resolve(ingredient.id, acceptingInterpretation: false)
    recovered.updateIngredientText(resolved)
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

  func testFinishingTextPreservesDirectStructuredAdjustments() throws {
    var session = RecipeEditSession(draft: RecipeDraft(title: "Soup", ingredientSections: [
      IngredientSection(ingredients: [IngredientLineParser.parse("1 tsp salt")])
    ]))
    session.prepareIngredientText()
    session.ingredientSections[0].ingredients[0].note = "An explicit adjustment"
    XCTAssertEqual(try session.validatedDraft().ingredientSections[0].ingredients[0].note, "An explicit adjustment")
    session.finishIngredientText()
    XCTAssertEqual(session.ingredientSections[0].ingredients[0].note, "An explicit adjustment")
  }

  func testOpeningSparseSectionsRetainsEvenEmptyAuthoredRows() {
    let named = RecipeIngredient(ingredientText: "salt", note: "Keep this detail")
    let blank = RecipeIngredient()
    let sections = [IngredientSection(ingredients: [named, blank]), IngredientSection(ingredients: [])]
    let text = RecipeIngredientTextDraft(sections: sections)
    XCTAssertEqual(text.sections, sections)
    XCTAssertTrue(text.lines.allSatisfy(\.isInterpreted))
    let displayed = RecipeIngredientTextDraft(sections: sections, displayWording: [named.id: "Fine salt"])
    XCTAssertTrue(displayed.text.hasPrefix("Fine salt"))
    XCTAssertEqual(displayed.sections, sections)
  }

  func testRearrangingSectionsCarriesPendingReviewAndExplicitWording() {
    var salt = IngredientLineParser.parse("1 tsp salt")
    salt.parseState = .reviewed
    var text = RecipeIngredientTextDraft(sections: [IngredientSection(ingredients: [salt])])
    text.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2")
    text.finishEditing()
    XCTAssertEqual(text.conflicts.first?.id, salt.id)
    let extra = IngredientSection(title: "Finish", ingredients: [IngredientLineParser.parse("oil")])
    text = text.incorporating([extra] + text.sections)
    XCTAssertEqual(text.conflicts.first?.id, salt.id)
    XCTAssertEqual(text.sections.first?.id, extra.id)
    var precise = text.sections
    precise[1].ingredients[0].originalText = "A pinch of fine salt"
    text = text.incorporating(precise)
    XCTAssertTrue(text.conflicts.isEmpty)
    XCTAssertTrue(text.text.hasSuffix("A pinch of fine salt"))
    XCTAssertEqual(text.sections[1].ingredients[0].quantity, salt.quantity)
  }

  func testBlankHeadingsAndPartialInputRemainReversible() {
    var empty = RecipeIngredientTextDraft(sections: [])
    XCTAssertTrue(empty.sections.isEmpty)
    empty.replaceCharacters(in: NSRange(location: 0, length: 0), with: "1,5 kg flour")
    empty.finishEditing(locale: Locale(identifier: "fr_CA"), excludingLineAtUTF16Offset: 3)
    XCTAssertFalse(empty.lines[0].isInterpreted)
    XCTAssertEqual(empty.sections[0].ingredients[0].originalText, "1,5 kg flour")
    empty.finishEditing(locale: Locale(identifier: "fr_CA"))
    XCTAssertEqual(empty.sections[0].ingredients[0].quantity?.lowerBound,
                   RationalQuantity(numerator: 3, denominator: 2))
    let section = IngredientSection(title: "Sauce", ingredients: [])
    var text = RecipeIngredientTextDraft(sections: [section])
    text.replaceCharacters(in: NSRange(location: 2, length: 5), with: "")
    text.finishEditing()
    XCTAssertEqual(text.sections, [IngredientSection(id: section.id, ingredients: [])])
    text.replaceCharacters(in: NSRange(location: 0, length: 2), with: "salt")
    text.finishEditing()
    XCTAssertEqual(text.sections[0].ingredients.first?.originalText, "salt")
    XCTAssertNil(text.sections[0].ingredients.first?.quantity)
  }

  func testRebasingPrecisionRetainsHistoricalTextAndItsParsedQuantity() {
    let salt = IngredientLineParser.parse("1 tsp salt")
    let original = RecipeIngredientTextDraft(sections: [IngredientSection(ingredients: [salt])])
    var later = original
    later.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2")
    later.finishEditing()
    var sections = later.sections
    sections[0].ingredients[0].note = "Use fine salt"
    sections[0].ingredients[0].isOptional = true
    let adjusted = later.incorporating(sections)
    let restored = original.preservingAdjustments(from: later, to: adjusted)
    XCTAssertEqual(restored.sections[0].ingredients[0].quantity, salt.quantity)
    XCTAssertEqual(restored.sections[0].ingredients[0].originalText, "1 tsp salt")
    XCTAssertEqual(restored.sections[0].ingredients[0].note, "Use fine salt")
    XCTAssertTrue(restored.sections[0].ingredients[0].isOptional)
  }

}
