// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryApplication
import Foundation
import KitchenMemoryDomain
import KitchenMemoryImport
import XCTest

final class RecipeImportServiceTests: XCTestCase {
  func testMapsCandidateToEditableDraftWithBoundedSourceCaptureAndConcerns() throws {
    let sourceURL = URL(string: "https://example.com/recipe")!
    let payload = Data(#"{"@type":"Recipe","name":"Soup"}"#.utf8)
    let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let candidate = RecipeImportCandidate(
      id: .init(blockIndex: 2, objectIndex: 4),
      draft: RecipeImportDraft(
        title: "Soup",
        source: RecipeSource(kind: .webpage, canonicalURL: sourceURL),
        cuisines: ["French"],
        categories: ["Dinner"],
        keywords: ["quick"],
        ingredientSections: [IngredientSection(ingredients: [
          RecipeIngredient(originalText: "salt", presentationMode: .original)
        ])]
      ),
      snapshot: RecipeImportSourceSnapshot(
        documentURL: sourceURL,
        jsonLD: payload,
        candidateJSONLD: Data("normalized duplicate is not persisted".utf8)
      )
    )

    let options = try RecipeImportService.options(
      from: RecipeImportResult(candidates: [candidate]),
      requestedURL: sourceURL,
      capturedAt: capturedAt
    )
    let option = try XCTUnwrap(options.first)

    XCTAssertEqual(option.draft.cuisines, ["French"])
    XCTAssertEqual(option.draft.categories, ["Dinner"])
    XCTAssertEqual(option.draft.keywords, ["quick"])
    XCTAssertEqual(option.concerns, [.missingInstructions, .unparsedIngredients(count: 1)])
    XCTAssertEqual(option.draft.sourceCapture?.payload, payload)
    XCTAssertEqual(option.draft.sourceCapture?.capturedAt, capturedAt)
    XCTAssertEqual(option.draft.sourceCapture?.blockIndex, 2)
    XCTAssertEqual(option.draft.sourceCapture?.objectIndex, 4)
  }

  func testRejectsAResultWithNoRecipeCandidates() {
    XCTAssertThrowsError(try RecipeImportService.options(
      from: RecipeImportResult(candidates: []),
      requestedURL: URL(string: "https://example.com")!,
      capturedAt: Date()
    )) { error in
      XCTAssertEqual(error as? RecipeImportServiceError, .noRecipeCandidates)
    }
  }
}
