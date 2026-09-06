// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
final class RecipeReconciliationTests: XCTestCase {
  func testExplicitFieldChoicesPreserveUnknownContentAndAllParents() throws {
    let recipeID = Recipe.ID()
    let first = RecipeRevision(
      recipeID: recipeID, revisionNumber: 1, title: " Soup ", summary: "Original wording",
      ingredientSections: [IngredientSection(ingredients: [RecipeIngredient(originalText: "salt, as needed")])]
    )
    var second = RecipeRevision(recipeID: recipeID, revisionNumber: 2, title: "Stew")
    second.media = [RecipeMedia(role: .hero, imageData: Data([1, 2]))]
    var comparison = try RecipeReconciliation(
      kitchenID: Kitchen.ID(), revisions: [first, second], observedSelectionIDs: []
    )
    XCTAssertNil(comparison.draft)
    XCTAssertEqual(Set(try comparison.differences(between: first.id, and: second.id)),
                   [.title, .summary, .ingredients, .media])
    try comparison.chooseRevision(first.id)
    try comparison.choose(.media, from: second.id)
    let selected = try XCTUnwrap(comparison.draft)
    XCTAssertEqual(selected.title, " Soup ")
    XCTAssertEqual(selected.ingredientSections, first.ingredientSections)
    XCTAssertEqual(selected.media, second.media)
    XCTAssertEqual(Set(comparison.parentRevisionIDs), [first.id, second.id])
    let restored = try JSONDecoder().decode(RecipeReconciliation.self, from: JSONEncoder().encode(comparison))
    XCTAssertEqual(restored, comparison)
  }
  func testCompetingSelectionsRemainDiscoverableAndSaveNamesBothParents() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Reconciliation Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let original = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let observed = try repository.selectionHeads(for: original.id)
    for title in ["Bean soup", "Lentil soup"] {
      try repository.save(editor.prepareSave(
        in: kitchen.id, from: RecipeDraft(title: title), original: original, observedSelectionIDs: observed
      ))
    }
    XCTAssertTrue(try repository.recipes(in: kitchen.id).isEmpty)
    var comparison = try XCTUnwrap(repository.reconciliations(in: kitchen.id).first)
    XCTAssertEqual(comparison.revisions.count, 2)
    try comparison.chooseRevision(comparison.revisions[0].id)
    let command = try editor.prepareReconciliationSave(
      comparison, session: RecipeEditSession(draft: try XCTUnwrap(comparison.draft))
    )
    XCTAssertEqual(Set(command.parentRevisionIDs), Set(comparison.parentRevisionIDs))
    try repository.save(command)
    try repository.save(command)
    XCTAssertEqual(try repository.revisions(for: original.id).count, 4)
    XCTAssertTrue(try repository.reconciliations(in: kitchen.id).isEmpty)
    XCTAssertEqual(try repository.recipe(id: original.id)?.revision.id, command.revision.id)
    // A later-arriving command that never observed the reconciliation stays competing.
    try repository.save(editor.prepareSave(
      in: kitchen.id, from: RecipeDraft(title: "Late soup"), original: original, observedSelectionIDs: observed
    ))
    XCTAssertTrue(try repository.recipes(in: kitchen.id).isEmpty)
    XCTAssertEqual(try repository.reconciliations(in: kitchen.id).first?.revisions.count, 2)
  }

  func testComparisonChoicesAndFrozenSaveSurviveRelaunchWithoutOverwritingAnExistingDraft() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let original = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let observed = try repository.selectionHeads(for: original.id)
    for title in ["A", "B", "C"] {
      try repository.save(editor.prepareSave(in: kitchen.id, from: RecipeDraft(title: title),
                                            original: original, observedSelectionIDs: observed))
    }
    let comparison = try XCTUnwrap(repository.reconciliations(in: kitchen.id).first)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                                samples: ComparisonSamples(), importer: RecipeImportService())
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ComparisonStore(url: directory.appendingPathComponent("drafts.json"))
    var drafts = RecipeDrafts(library: library, store: store)
    let ordinary = try XCTUnwrap(drafts.begin(original))
    XCTAssertThrowsError(try drafts.beginReconciliation(comparison))
    XCTAssertTrue(drafts.discard(ordinary.id))
    let draft = try drafts.beginReconciliation(comparison)
    XCTAssertFalse(draft.canSaveRevision)
    XCTAssertNil(drafts.save(draft.id))
    try draft.chooseRevision(comparison.revisions[0].id)
    var session = draft.session
    session.title = "  Deliberate title  "
    draft.session = session
    drafts = RecipeDrafts(library: library, store: store)
    let restored = try XCTUnwrap(drafts.drafts.first)
    XCTAssertEqual(restored.session.title, "  Deliberate title  ")
    XCTAssertEqual(restored.reconciliation?.parentRevisionIDs.count, 3)
    XCTAssertEqual(try drafts.beginReconciliation(comparison).id, restored.id)
    store.failCleanup = true
    let saved = try XCTUnwrap(drafts.save(restored.id))
    XCTAssertFalse(saved.removedDraft)
    let frozen = try XCTUnwrap(restored.pendingSave)
    XCTAssertEqual(frozen.revision.title, "  Deliberate title  ")
    XCTAssertEqual(Set(frozen.parentRevisionIDs), Set(comparison.parentRevisionIDs))
    XCTAssertThrowsError(try restored.chooseRevision(comparison.revisions[1].id))
    drafts = RecipeDrafts(library: library, store: store)
    XCTAssertEqual(drafts.drafts.first?.pendingSave, frozen)
    store.failCleanup = false
    XCTAssertTrue(try XCTUnwrap(drafts.save(restored.id)).removedDraft)
    XCTAssertEqual(try repository.revisions(for: original.id).count, 5)
  }

  func testIdenticalContentIgnoresRowIdentityButReorderingAndUnknownValuesRemainVisible() throws {
    let recipeID = Recipe.ID()
    let first = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "Soup", ingredientSections: [
      IngredientSection(ingredients: [
        RecipeIngredient(originalText: "salt"), RecipeIngredient(originalText: "pepper"),
      ]),
    ])
    var second = RecipeRevision(recipeID: recipeID, revisionNumber: 2, title: "Soup", ingredientSections: [
      IngredientSection(ingredients: [
        RecipeIngredient(originalText: "salt"), RecipeIngredient(originalText: "pepper"),
      ]),
    ])
    var same = try RecipeReconciliation(kitchenID: Kitchen.ID(), revisions: [first, second], observedSelectionIDs: [])
    XCTAssertTrue(try same.differences(between: first.id, and: second.id).isEmpty)
    XCTAssertThrowsError(try same.choose(.title, from: first.id))
    XCTAssertThrowsError(try same.editedDraft(from: RecipeEditSession()))
    XCTAssertThrowsError(try same.chooseIngredient(from: first.id, section: 0, ingredient: 0, targetSection: 0))
    XCTAssertThrowsError(try same.chooseRevision(RecipeRevision.ID()))
    try same.chooseRevision(first.id)
    for field in RecipeComparisonField.allCases { try same.choose(field, from: second.id) }
    XCTAssertEqual(same.draft, RecipeDraft(revision: second))
    second.ingredientSections[0].ingredients.reverse()
    second.ingredientSections[0].ingredients[0].quantity = QuantityExpression(kind: .none, text: "unknown")
    var reordered = try RecipeReconciliation(kitchenID: Kitchen.ID(), revisions: [first, second],
                                            observedSelectionIDs: [])
    XCTAssertEqual(try reordered.differences(between: first.id, and: second.id), [.ingredients])
    try reordered.chooseRevision(first.id)
    try reordered.chooseIngredient(from: second.id, section: 0, ingredient: 0, targetSection: 0, replacing: 0)
    try reordered.chooseIngredient(from: second.id, section: 0, ingredient: 1, targetSection: 0)
    XCTAssertEqual(reordered.draft?.ingredientSections[0].ingredients.map(\.originalText),
                   ["pepper", "pepper", "salt"])
    XCTAssertEqual(reordered.draft?.ingredientSections[0].ingredients[0].quantity?.text, "unknown")
    XCTAssertEqual(Set(reordered.draft?.ingredientSections[0].ingredients.map(\.id) ?? []).count, 3)
    XCTAssertThrowsError(try reordered.chooseIngredient(from: first.id, section: -1, ingredient: 0, targetSection: 0))
    XCTAssertThrowsError(try reordered.chooseIngredient(from: first.id, section: 0, ingredient: 0,
                                                      targetSection: 0, replacing: 99))
    XCTAssertThrowsError(try RecipeReconciliation(kitchenID: Kitchen.ID(), revisions: [first],
                                                  observedSelectionIDs: []))
  }

  func testSavePreservesUneditedAuthoredValuesInsteadOfNormalizingThem() throws {
    let recipeID = Recipe.ID()
    let unknown = QuantityExpression(kind: .none, text: " as available ")
    let first = RecipeRevision(
      recipeID: recipeID, revisionNumber: 1, title: " Soup ", summary: "  Notes  ", authorName: "  Cook  ",
      source: RecipeSource(kind: .book, title: "  Notebook  "),
      recipeYield: RecipeYield(quantity: unknown, originalText: "  a pot  "),
      prepDuration: RecipeDuration(seconds: 91),
      media: [RecipeMedia(role: .hero, imageData: Data([7, 8]))],
      equipment: [EquipmentItem(originalText: "  pot  ", quantity: unknown, name: "  pan  ")],
      ingredientSections: [IngredientSection(title: " Base ", ingredients: [
        RecipeIngredient(originalText: " salt  ", quantity: unknown),
      ]),
      ],
      instructionSections: [InstructionSection(title: " Method ", steps: [InstructionStep(text: "  Stir  ")])]
    )
    let second = RecipeRevision(recipeID: recipeID, revisionNumber: 2, title: "Other")
    var comparison = try RecipeReconciliation(kitchenID: Kitchen.ID(), revisions: [first, second],
                                             observedSelectionIDs: [])
    try comparison.chooseRevision(first.id)
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let editor = RecipeEditor(repository: repository)
    let session = RecipeEditSession(draft: try XCTUnwrap(comparison.draft))
    let command = try editor.prepareReconciliationSave(comparison, session: session)
    let result = command.revision
    XCTAssertEqual(result.title, " Soup ")
    XCTAssertEqual(result.summary, "  Notes  ")
    XCTAssertEqual(result.authorName, "  Cook  ")
    XCTAssertEqual(result.source, first.source)
    XCTAssertEqual(result.recipeYield, first.recipeYield)
    XCTAssertEqual(result.prepDuration?.seconds, 91)
    XCTAssertEqual(result.media, first.media)
    XCTAssertEqual(result.equipment.first?.quantity, unknown)
    XCTAssertEqual(result.equipment.first?.originalText, "  pot  ")
    XCTAssertEqual(result.ingredientSections.first?.ingredients.first?.quantity, unknown)
    XCTAssertEqual(result.instructionSections.first?.steps.first?.text, "  Stir  ")
    XCTAssertNotEqual(result.ingredientSections.first?.id, first.ingredientSections.first?.id)
    let maximum = RecipeRevision(recipeID: recipeID, revisionNumber: Int.max, title: "Overflow")
    let invalid = try RecipeReconciliation(kitchenID: Kitchen.ID(), revisions: [first, maximum],
                                          observedSelectionIDs: [])
    XCTAssertThrowsError(try editor.prepareReconciliationSave(invalid, session: RecipeEditSession()))
  }

}

private struct ComparisonSamples: SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] { [] }
}

@MainActor
private final class ComparisonStore: RecipeEditingStoring {
  let file: FileRecipeEditingStore
  var failCleanup = false
  init(url: URL) { file = FileRecipeEditingStore(url: url) }
  func load() throws -> [RecipeEditingRecord] { try file.load() }
  func save(_ drafts: [RecipeEditingRecord]) throws {
    if drafts.isEmpty, failCleanup { throw CocoaError(.fileWriteUnknown) }
    try file.save(drafts)
  }
}
