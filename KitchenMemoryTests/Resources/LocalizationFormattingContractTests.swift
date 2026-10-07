// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class LocalizationFormattingContractTests: XCTestCase {
  func testComparisonSecondsUsesCompletePluralMessagesForExplicitLocales() {
    let examples: [(String, [String])] = [
      ("en-US", ["0 seconds", "1 second", "2 seconds"]),
      ("en-GB", ["0 seconds", "1 second", "2 seconds"]),
      ("es-MX", ["0 segundos", "1 segundo", "2 segundos"]),
      ("fr-CA", ["0 seconde", "1 seconde", "2 secondes"]),
      ("de-DE", ["0 Sekunden", "1 Sekunde", "2 Sekunden"]),
      ("it-IT", ["0 secondi", "1 secondo", "2 secondi"]),
    ]
    var revision = RecipeRevision(recipeID: Recipe.ID(), revisionNumber: 1, title: "Authored title")
    for (language, expected) in examples {
      let formatter = RecipeComparisonFormatter(locale: Locale(identifier: language))
      for count in 0...2 {
        revision.prepDuration = RecipeDuration(seconds: count)
        XCTAssertEqual(formatter.value(.preparation, revision: revision), expected[count], language)
        XCTAssertEqual(revision.prepDuration?.seconds, count)
        XCTAssertEqual(revision.title, "Authored title")
      }
    }
  }

  func testSampleRemovalConfirmationIncludesCompleteCountSentenceInRequestedLocale() {
    let english = Locale(identifier: "en-US")
    for count in 0...2 {
      let expected = count == 1
        ? "1 untouched sample will be removed."
        : "\(count) untouched samples will be removed."
      XCTAssertTrue(SamplePackRemovalCopy.message(count: count, locale: english).hasSuffix("\n\n" + expected))
    }
    let french = Locale(identifier: "fr-CA")
    let message = SamplePackRemovalCopy.message(count: 2, locale: french)
    XCTAssertNotEqual(message, SamplePackRemovalCopy.message(count: 2, locale: english))
    XCTAssertFalse(message.contains("untouched"))
    XCTAssertFalse(message.contains("%"))
    XCTAssertEqual(message.components(separatedBy: "\n\n").count, 2)
  }

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
    for language in ["en-US", "en-GB", "es-MX", "fr-CA", "de-DE", "it-IT"] {
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
