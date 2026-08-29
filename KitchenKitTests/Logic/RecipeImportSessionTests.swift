// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

final class RecipeImportSessionTests: XCTestCase {
  func testNormalizesOnlyBoundedCredentialFreeHTTPSURLs() {
    var session = RecipeImportSession()
    session.enteredURL = " recipes.example/soup "
    XCTAssertEqual(session.normalizedURL?.absoluteString, "https://recipes.example/soup")

    for invalid in [
      "",
      "http://recipes.example/soup",
      "https://person:secret@recipes.example/soup",
      "https:///soup",
      String(repeating: "a", count: RecipeImportSession.maximumURLBytes + 1),
    ] {
      session.enteredURL = invalid
      XCTAssertNil(session.normalizedURL, invalid)
    }
  }

  func testBeginReceiveAndChooseTransitionsClearStaleState() throws {
    var session = RecipeImportSession()
    session.enteredURL = "https://example.com"

    XCTAssertEqual(session.beginImport()?.host, "example.com")
    XCTAssertTrue(session.isLoading)
    XCTAssertNil(session.beginImport())
    XCTAssertNil(session.receive([]))
    XCTAssertEqual(session.failure, .noRecipeCandidates)

    XCTAssertNotNil(session.beginImport())
    let first = option(index: 1)
    let second = option(index: 2)
    XCTAssertEqual(session.receive([first, second]), .choose)
    XCTAssertEqual(session.candidates, [first, second])
    session.useDifferentURL()
    XCTAssertTrue(session.candidates.isEmpty)
    XCTAssertNil(session.failure)

    XCTAssertNotNil(session.beginImport())
    XCTAssertEqual(session.receive([first]), .review(first))
    XCTAssertTrue(session.candidates.isEmpty)
    XCTAssertFalse(session.isLoading)
  }

  func testCancellationAndEveryTypedFailureMapToStableSessionState() {
    let mappings: [(Error, RecipeImportSessionFailure?)] = [
      (RecipeImportServiceError.noRecipeCandidates, .noRecipeCandidates),
      (RecipeImportServiceError.disallowedAddress, .disallowedAddress),
      (RecipeImportServiceError.pageTooLarge, .pageTooLarge),
      (RecipeImportServiceError.unsupportedPage, .unsupportedPage),
      (RecipeImportServiceError.networkFailure, .networkFailure),
      (URLError(.badServerResponse), .unknown),
      (CancellationError(), nil),
    ]

    for (error, expected) in mappings {
      var session = RecipeImportSession()
      session.enteredURL = "example.com"
      XCTAssertNotNil(session.beginImport())
      session.receive(error: error)
      XCTAssertEqual(session.failure, expected)
      XCTAssertFalse(session.isLoading)
      XCTAssertTrue(session.candidates.isEmpty)
    }

    var session = RecipeImportSession()
    session.enteredURL = "example.com"
    XCTAssertNotNil(session.beginImport())
    session.cancel()
    XCTAssertFalse(session.isLoading)
  }

  private func option(index: Int) -> RecipeImportOption {
    RecipeImportOption(
      id: .init(blockIndex: index, objectIndex: 0),
      draft: RecipeDraft(title: "Soup \(index)"),
      concerns: []
    )
  }
}
