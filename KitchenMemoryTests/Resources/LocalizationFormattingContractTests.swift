// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class LocalizationFormattingContractTests: XCTestCase {
  func testComparisonLocalizesCapturedDateAndPreservesAuthoredUnitsAndEvidence() throws {
    let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
    let url = try XCTUnwrap(URL(string: "https://example.com/synthetic-recipe"))
    var revision = RecipeRevision(recipeID: Recipe.ID(), revisionNumber: 1, title: "Synthetic recipe")
    revision.sourceCapture = RecipeSourceCapture(kind: .schemaOrgJSONLD, sourceURL: url,
      capturedAt: capturedAt, mediaType: "application/ld+json", payload: Data("{}".utf8),
      blockIndex: 0, objectIndex: 0)
    let ingredient = RecipeIngredient(quantity: QuantityExpression(kind: .exact,
      lowerBound: RationalQuantity(numerator: 3, denominator: 2)), unitText: "tasses", ingredientText: "farine")
    let retained = revision
    var dates: Set<String> = []
    for language in ["en-US", "es-MX", "fr-CA"] {
      let locale = Locale(identifier: language)
      let comparison = RecipeComparisonFormatter(locale: locale)
      let source = comparison.value(.source, revision: revision)
      let date = capturedAt.formatted(.dateTime.locale(locale))
      XCTAssertTrue(source.contains(date))
      XCTAssertTrue(source.contains(url.absoluteString))
      dates.insert(date)
      XCTAssertTrue(comparison.ingredient(ingredient).contains("tasses"))
      XCTAssertTrue(comparison.ingredient(ingredient).contains("farine"))
      XCTAssertEqual(revision, retained)
      for count in [0, 1, 2, 1_000] {
        let message = RecipeImportConcern.unparsedIngredients(count: count).reviewMessage(locale: locale)
        XCTAssertFalse(message.isEmpty)
        XCTAssertFalse(message.contains("%"))
      }
      for seconds in [0, 60, 3_600, 7_500] {
        XCTAssertFalse(RecipePresentationFormatter(locale: locale).duration(RecipeDuration(seconds: seconds)).isEmpty)
      }
    }
    XCTAssertGreaterThan(dates.count, 1)
  }
}
