// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

@MainActor
final class RecipeImportStagingTests: XCTestCase {
  func testDocumentEntryPointStagesLocallyAndAbandonmentDoesNotChangeLibrary() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("recipe.json")
    try Data(#"{"@context":"https://schema.org","@type":"Recipe","name":"Document soup"}"#.utf8)
      .write(to: url)
    let app = try AppRuntime.testing()
    let model = app.libraryModel
    model.loadIfNeeded()
    let before = model.recipes
    let options = try model.importDocument(from: url)
    XCTAssertEqual(options.first?.draft.title, "Document soup")
    XCTAssertEqual(model.importCandidates.count, 1)
    XCTAssertTrue(model.beginImportReview(try XCTUnwrap(options.first)))
    model.discardEditor(confirmed: true)
    XCTAssertTrue(model.authoringItems.isEmpty)
    XCTAssertEqual(model.recipes, before)
    try Data().write(to: url)
    XCTAssertThrowsError(try model.importDocument(from: url))
    XCTAssertTrue(model.authoringItems.isEmpty)
  }

  func testCandidateResumesAndAcceptanceCreatesOnlyALocalDraftUntilSave() throws {
    let app = try AppRuntime.testing()
    let model = app.libraryModel
    model.loadIfNeeded()
    let initialCount = model.recipes.count
    let capture = RecipeSourceCapture(
      kind: .schemaOrgJSONLD, sourceURL: try XCTUnwrap(URL(string: "https://example.com/soup")),
      capturedAt: Date(timeIntervalSince1970: 100), mediaType: "application/ld+json",
      payload: Data("{\"unknown\":\"keep original spelling\"}".utf8), blockIndex: 0, objectIndex: 0
    )
    let option = RecipeImportOption(
      id: .init(blockIndex: 0, objectIndex: 0),
      draft: RecipeDraft(sourceCapture: capture, ingredientSections: [
        IngredientSection(ingredients: [RecipeIngredient(originalText: "a little salt")]),
      ]),
      concerns: [.missingTitle, .missingInstructions]
    )
    try model.stageImports([option, option])
    XCTAssertEqual(model.importCandidates.count, 1)
    XCTAssertTrue(model.editingDrafts.isEmpty)
    let candidateID = try XCTUnwrap(model.importCandidates.first?.id)
    model.resumeEditingDraft(candidateID)
    model.editor?.session.title = "Reviewed soup"
    XCTAssertFalse(model.saveEditor())
    model.closeEditor()

    let relaunched = RecipeLibraryModel(
      library: model.library,
      samplePreferences: VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted),
      kitchenWasCreated: false, editingStore: model.editingStore
    )
    relaunched.loadIfNeeded()
    XCTAssertEqual(relaunched.importCandidates.first?.concerns, option.concerns)
    XCTAssertTrue(relaunched.acceptImportCandidate(candidateID))
    XCTAssertTrue(relaunched.acceptImportCandidate(candidateID))
    XCTAssertTrue(relaunched.importCandidates.isEmpty)
    XCTAssertEqual(relaunched.editingDrafts.count, 1)
    XCTAssertEqual(relaunched.recipes.count, initialCount)
    XCTAssertTrue(relaunched.saveEditor())
    XCTAssertEqual(relaunched.recipes.count, initialCount + 1)
    XCTAssertEqual(relaunched.selectedRecipe?.revision.sourceCapture, capture)
    XCTAssertFalse(relaunched.acceptImportCandidate(candidateID))
  }
}
