// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import XCTest

@MainActor
final class RecipeIngredientLifecycleTests: XCTestCase {
  func testDetailBindingsCannotReplaceIngredientsOrHiddenMetadata() throws {
    let fixture = try IngredientLifecycleFixture()
    let draft = try XCTUnwrap(fixture.drafts.begin(fixture.original))
    let input = draft.beginIngredientTextEditing()
    input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: input.document.text)
    let ingredients = draft.session.ingredientSections
    let document = input.document
    var foreign = RecipeEditSession(draft: RecipeDraft(title: "Stew", cuisines: ["Foreign"], ingredientSections: []))
    foreign.summary = "New summary"
    foreign.authorName = "Cook"
    foreign.recipeYield = RecipeYield(originalText: "Four portions")
    foreign.prepMinutes = "10"
    foreign.cookMinutes = "20"
    foreign.totalMinutes = "30"
    foreign.sourceKind = .webpage
    foreign.sourceTitle = "Source"
    foreign.sourceAuthor = "Writer"
    foreign.sourcePublisher = "Publisher"
    foreign.sourceURL = "https://example.com/soup"
    foreign.media = [RecipeMedia(role: .hero, assetName: "soup")]
    foreign.equipment = [EquipmentItem(originalText: "Pot", name: "Pot")]
    foreign.instructionSections = [InstructionSection(steps: [InstructionStep(text: "Simmer")])]
    XCTAssertTrue(draft.updateRecipeDetails(from: foreign))
    XCTAssertEqual(draft.session.ingredientSections, ingredients)
    XCTAssertEqual(input.document, document)
    XCTAssertTrue(input.isActive)
    let contents = try draft.session.validatedDraft()
    let expected = try foreign.validatedDraft()
    XCTAssertEqual(contents.title, expected.title)
    XCTAssertEqual(contents.summary, expected.summary)
    XCTAssertEqual(contents.authorName, expected.authorName)
    XCTAssertEqual(contents.recipeYield, expected.recipeYield)
    XCTAssertEqual(contents.prepDuration, expected.prepDuration)
    XCTAssertEqual(contents.cookDuration, expected.cookDuration)
    XCTAssertEqual(contents.totalDuration, expected.totalDuration)
    XCTAssertEqual(contents.source, expected.source)
    XCTAssertEqual(contents.media, expected.media)
    XCTAssertEqual(contents.equipment, expected.equipment)
    XCTAssertEqual(contents.instructionSections, expected.instructionSections)
    XCTAssertEqual(contents.cuisines, ["Original"])
    XCTAssertEqual(contents.contentLanguage, fixture.original.revision.contentLanguage)
    XCTAssertEqual(contents.sourceCapture, fixture.original.revision.sourceCapture)
    XCTAssertEqual(contents.categories, fixture.original.revision.categories)
    XCTAssertEqual(contents.keywords, fixture.original.revision.keywords)
    XCTAssertEqual(try fixture.store.load().first?.session, draft.session)
    XCTAssertFalse(draft.updateRecipeDetails(from: foreign))
    XCTAssertTrue(try XCTUnwrap(fixture.drafts.save(draft.id)).removedDraft)
    let frozen = draft.session
    foreign.title = "Too late"
    XCTAssertFalse(draft.updateRecipeDetails(from: foreign))
    XCTAssertEqual(draft.session, frozen)
  }

  func testFieldAndRowChoicesPreserveUntouchedPendingTextAndProposals() throws {
    let fixture = try IngredientLifecycleFixture()
    let comparison = try fixture.comparison()
    let draft = try fixture.drafts.beginReconciliation(comparison)
    try draft.chooseRevision(comparison.revisions[0].id)
    let input = draft.beginIngredientTextEditing()
    input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: input.document.text)
    input.completeLines(locale: Locale(identifier: "en_US"))
    let proposal = try XCTUnwrap(input.document.conflicts.first)
    let end = (input.document.text as NSString).length
    input.replaceCharacters(in: NSRange(location: end, length: 0), with: ", fresh", source: input.document.text)
    let pending = input.document
    XCTAssertFalse(try XCTUnwrap(pending.lines.last).isInterpreted)

    try draft.choose(.title, from: comparison.revisions[1].id)
    XCTAssertEqual(draft.session.title, "Stew")
    XCTAssertEqual(draft.session.ingredientText, pending)
    XCTAssertEqual(draft.session.ingredientSections, pending.sections)
    XCTAssertFalse(input.isActive)

    try draft.chooseIngredient(from: comparison.revisions[1].id, section: 0, ingredient: 0,
                               targetSection: 0)
    let appended = try XCTUnwrap(draft.session.ingredientText)
    XCTAssertEqual(Array(appended.lines.prefix(2)), pending.lines)
    XCTAssertEqual(appended.conflicts, [proposal])
    XCTAssertEqual(appended.sections, draft.session.ingredientSections)
    XCTAssertEqual(try fixture.store.load().first?.session, draft.session)

    try draft.choose(.ingredients, from: comparison.revisions[1].id)
    XCTAssertEqual(draft.session.ingredientSections, comparison.revisions[1].ingredientSections)
    XCTAssertNil(draft.session.ingredientText)
  }

  func testRecoveryRepairsLegacyRepresentationMismatchBeforeExposingTheDraft() throws {
    let fixture = try IngredientLifecycleFixture()
    let draft = try XCTUnwrap(fixture.drafts.begin(fixture.original))
    let input = draft.beginIngredientTextEditing()
    input.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: input.document.text)
    input.completeLines(locale: Locale(identifier: "en_US"))
    let text = input.document
    var record = try XCTUnwrap(fixture.store.load().first)
    var sections = record.session.ingredientSections
    sections[0].ingredients[1].note = "Legacy precision write"
    // Model a pre-sealing record whose structured write did not update its text document.
    var object = try XCTUnwrap(JSONSerialization.jsonObject(
      with: JSONEncoder().encode(record.session)) as? [String: Any])
    object["ingredientSections"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(sections))
    record.session = try JSONDecoder().decode(RecipeEditSession.self,
                                               from: JSONSerialization.data(withJSONObject: object))
    try fixture.store.save([record])
    let restored = RecipeDrafts(library: fixture.library, store: fixture.store)
    let recovered = try XCTUnwrap(restored.drafts.first)
    XCTAssertEqual(recovered.session.ingredientSections, sections)
    XCTAssertEqual(recovered.session.ingredientText?.sections, sections)
    XCTAssertEqual(recovered.session.ingredientText?.lines.map(\.id), text.lines.map(\.id))
    XCTAssertEqual(recovered.session.ingredientText?.conflicts, text.conflicts)
    XCTAssertTrue(restored.prepareToLeave())
    XCTAssertEqual(try fixture.store.load().first?.session, recovered.session)
  }

  func testFileRecoveryRetainsProposalsPendingTextAndPrecisionButNotNativeHistory() throws {
    let fixture = try IngredientLifecycleFixture()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileRecipeEditingStore(url: directory.appendingPathComponent("drafts.json"))
    var owner: RecipeDrafts? = RecipeDrafts(library: fixture.library, store: store)
    var editing: RecipeEditingDraft? = try XCTUnwrap(owner?.begin(fixture.original))
    var input: RecipeIngredientTextEditing? = editing?.beginIngredientTextEditing()
    input?.replaceCharacters(in: NSRange(location: 0, length: 1), with: "2", source: "1 tsp salt\noil")
    input?.completeLines(locale: Locale(identifier: "en_US"))
    let proposal = try XCTUnwrap(input?.document.conflicts.first)
    XCTAssertEqual(editing?.finishIngredientText(), false)
    XCTAssertEqual(owner?.prepareToLeave(), true)
    let retained = try XCTUnwrap(editing?.session)
    let editorID = editing?.ingredientTextEditorID
    input = nil
    editing = nil
    owner = nil

    let recovered = RecipeDrafts(library: fixture.library, store: FileRecipeEditingStore(url: store.url))
    let draft = try XCTUnwrap(recovered.drafts.first)
    XCTAssertEqual(draft.session, retained)
    XCTAssertNotEqual(draft.ingredientTextEditorID, editorID)
    let reopened = draft.beginIngredientTextEditing()
    XCTAssertEqual(reopened.document.conflicts, [proposal])
    // Begin a second edit, then simulate process termination without Close.
    let end = (reopened.document.text as NSString).length
    reopened.replaceCharacters(in: NSRange(location: end, length: 0), with: ", fresh", source: reopened.document.text)
    let pending = reopened.document
    let relaunched = RecipeDrafts(library: fixture.library, store: FileRecipeEditingStore(url: store.url))
    let restored = try XCTUnwrap(relaunched.drafts.first)
    XCTAssertEqual(restored.session.ingredientText, pending)
    XCTAssertEqual(restored.session.ingredientSections, pending.sections)
    XCTAssertEqual(restored.session.ingredientText?.conflicts, [proposal])
    XCTAssertFalse(try XCTUnwrap(restored.session.ingredientText?.lines.last).isInterpreted)
    let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: store.url)) as? [String: Any])
    XCTAssertEqual(encoded["version"] as? Int, 1)
    XCTAssertTrue(try XCTUnwrap(relaunched.save(restored.id)).removedDraft)
    let revision = try XCTUnwrap(fixture.library.load().recipes.first?.revision)
    let salt = try XCTUnwrap(revision.ingredientSections.first?.ingredients.first)
    XCTAssertEqual(salt.originalText, "2 tsp salt")
    XCTAssertEqual(salt.quantity?.lowerBound?.numerator, 1)
    XCTAssertEqual(salt.note, "Use fine salt")
    let published = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(revision)) as? [String: Any])
    XCTAssertNil(published["ingredientText"])
    XCTAssertNil(published["ingredientTextEditorID"])
    XCTAssertNil(published["conflicts"])
  }
}

@MainActor
private struct IngredientLifecycleFixture {
  let library: RecipeLibrary
  let original: StoredRecipe
  let store = VolatileRecipeEditingStore()
  let drafts: RecipeDrafts

  init() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                            samples: IngredientLifecycleSamples(), importer: RecipeImportService())
    var salt = IngredientLineParser.parse("1 tsp salt")
    salt.note = "Use fine salt"
    let capture = RecipeSourceCapture(kind: .schemaOrgJSONLD,
                                      sourceURL: try XCTUnwrap(URL(string: "https://example.com/original")),
                                      capturedAt: Date(timeIntervalSince1970: 1), mediaType: "application/ld+json",
                                      payload: Data("{}".utf8), blockIndex: 0, objectIndex: 0)
    original = try library.create(from: RecipeDraft(
      title: "Soup", contentLanguage: RecipeContentLanguage(rawValue: "en"), sourceCapture: capture,
      cuisines: ["Original"], categories: ["Dinner"], keywords: ["Home"], ingredientSections: [
      IngredientSection(ingredients: [salt, IngredientLineParser.parse("oil")]),
    ]))
    drafts = RecipeDrafts(library: library, store: store)
  }

  func comparison() throws -> RecipeReconciliation {
    let second = RecipeRevision(recipeID: original.id, revisionNumber: 2, title: "Stew", ingredientSections: [
      IngredientSection(ingredients: [IngredientLineParser.parse("tomatoes")]),
    ])
    return try RecipeReconciliation(kitchenID: original.recipe.kitchenID,
                                    revisions: [original.revision, second], observedSelectionIDs: [])
  }
}

@MainActor
private struct IngredientLifecycleSamples: SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] { [] }
}
