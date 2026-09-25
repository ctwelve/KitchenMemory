// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import XCTest

@MainActor
final class RecipeIngredientAuthoringTests: XCTestCase {
  func testPrecisionEditKeepsLiveAndPersistedRepresentationsConsistent() throws {
    let salt = IngredientLineParser.parse("1 tsp salt")
    let fixture = try Fixture(sections: [IngredientSection(ingredients: [salt])])
    let section = try XCTUnwrap(fixture.draft.session.ingredientSections.first)
    var adjusted = try XCTUnwrap(section.ingredients.first)
    adjusted.note = "Use fine salt"
    adjusted.quantity = QuantityExpression(kind: .exact, lowerBound: RationalQuantity(numerator: 3, denominator: 2))

    XCTAssertTrue(fixture.draft.updateIngredient(adjusted))

    let session = fixture.draft.session
    XCTAssertEqual(session.ingredientSections[0].id, section.id)
    XCTAssertEqual(session.ingredientSections[0].ingredients, [adjusted])
    XCTAssertEqual(session.ingredientText?.text, "1 tsp salt")
    XCTAssertEqual(session.ingredientText?.sections, session.ingredientSections)
    XCTAssertEqual(try fixture.store.load().first?.session, session)
    XCTAssertEqual(try fixture.library.load().recipes.first?.revision.ingredientSections, [section])
    XCTAssertEqual(fixture.store.writes.count, 2)
    XCTAssertEqual(fixture.store.writes.last?.first?.session.ingredientText?.sections,
                   fixture.store.writes.last?.first?.session.ingredientSections)
  }

  func testStructuralOperationsShareTheLiveDraftAndRetainAuthoredOrder() throws {
    let fixture = try Fixture(sections: [IngredientSection(ingredients: [IngredientLineParser.parse("salt")])])
    let first = try XCTUnwrap(fixture.draft.session.ingredientSections.first)
    let secondID = try XCTUnwrap(fixture.draft.addIngredientSection(title: "Sauce"))
    let tomatoID = try XCTUnwrap(fixture.draft.addIngredient(to: secondID))
    let oilID = try XCTUnwrap(fixture.draft.addIngredient(to: secondID))
    var tomato = try XCTUnwrap(fixture.draft.session.ingredientSections.last?.ingredients.first)
    tomato.ingredientText = "tomatoes"
    tomato.note = "Crush by hand"
    XCTAssertTrue(fixture.draft.updateIngredient(tomato))
    XCTAssertTrue(fixture.draft.moveIngredient(oilID, by: -1))
    XCTAssertEqual(fixture.draft.session.ingredientSections.last?.ingredients.map(\.id), [oilID, tomatoID])
    XCTAssertTrue(fixture.draft.renameIngredientSection(secondID, to: "Finish"))
    XCTAssertTrue(fixture.draft.moveIngredientSection(secondID, by: -1))
    XCTAssertEqual(fixture.draft.session.ingredientSections.map(\.id), [secondID, first.id])
    XCTAssertTrue(fixture.draft.removeIngredient(oilID))
    XCTAssertTrue(fixture.draft.removeIngredientSection(first.id))

    let session = fixture.draft.session
    XCTAssertEqual(session.ingredientSections,
                   [IngredientSection(id: secondID, title: "Finish", ingredients: [tomato])])
    XCTAssertEqual(session.ingredientText?.sections, session.ingredientSections)
    XCTAssertEqual(try fixture.store.load().first?.session, session)
    for records in fixture.store.writes.dropFirst() {
      let persisted = try XCTUnwrap(records.first?.session)
      XCTAssertEqual(persisted.ingredientText?.sections, persisted.ingredientSections)
    }
  }

  func testStaleAndOutOfRangeRequestsLeaveTheDraftAndPersistenceUntouched() throws {
    let fixture = try Fixture(sections: [IngredientSection(ingredients: [IngredientLineParser.parse("salt")])])
    let before = fixture.draft.session
    let section = try XCTUnwrap(before.ingredientSections.first)
    let ingredient = try XCTUnwrap(section.ingredients.first)
    let missing = RecipeIngredient()
    let missingSection = IngredientSection.ID()
    XCTAssertFalse(fixture.draft.updateIngredient(ingredient))
    XCTAssertFalse(fixture.draft.updateIngredient(missing))
    XCTAssertNil(fixture.draft.addIngredient(to: missingSection))
    XCTAssertFalse(fixture.draft.removeIngredient(missing.id))
    XCTAssertFalse(fixture.draft.moveIngredient(missing.id, by: 1))
    XCTAssertFalse(fixture.draft.renameIngredientSection(missingSection, to: "Gone"))
    XCTAssertFalse(fixture.draft.removeIngredientSection(missingSection))
    XCTAssertFalse(fixture.draft.moveIngredientSection(missingSection, by: 1))
    XCTAssertFalse(fixture.draft.resolveIngredientInterpretation(ingredient.id, accepting: true))
    for offset in [-1, 0, 1, Int.max, Int.min] {
      XCTAssertFalse(fixture.draft.moveIngredient(ingredient.id, by: offset))
      XCTAssertFalse(fixture.draft.moveIngredientSection(section.id, by: offset))
    }
    XCTAssertEqual(fixture.draft.session, before)
    XCTAssertEqual(fixture.store.writes.count, 1)
  }

  func testFrozenSaveRejectsStructuredAndInterpretationEditsWithoutChangingItsIntention() throws {
    let fixture = try Fixture(sections: [IngredientSection(ingredients: [IngredientLineParser.parse("salt")])])
    fixture.draft.prepareIngredientText()
    fixture.store.refusesRemoval = true
    XCTAssertFalse(try XCTUnwrap(fixture.drafts.save(fixture.draft.id)).removedDraft)
    let command = try XCTUnwrap(fixture.draft.pendingSave)
    let before = fixture.draft.session
    let writes = fixture.store.writes.count
    let section = try XCTUnwrap(before.ingredientSections.first)
    var ingredient = try XCTUnwrap(section.ingredients.first)
    ingredient.note = "Too late"
    XCTAssertFalse(fixture.draft.updateIngredient(ingredient))
    XCTAssertNil(fixture.draft.addIngredient(to: section.id))
    XCTAssertFalse(fixture.draft.removeIngredient(ingredient.id))
    XCTAssertFalse(fixture.draft.moveIngredient(ingredient.id, by: 1))
    XCTAssertNil(fixture.draft.addIngredientSection())
    XCTAssertFalse(fixture.draft.renameIngredientSection(section.id, to: "Too late"))
    XCTAssertFalse(fixture.draft.removeIngredientSection(section.id))
    XCTAssertFalse(fixture.draft.moveIngredientSection(section.id, by: 1))
    XCTAssertFalse(fixture.draft.prepareIngredientText())
    XCTAssertFalse(fixture.draft.finishIngredientText())
    XCTAssertFalse(fixture.draft.resolveIngredientInterpretation(ingredient.id, accepting: true))
    XCTAssertEqual(fixture.draft.pendingSave, command)
    XCTAssertEqual(fixture.draft.session, before)
    XCTAssertEqual(fixture.store.writes.count, writes)
    fixture.store.refusesRemoval = false
    XCTAssertTrue(try XCTUnwrap(fixture.drafts.save(fixture.draft.id)).removedDraft)
  }

  func testStructuralEditsRetainSurvivingLineIdentitiesAndUnresolvedProposals() throws {
    var salt = IngredientLineParser.parse("1 tsp salt")
    salt.parseState = .reviewed
    let fixture = try Fixture(sections: [IngredientSection(title: "Main", ingredients: [salt])])
    let input = fixture.draft.beginIngredientTextEditing()
    input.replaceCharacters(in: NSRange(location: 7, length: 1), with: "2", source: input.document.text)
    input.completeLines(locale: Locale(identifier: "en_US"))
    let text = input.document
    let sectionID = try XCTUnwrap(text.sections.first?.id)
    let lineIDs = text.lines.map(\.id)
    let proposal = try XCTUnwrap(text.conflicts.first)

    XCTAssertTrue(fixture.draft.renameIngredientSection(sectionID, to: "Soup"))
    XCTAssertEqual(fixture.draft.session.ingredientText?.lines.map(\.id), lineIDs)
    let otherID = try XCTUnwrap(fixture.draft.addIngredientSection(title: "Finish"))
    XCTAssertTrue(fixture.draft.moveIngredientSection(otherID, by: -1))

    let current = try XCTUnwrap(fixture.draft.session.ingredientText)
    XCTAssertEqual(Array(current.lines.suffix(2)).map(\.id), lineIDs)
    XCTAssertEqual(current.conflicts, [proposal])
    XCTAssertEqual(current.text, "# Finish\n# Soup\n2 tsp salt")
    XCTAssertEqual(current.sections.last?.ingredients.first?.quantity, salt.quantity)
    XCTAssertEqual(try fixture.store.load().first?.session.ingredientText, current)
  }

  func testInterpretationChoicesAndModeCompletionKeepExplicitPrecision() throws {
    for accept in [false, true] {
      var salt = IngredientLineParser.parse("1 tsp salt")
      salt.note = "Use fine salt"
      let fixture = try Fixture(sections: [IngredientSection(ingredients: [salt])])
      let input = fixture.draft.beginIngredientTextEditing()
      let ingredientID = try XCTUnwrap(input.document.sections.first?.ingredients.first?.id)
      input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: input.document.text)

      XCTAssertTrue(fixture.draft.finishIngredientText(locale: Locale(identifier: "en_US")))
      XCTAssertEqual(fixture.draft.session.ingredientText?.conflicts.count, 1)
      XCTAssertTrue(fixture.draft.resolveIngredientInterpretation(ingredientID, accepting: accept))

      let ingredient = try XCTUnwrap(fixture.draft.session.ingredientSections.first?.ingredients.first)
      XCTAssertEqual(ingredient.id, ingredientID)
      XCTAssertEqual(ingredient.note, "Use fine salt")
      XCTAssertEqual(ingredient.originalText, "2 tsp salt")
      XCTAssertEqual(ingredient.quantity?.lowerBound?.numerator, accept ? 2 : 1)
      XCTAssertEqual(fixture.draft.session.ingredientText?.sections, fixture.draft.session.ingredientSections)
      XCTAssertEqual(try fixture.store.load().first?.session, fixture.draft.session)
      XCTAssertFalse(fixture.draft.finishIngredientText())
      XCTAssertFalse(fixture.draft.prepareIngredientText())
      XCTAssertFalse(fixture.draft.resolveIngredientInterpretation(ingredientID, accepting: !accept))
    }
  }

  @MainActor
  private struct Fixture {
    let library: RecipeLibrary
    let store = IngredientAuthoringStore()
    let drafts: RecipeDrafts
    let draft: RecipeEditingDraft

    init(sections: [IngredientSection]) throws {
      let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
      let kitchen = Kitchen(name: "Home")
      try repository.save(kitchen)
      library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                              samples: IngredientAuthoringSamples(), importer: RecipeImportService(),
      sampleFolderName: "Sample Pack", sampleTagName: "samples")
      let original = try library.create(from: RecipeDraft(title: "Soup", ingredientSections: sections))
      drafts = RecipeDrafts(library: library, store: store)
      draft = try XCTUnwrap(drafts.begin(original))
    }
  }
}

@MainActor
private struct IngredientAuthoringSamples: SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] { [] }
}

@MainActor
private final class IngredientAuthoringStore: RecipeEditingStoring {
  var writes: [[RecipeEditingRecord]] = []
  var refusesRemoval = false
  func load() throws -> [RecipeEditingRecord] { writes.last ?? [] }
  func save(_ drafts: [RecipeEditingRecord]) throws {
    if refusesRemoval && drafts.isEmpty { throw CocoaError(.fileWriteUnknown) }
    writes.append(drafts)
  }
}
