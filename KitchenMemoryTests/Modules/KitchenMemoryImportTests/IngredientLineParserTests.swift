// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
@testable import KitchenMemoryImport
import XCTest

final class IngredientLineParserTests: XCTestCase {
  func testEmptyAndIncompleteLinesRemainLosslessOriginalText() {
    let empty = IngredientLineParser.parse(" \t\n ")
    XCTAssertEqual(empty.originalText, "")
    XCTAssertEqual(empty.presentationMode, .original)
    XCTAssertEqual(empty.parseState, .unparsed)
    XCTAssertNil(empty.quantity)

    let quantityOnly = IngredientLineParser.parse("2")
    XCTAssertEqual(quantityOnly.originalText, "2")
    XCTAssertEqual(quantityOnly.parseState, .parsed)
    XCTAssertEqual(quantityOnly.quantity?.lowerBound, .init(numerator: 2))
    XCTAssertNil(quantityOnly.ingredientText)

    let unitWithoutIngredient = IngredientLineParser.parse("1 cup")
    XCTAssertEqual(unitWithoutIngredient.originalText, "1 cup")
    XCTAssertEqual(unitWithoutIngredient.parseState, .unparsed)
    XCTAssertNil(unitWithoutIngredient.quantity)
  }

  func testExactRangesUnitsAndPreparationMapConservatively() {
    assertIngredient(
      "1 1/2 cups all-purpose flour, sifted",
      lower: .init(numerator: 3, denominator: 2),
      unit: "cups",
      name: "all-purpose flour",
      preparation: "sifted"
    )
    assertIngredient(
      "1½-2 tbsp. olive oil",
      kind: .range,
      lower: .init(numerator: 3, denominator: 2),
      upper: .init(numerator: 2),
      unit: "tbsp.",
      name: "olive oil"
    )
    assertIngredient(
      "3 eggs, divided",
      lower: .init(numerator: 3),
      name: "eggs",
      preparation: "divided"
    )

    let unparsed = IngredientLineParser.parse("salt and pepper, to taste")
    XCTAssertEqual(unparsed.originalText, "salt and pepper, to taste")
    XCTAssertEqual(unparsed.parseState, .unparsed)
  }

  func testEverySupportedUnicodeFractionParses() {
    let cases: [(Character, RationalQuantity)] = [
      ("½", .init(numerator: 1, denominator: 2)),
      ("⅓", .init(numerator: 1, denominator: 3)),
      ("⅔", .init(numerator: 2, denominator: 3)),
      ("¼", .init(numerator: 1, denominator: 4)),
      ("¾", .init(numerator: 3, denominator: 4)),
      ("⅛", .init(numerator: 1, denominator: 8)),
      ("⅜", .init(numerator: 3, denominator: 8)),
      ("⅝", .init(numerator: 5, denominator: 8)),
      ("⅞", .init(numerator: 7, denominator: 8)),
    ]

    for (glyph, expected) in cases {
      let ingredient = IngredientLineParser.parse("\(glyph) cup oats")
      XCTAssertEqual(ingredient.quantity?.lowerBound, expected, String(glyph))
      XCTAssertEqual(ingredient.ingredientText, "oats", String(glyph))
    }
  }

  func testOutOfRangeAndMalformedQuantitiesStayUnstructured() {
    let rejected = [
      "-1 cups flour",
      "1/0 cups flour",
      "1000001 cups flour",
      "1000000 1/2 cups flour",
      "1000001½ cups flour",
      "1/1000001 cup flour",
      "1-two cups flour",
    ]

    for source in rejected {
      let ingredient = IngredientLineParser.parse(source)
      XCTAssertEqual(ingredient.originalText, source)
      XCTAssertEqual(ingredient.parseState, .unparsed, source)
      XCTAssertNil(ingredient.quantity, source)
    }
  }

  func testSeededMixedFractionsPreserveTheirArithmetic() throws {
    let seed = try PropertyTestSeeds.bundled().seed(named: .importIngredientMixedFractions)
    var generator = SeededGenerator(seed: seed.value)
    for caseIndex in 0..<256 {
      let whole = generator.int(in: 0...500)
      let denominator = generator.int(in: 1...64)
      let numerator = generator.int(in: 0...denominator)
      let whitespace = generator.int(in: 0...1) == 0 ? " " : "\t"
      let source = "\(whole)\(whitespace)\(numerator)/\(denominator) cups item\(caseIndex)"

      let ingredient = IngredientLineParser.parse(source)
      let context = "seed=\(seed.hexadecimal) case=\(caseIndex) source=\(source)"
      XCTAssertEqual(
        ingredient.quantity?.lowerBound,
        .init(numerator: whole * denominator + numerator, denominator: denominator),
        context
      )
      XCTAssertEqual(ingredient.unitText, "cups", context)
      XCTAssertEqual(ingredient.ingredientText, "item\(caseIndex)", context)
      XCTAssertEqual(ingredient.parseState, .parsed, context)
    }
  }

  private func assertIngredient(
    _ source: String,
    kind: QuantityExpression.Kind = .exact,
    lower: RationalQuantity,
    upper: RationalQuantity? = nil,
    unit: String? = nil,
    name: String,
    preparation: String? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let ingredient = IngredientLineParser.parse(source)
    XCTAssertEqual(ingredient.originalText, source, file: file, line: line)
    XCTAssertEqual(ingredient.quantity?.kind, kind, file: file, line: line)
    XCTAssertEqual(ingredient.quantity?.lowerBound, lower, file: file, line: line)
    XCTAssertEqual(ingredient.quantity?.upperBound, upper, file: file, line: line)
    XCTAssertEqual(ingredient.unitText, unit, file: file, line: line)
    XCTAssertEqual(ingredient.ingredientText, name, file: file, line: line)
    XCTAssertEqual(ingredient.preparation, preparation, file: file, line: line)
    XCTAssertEqual(ingredient.parseState, .parsed, file: file, line: line)
  }
}
