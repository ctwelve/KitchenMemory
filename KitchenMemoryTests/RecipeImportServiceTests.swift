// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemory
import Foundation
import KitchenMemoryDomain
import KitchenMemoryImport
import XCTest

@MainActor
final class RecipeImportServiceTests: XCTestCase {
  // This test intentionally keeps one complete imported candidate and all of
  // its mapped evidence visible together.
  // swiftlint:disable:next function_body_length
  func testMapsCandidateToEditableDraftWithBoundedSourceCaptureAndConcerns() throws {
    let requestedURL = URL(string: "https://short.example/soup")!
    let sourceURL = URL(string: "https://fetched.example/recipe")!
    let publisherCanonicalURL = URL(string: "https://canonical.example/soup")!
    let payload = Data(
      #"{"@type":"Recipe","name":"Soup","url":"https://canonical.example/soup"}"#.utf8
    )
    let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)
    let candidate = RecipeImportCandidate(
      id: .init(blockIndex: 2, objectIndex: 4),
      draft: RecipeImportDraft(
        title: "Soup",
        source: RecipeSource(kind: .webpage, canonicalURL: publisherCanonicalURL),
        cuisines: ["French"],
        categories: ["Dinner"],
        keywords: ["quick"],
        imageURLs: [
          URL(string: "https://example.com/soup.jpg")!,
          URL(string: "https://example.com/soup-2.jpg")!,
        ],
        ingredientSections: [
          IngredientSection(ingredients: [
            RecipeIngredient(originalText: "salt", presentationMode: .original),
            RecipeIngredient(
              originalText: "2 cups water",
              presentationMode: .original,
              parseState: .parsed
            ),
          ]),
        ]
      ),
      snapshot: RecipeImportSourceSnapshot(
        documentURL: sourceURL,
        jsonLD: payload
      )
    )

    let options = try RecipeImportService.options(
      from: RecipeImportResult(
        candidates: [candidate],
        diagnostics: [.init(blockIndex: 7, kind: .malformedJSONLD)]
      ),
      requestedURL: requestedURL,
      capturedAt: capturedAt
    )
    let option = try XCTUnwrap(options.first)

    XCTAssertEqual(option.draft.cuisines, ["French"])
    XCTAssertEqual(option.draft.categories, ["Dinner"])
    XCTAssertEqual(option.draft.keywords, ["quick"])
    XCTAssertEqual(option.concerns, [
      .missingInstructions,
      .unparsedIngredients(count: 1),
      .provisionalIngredients(count: 1),
      .ignoredSourceBlocks(count: 1),
      .preservedTaxonomy(cuisines: ["French"], categories: ["Dinner"], keywords: ["quick"]),
      .referencedImages(count: 2),
    ])
    XCTAssertEqual(option.concerns.last?.isInformational, true)
    XCTAssertEqual(option.draft.source?.canonicalURL, sourceURL)
    XCTAssertEqual(option.draft.sourceCapture?.sourceURL, sourceURL)
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
