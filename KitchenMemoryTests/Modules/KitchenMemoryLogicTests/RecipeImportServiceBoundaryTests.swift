// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryLogic
import Foundation
import KitchenMemoryDomain
import KitchenMemoryImport
import XCTest

final class RecipeImportServiceBoundaryTests: XCTestCase {
  func testImporterFailuresBecomeStableProductFailures() async {
    let mappings: [(Error, RecipeImportServiceError?)] = [
      (RecipeURLImportError.disallowedURL, .disallowedAddress),
      (RecipeURLImportError.tooManyRedirects, .disallowedAddress),
      (RecipeURLImportError.responseTooLarge(maximumBytes: 1), .pageTooLarge),
      (RecipeURLImportError.tooManyCandidates(maximum: 1), .pageTooLarge),
      (RecipeURLImportError.processingLimitExceeded, .pageTooLarge),
      (RecipeURLImportError.unsupportedContentType, .unsupportedPage),
      (RecipeURLImportError.undecodableDocument, .unsupportedPage),
      (RecipeURLImportError.invalidResponse, .unsupportedPage),
      (URLError(.cannotConnectToHost), .networkFailure),
      (CancellationError(), nil),
    ]

    for (error, expected) in mappings {
      let service = RecipeImportService(importer: ImporterStub(result: .failure(error)))
      do {
        _ = try await service.importRecipe(from: URL(string: "https://example.com")!)
        XCTFail("Expected \(error)")
      } catch is CancellationError {
        XCTAssertNil(expected)
      } catch {
        XCTAssertEqual(error as? RecipeImportServiceError, expected)
      }
    }
  }

  func testSuccessfulImportUsesInjectedClockAndRequestedURLFallback() async throws {
    let capturedAt = Date(timeIntervalSince1970: 42)
    let candidate = RecipeImportCandidate(
      id: .init(blockIndex: 1, objectIndex: 2),
      draft: RecipeImportDraft(
        title: "",
        source: RecipeSource(kind: .webpage),
        ingredientSections: [],
        instructionSections: []
      ),
      snapshot: RecipeImportSourceSnapshot(documentURL: nil, jsonLD: Data("{}".utf8))
    )
    let service = RecipeImportService(
      importer: ImporterStub(result: .success(RecipeImportResult(candidates: [candidate]))),
      now: { capturedAt }
    )
    let requestedURL = URL(string: "https://example.com/soup")!

    let options = try await service.importRecipe(from: requestedURL)
    let option = try XCTUnwrap(options.first)

    XCTAssertEqual(option.draft.source?.canonicalURL, requestedURL)
    XCTAssertEqual(option.draft.sourceCapture?.capturedAt, capturedAt)
    XCTAssertEqual(option.concerns, [.missingTitle, .missingIngredients, .missingInstructions])
    XCTAssertFalse(option.concerns[0].isInformational)
  }

  func testPublisherURLIsFallbackWhenNoFetchedDocumentURLExists() throws {
    let publisherURL = URL(string: "https://publisher.example/soup")!
    let candidate = RecipeImportCandidate(
      id: .init(blockIndex: 0, objectIndex: 0),
      draft: RecipeImportDraft(
        title: "Soup",
        source: RecipeSource(kind: .webpage, canonicalURL: publisherURL),
        instructionSections: [
          InstructionSection(steps: [InstructionStep(text: "Cook.")]),
        ]
      ),
      snapshot: RecipeImportSourceSnapshot(documentURL: nil, jsonLD: Data())
    )

    let option = try XCTUnwrap(RecipeImportService.options(
      from: RecipeImportResult(
        candidates: [candidate],
        diagnostics: [
          .init(blockIndex: 1, kind: .unsupportedTopLevel),
          .init(blockIndex: 2, kind: .missingTitle),
        ]
      ),
      requestedURL: URL(string: "https://request.example")!,
      capturedAt: Date()
    ).first)

    XCTAssertEqual(option.draft.source?.canonicalURL, publisherURL)
    XCTAssertEqual(option.concerns, [
      .missingIngredients,
      .ignoredSourceBlocks(count: 1),
    ])
  }

  func testDefaultClockProducesACaptureTimestamp() async throws {
    let candidate = RecipeImportCandidate(
      id: .init(blockIndex: 0, objectIndex: 0),
      draft: RecipeImportDraft(title: "Soup", source: RecipeSource(kind: .webpage)),
      snapshot: RecipeImportSourceSnapshot(documentURL: nil, jsonLD: Data())
    )
    let service = RecipeImportService(importer: ImporterStub(
      result: .success(RecipeImportResult(candidates: [candidate]))
    ))

    let options = try await service.importRecipe(from: URL(string: "https://example.com")!)

    XCTAssertNotNil(options.first?.draft.sourceCapture?.capturedAt)
  }
}

private struct ImporterStub: RecipeURLImporting {
  let result: Result<RecipeImportResult, Error>

  func importRecipe(from url: URL) async throws -> RecipeImportResult {
    try result.get()
  }
}
