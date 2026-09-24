// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import XCTest

@MainActor
final class RecipeIngredientTextEditingTests: XCTestCase {
  func testOpeningNativeEditorAfterSaveCannotInitializeOrMutateFrozenContents() throws {
    let fixture = try IngredientTextEditingFixture()
    XCTAssertNil(fixture.draft.session.ingredientText)
    XCTAssertTrue(try XCTUnwrap(fixture.drafts.save(fixture.draft.id)).removedDraft)
    let before = fixture.draft.session
    let input = fixture.draft.beginIngredientTextEditing()
    XCTAssertFalse(input.isActive)
    XCTAssertEqual(input.document.text, "1 tsp salt")
    XCTAssertEqual(input.document.sections, before.ingredientSections)
    XCTAssertFalse(input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: "1 tsp salt"))
    XCTAssertFalse(input.completeLines())
    XCTAssertEqual(fixture.draft.session, before)
  }

  func testHistoryIsTransientAndCannotChangeAFrozenSave() throws {
    let fixture = try IngredientTextEditingFixture()
    let input = fixture.draft.beginIngredientTextEditing()
    XCTAssertTrue(input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: "1 tsp salt"))
    input.completeLines(locale: fixture.locale)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let encoded = try encoder.encode(fixture.store.load())
    input.end()
    let reopened = fixture.draft.beginIngredientTextEditing()
    XCTAssertEqual(try encoder.encode(fixture.store.load()), encoded)
    XCTAssertFalse(input.isActive)
    XCTAssertTrue(reopened.isActive)
    XCTAssertTrue(try XCTUnwrap(fixture.drafts.save(fixture.draft.id)).removedDraft)
    let saved = try XCTUnwrap(fixture.draft.pendingSave)
    XCTAssertFalse(reopened.isActive)
    XCTAssertFalse(reopened.observeNativeUndo(text: "1 tsp salt", redoing: false))
    XCTAssertFalse(reopened.completeLines())
    let frozen = fixture.draft.beginIngredientTextEditing()
    XCTAssertFalse(frozen.isActive)
    XCTAssertEqual(fixture.draft.pendingSave, saved)
    XCTAssertEqual(fixture.draft.session.ingredientText?.text, "2 tsp salt")
  }

  func testPendingInterpretationProposalsAndUntouchedPrecisionSurviveNativeHistory() throws {
    var salt = IngredientLineParser.parse("1 tsp salt")
    salt.parseState = .reviewed
    let fixture = try IngredientTextEditingFixture(ingredients: [salt, IngredientLineParser.parse("oil")])
    let draft = fixture.draft
    let input = draft.beginIngredientTextEditing()
    let source = input.document.text
    let lineIDs = input.document.lines.map(\.id)
    XCTAssertTrue(input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: source))
    XCTAssertFalse(input.completeLines(excluding: 0, locale: fixture.locale))
    XCTAssertTrue(input.document.conflicts.isEmpty)
    XCTAssertTrue(input.completeLines(locale: fixture.locale))
    let proposal = try XCTUnwrap(input.document.conflicts.first)
    var oil = try XCTUnwrap(draft.session.ingredientSections.first?.ingredients.last)
    oil.isOptional = true
    XCTAssertTrue(draft.updateIngredient(oil))
    XCTAssertTrue(input.observeNativeUndo(text: source, redoing: false))
    XCTAssertTrue(input.document.conflicts.isEmpty)
    XCTAssertEqual(input.document.sections.first?.ingredients.last, oil)
    XCTAssertTrue(input.observeNativeUndo(text: "2 tsp salt\noil", redoing: true))
    XCTAssertEqual(input.document.conflicts, [proposal])
    XCTAssertEqual(input.document.lines.map(\.id), lineIDs)
    XCTAssertEqual(input.document.sections.first?.ingredients.last, oil)
    XCTAssertTrue(draft.resolveIngredientInterpretation(proposal.id, accepting: false))
    XCTAssertTrue(input.document.conflicts.isEmpty)
    XCTAssertEqual(input.document.sections.first?.ingredients.first?.quantity?.lowerBound?.numerator, 1)
    XCTAssertTrue(input.isActive)
  }

  func testInvalidAndDuplicateNativeDeliveryCannotChangeTheLiveDraft() throws {
    let fixture = try IngredientTextEditingFixture()
    let input = fixture.draft.beginIngredientTextEditing()
    let before = fixture.draft.session
    for range in [NSRange(location: -1, length: 0), NSRange(location: 0, length: -1),
                  NSRange(location: Int.max, length: Int.max), NSRange(location: 0, length: 100),
    ] {
      XCTAssertFalse(input.replaceCharacters(in: range, with: "x", source: input.document.text))
    }
    XCTAssertFalse(input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: "stale"))
    XCTAssertFalse(input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "1", source: "1 tsp salt"))
    XCTAssertEqual(fixture.draft.session, before)
    XCTAssertTrue(input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: "1 tsp salt"))
    XCTAssertFalse(input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: "1 tsp salt"))
    XCTAssertTrue(input.observeNativeUndo(text: "1 tsp salt", redoing: false))
    XCTAssertFalse(input.observeNativeUndo(text: "1 tsp salt", redoing: false))
    XCTAssertEqual(fixture.draft.session, before)
    XCTAssertEqual(try fixture.store.load().first?.session, before)
  }

  func testReconciliationReplacementRetiresNativeCallbacks() throws {
    let fixture = try IngredientTextEditingFixture()
    let recipeID = Recipe.ID()
    let first = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "Soup", ingredientSections: [
      IngredientSection(ingredients: [IngredientLineParser.parse("1 tsp salt")]),
    ])
    let second = RecipeRevision(recipeID: recipeID, revisionNumber: 2, title: "Stew", ingredientSections: [
      IngredientSection(ingredients: [IngredientLineParser.parse("2 tsp salt")]),
    ])
    let comparison = try RecipeReconciliation(kitchenID: Kitchen.ID(), revisions: [first, second],
                                              observedSelectionIDs: [])
    let draft = try fixture.drafts.beginReconciliation(comparison)
    try draft.chooseRevision(first.id)
    let old = draft.beginIngredientTextEditing()
    try draft.chooseRevision(second.id)
    XCTAssertFalse(old.isActive)
    XCTAssertFalse(old.observeNativeUndo(text: "1 tsp salt", redoing: false))
    XCTAssertEqual(draft.session.ingredientSections, second.ingredientSections)
  }

  func testReplacementWithIdenticalWordingRetiresOldIdentityHistory() throws {
    let fixture = try IngredientTextEditingFixture()
    let draft = fixture.draft
    let old = draft.beginIngredientTextEditing()
    let oldID = try XCTUnwrap(old.document.sections.first?.ingredients.first?.id)
    var replacement = RecipeEditSession(draft: RecipeDraft(title: "Replacement", ingredientSections: [
      IngredientSection(ingredients: [IngredientLineParser.parse("1 tsp salt")]),
    ]))
    replacement.prepareIngredientText()
    draft.session = replacement
    XCTAssertFalse(old.isActive)
    XCTAssertFalse(old.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: "1 tsp salt"))
    XCTAssertEqual(draft.session, replacement)
    let current = draft.beginIngredientTextEditing()
    XCTAssertNotEqual(current.document.sections.first?.ingredients.first?.id, oldID)
    draft.session = RecipeEditSession(draft: RecipeDraft(title: "No text document"))
    XCTAssertFalse(current.isActive)
    XCTAssertFalse(current.completeLines())
    XCTAssertNil(draft.session.ingredientText)
  }

  func testModeCompletionRetiresCallbacksAndReopeningStartsNewHistory() throws {
    let fixture = try IngredientTextEditingFixture()
    let draft = fixture.draft
    let old = draft.beginIngredientTextEditing()
    XCTAssertTrue(old.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2",
                                        source: "1 tsp salt", locale: fixture.locale))
    XCTAssertTrue(draft.finishIngredientText(locale: fixture.locale))
    XCTAssertFalse(old.isActive)
    XCTAssertFalse(old.observeNativeUndo(text: "1 tsp salt", redoing: false))
    XCTAssertFalse(old.completeLines())
    XCTAssertEqual(draft.session.ingredientText?.text, "2 tsp salt")
    let reopened = draft.beginIngredientTextEditing()
    old.end()
    XCTAssertTrue(reopened.isActive)
    let line = try XCTUnwrap(reopened.document.lines.first)
    // With no native actions left, a fresh replacement is ordinary input, not restored history.
    XCTAssertTrue(reopened.replaceCharacters(in: NSRange(location: 0, length: 1), with: "3",
                                             source: "2 tsp salt", locale: fixture.locale))
    XCTAssertEqual(reopened.document.lines.first?.id, line.id)
    XCTAssertEqual(reopened.document.text, "3 tsp salt")
    reopened.end()
    XCTAssertFalse(reopened.isActive)
    XCTAssertFalse(reopened.replaceCharacters(in: NSRange(location: 0, length: 1), with: "4",
                                              source: "3 tsp salt"))
  }

  func testNativeUndoAndRedoRetainIdentityAndLaterPrecision() throws {
    let fixture = try IngredientTextEditingFixture()
    let draft = fixture.draft
    let input = draft.beginIngredientTextEditing()
    let original = try XCTUnwrap(draft.session.ingredientSections.first?.ingredients.first)

    XCTAssertTrue(input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2",
                                          source: "1 tsp salt", locale: fixture.locale))
    XCTAssertFalse(try XCTUnwrap(input.document.lines.first).isInterpreted)
    XCTAssertTrue(input.completeLines(locale: fixture.locale))
    var precise = try XCTUnwrap(draft.session.ingredientSections.first?.ingredients.first)
    precise.note = "Use fine salt"
    XCTAssertTrue(draft.updateIngredient(precise))

    XCTAssertTrue(input.observeNativeUndo(text: "1 tsp salt", redoing: false, locale: fixture.locale))
    let undone = try XCTUnwrap(draft.session.ingredientSections.first?.ingredients.first)
    XCTAssertEqual(undone.id, original.id)
    XCTAssertEqual(undone.quantity?.lowerBound?.numerator, 1)
    XCTAssertEqual(undone.note, "Use fine salt")
    XCTAssertTrue(input.observeNativeUndo(text: "2 tsp salt", redoing: true, locale: fixture.locale))
    let redone = try XCTUnwrap(draft.session.ingredientSections.first?.ingredients.first)
    XCTAssertEqual(redone.id, original.id)
    XCTAssertEqual(redone.quantity?.lowerBound?.numerator, 2)
    XCTAssertEqual(redone.note, "Use fine salt")
    XCTAssertEqual(draft.session.ingredientText?.sections, draft.session.ingredientSections)
    XCTAssertEqual(try fixture.store.load().first?.session, draft.session)
  }
}

@MainActor
private struct IngredientTextEditingFixture {
  let drafts: RecipeDrafts
  let draft: RecipeEditingDraft
  let store = VolatileRecipeEditingStore()
  let locale = Locale(identifier: "en_US")

  init(ingredients: [RecipeIngredient] = [IngredientLineParser.parse("1 tsp salt")]) throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                                samples: IngredientTextEditingSamples(), importer: RecipeImportService())
    let original = try library.create(from: RecipeDraft(title: "Soup", ingredientSections: [
      IngredientSection(ingredients: ingredients),
    ]))
    drafts = RecipeDrafts(library: library, store: store)
    draft = try XCTUnwrap(drafts.begin(original))
  }
}

@MainActor
private struct IngredientTextEditingSamples: SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] { [] }
}
