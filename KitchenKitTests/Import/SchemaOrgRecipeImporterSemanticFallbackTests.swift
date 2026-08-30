// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

final class SchemaOrgSemanticFallbackTests: XCTestCase {
  func testMarkupOnlyAndExhaustedYieldValuesAreOmitted() throws {
    let values: [Any] = [
      "",
      "<script>DROP_YIELD</script>",
      ["", "<style>DROP_YIELD</style>"],
      [
        "value": "<script>DROP_YIELD</script>",
        "name": "<style>DROP_YIELD</style>",
        "unitText": "servings",
      ],
    ]

    for (index, value) in values.enumerated() {
      let candidate = try candidate(fields: ["recipeYield": value])

      XCTAssertNil(candidate.draft.recipeYield, "case=\(index)")
      if index > 0 {
        let capturedJSON = try XCTUnwrap(
          String(data: candidate.snapshot.jsonLD, encoding: .utf8)
        )
        XCTAssertTrue(capturedJSON.contains("DROP_YIELD"))
      }
    }
  }

  func testStructuredYieldUsesAValidNameAfterItsValueIsSuppressed() throws {
    let candidate = try candidate(fields: [
      "recipeYield": [
        "value": "<script>DROP_VALUE</script>",
        "name": "<b>one loaf</b>",
        "unitText": "<style>DROP_UNIT</style>",
      ],
    ])

    XCTAssertEqual(candidate.draft.recipeYield?.originalText, "one loaf")
    XCTAssertNil(candidate.draft.recipeYield?.unitText)
  }

  func testSuppressedIngredientValueCannotPromoteItsUnitAlone() throws {
    let candidate = try candidate(fields: [
      "recipeIngredient": [
        "",
        "<script>DROP_SCALAR</script>",
        ["value": "<script>DROP_VALUE</script>", "unitText": "cups"],
        [
          "value": "<style>DROP_VALUE</style>",
          "name": "<b>flour</b>",
          "unitText": "cups",
        ],
        ["name": "<script>DROP_NAME</script>"],
      ],
    ])

    let ingredients = try XCTUnwrap(candidate.draft.ingredientSections.first).ingredients
    XCTAssertEqual(ingredients.map(\.originalText), ["flour"])
    let capturedJSON = try XCTUnwrap(
      String(data: candidate.snapshot.jsonLD, encoding: .utf8)
    )
    XCTAssertTrue(capturedJSON.contains("DROP_VALUE"))
  }

  func testCanonicalURLUsesTheFirstSemanticallyAllowedFallback() throws {
    let documentURL = try XCTUnwrap(URL(string: "https://publisher.example/fetched"))
    let data = try JSONSerialization.data(withJSONObject: [
      [
        "@type": "Recipe",
        "name": "Empty ID",
        "mainEntityOfPage": ["@id": " \n ", "url": "/empty-id"],
      ],
      [
        "@type": "Recipe",
        "name": "Disallowed ID",
        "mainEntityOfPage": ["@id": "javascript:alert(1)", "url": "/disallowed-id"],
      ],
      [
        "@type": "Recipe",
        "name": "Disallowed Recipe URL",
        "url": "file:///tmp/not-a-recipe",
        "mainEntityOfPage": ["url": "/main-entity"],
      ],
      [
        "@type": "Recipe",
        "name": "Direct Main Entity",
        "mainEntityOfPage": "/direct",
      ],
    ])

    let urls = SchemaOrgRecipeImporter()
      .importJSONLD(data, documentURL: documentURL)
      .candidates
      .map(\.draft.source.canonicalURL?.absoluteString)

    XCTAssertEqual(urls, [
      "https://publisher.example/empty-id",
      "https://publisher.example/disallowed-id",
      "https://publisher.example/main-entity",
      "https://publisher.example/direct",
    ])
  }

  private func candidate(
    fields: [String: Any],
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> RecipeImportCandidate {
    var object: [String: Any] = ["@type": "Recipe", "name": "Fallbacks"]
    object.merge(fields) { _, replacement in replacement }
    let data = try JSONSerialization.data(withJSONObject: object)
    return try XCTUnwrap(
      SchemaOrgRecipeImporter().importJSONLD(data).unambiguousCandidate,
      file: file,
      line: line
    )
  }
}
