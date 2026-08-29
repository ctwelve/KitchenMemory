// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenKit
import Foundation
import XCTest

final class RecipeContentLanguageTests: XCTestCase {
  func testCanonicalizesCommonBCP47Spellings() throws {
    XCTAssertEqual(RecipeContentLanguage(rawValue: " EN_us ")?.rawValue, "en-US")
    XCTAssertEqual(RecipeContentLanguage(rawValue: "fr-ca")?.rawValue, "fr-CA")
    XCTAssertEqual(RecipeContentLanguage(rawValue: "es_MX")?.rawValue, "es-MX")
    XCTAssertNil(RecipeContentLanguage(rawValue: " \n "))
    XCTAssertNil(RecipeContentLanguage(rawValue: "@@@"))
  }

  func testCodableUsesASingleCanonicalStringAndRejectsInvalidTags() throws {
    let language = try XCTUnwrap(RecipeContentLanguage(rawValue: "fr_ca"))
    let encoded = try JSONEncoder().encode(language)

    XCTAssertEqual(String(data: encoded, encoding: .utf8), #""fr-CA""#)
    XCTAssertEqual(try JSONDecoder().decode(RecipeContentLanguage.self, from: encoded), language)
    XCTAssertThrowsError(
      try JSONDecoder().decode(RecipeContentLanguage.self, from: Data(#""@@@""#.utf8))
    )
  }
}
