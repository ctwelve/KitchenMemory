// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import KitchenMemoryImport
import XCTest

final class SchemaOrgRecipeImporterEdgeCaseTests: XCTestCase {
  func testHTMLDiscoveryReportsTheExactBlockLimit() {
    let importer = SchemaOrgRecipeImporter(limits: .init(maximumJSONLDBlocks: 1))
    let html = """
      <script type="application/ld+json">{"@type":"Recipe","name":"One"}</script>
      <script type="application/ld+json">{"@type":"Recipe","name":"Two"}</script>
      """

    assertLimit(importer.importHTML(html), .jsonLDBlocks)
  }

  func testTopLevelObjectLimitAndUnsupportedScalarsAreDiagnosed() throws {
    let limited = SchemaOrgRecipeImporter(limits: .init(maximumTopLevelObjects: 1))
    let objects = try JSONSerialization.data(withJSONObject: [
      ["@type": "Thing"],
      ["@type": "Recipe", "name": "Too late"],
    ])

    assertLimit(limited.importJSONLD(objects), .topLevelObjects)

    let emptyArray = SchemaOrgRecipeImporter().importJSONLD(Data("[]".utf8))
    XCTAssertTrue(emptyArray.candidates.isEmpty)
    XCTAssertEqual(
      emptyArray.diagnostics,
      [.init(blockIndex: 0, kind: .unsupportedTopLevel)]
    )
  }

  func testStructuredSourceYieldAndNumericTaxonomyValuesNormalize() throws {
    let data = try JSONSerialization.data(withJSONObject: [
      "@type": "Recipe",
      "name": "Structured",
      "mainEntityOfPage": ["@id": "/canonical"],
      "publisher": " <b>Example</b> ",
      "recipeYield": ["", " 6 servings "],
      "recipeCuisine": [1, [2, " <i>three</i> "]],
    ])
    let documentURL = try XCTUnwrap(URL(string: "https://publisher.example/path/page"))

    let draft = try XCTUnwrap(
      SchemaOrgRecipeImporter().importJSONLD(data, documentURL: documentURL)
        .unambiguousCandidate
    ).draft

    XCTAssertEqual(draft.source.canonicalURL?.absoluteString, "https://publisher.example/canonical")
    XCTAssertEqual(draft.source.publisherName, "Example")
    XCTAssertEqual(draft.recipeYield?.originalText, "6 servings")
    XCTAssertEqual(draft.cuisines, ["1", "2", "three"])
  }

  func testMainEntityObjectFallsBackFromIDToURL() throws {
    let data = try JSONSerialization.data(withJSONObject: [
      "@type": "Recipe",
      "name": "Fallback URL",
      "mainEntityOfPage": ["url": "/from-url"],
    ])
    let documentURL = try XCTUnwrap(URL(string: "https://publisher.example/path/page"))

    let candidate = try XCTUnwrap(
      SchemaOrgRecipeImporter().importJSONLD(data, documentURL: documentURL)
        .unambiguousCandidate
    )

    XCTAssertEqual(
      candidate.draft.source.canonicalURL?.absoluteString,
      "https://publisher.example/from-url"
    )
  }

  func testStructuredYieldObjectsUseValueThenNameAndNormalizeUnits() throws {
    let data = try JSONSerialization.data(withJSONObject: [
      [
        "@type": "Recipe",
        "name": "Value",
        "recipeYield": ["value": " 4 ", "name": "ignored", "unitText": "<b>servings</b>"],
      ],
      [
        "@type": "Recipe",
        "name": "Name",
        "recipeYield": ["name": " one loaf "],
      ],
      [
        "@type": "Recipe",
        "name": "Missing",
        "recipeYield": ["unitText": "servings"],
      ],
    ])

    let drafts = SchemaOrgRecipeImporter().importJSONLD(data).candidates.map(\.draft)

    XCTAssertEqual(drafts[0].recipeYield?.originalText, "4")
    XCTAssertEqual(drafts[0].recipeYield?.unitText, "servings")
    XCTAssertEqual(drafts[1].recipeYield?.originalText, "one loaf")
    XCTAssertNil(drafts[2].recipeYield)
  }

  func testIngredientTextObjectsAndScalarsArePromotedAsPlainText() throws {
    let data = try JSONSerialization.data(withJSONObject: [
      "@type": "Recipe",
      "name": "Ingredients",
      "recipeIngredient": [
        "1 cup <b>flour</b>",
        ["value": "2 <i>ripe</i> tomatoes", "unitText": ""],
        ["name": "<strong>salt</strong>"],
        ["future": "ignored"],
      ],
    ])

    let ingredients = try XCTUnwrap(
      SchemaOrgRecipeImporter().importJSONLD(data).unambiguousCandidate
    ).draft.ingredientSections[0].ingredients

    XCTAssertEqual(ingredients.map(\.originalText), [
      "1 cup flour",
      "2 ripe tomatoes",
      "salt",
    ])
  }

  func testNestedInstructionSectionsFlattenWithoutLosingNamedSteps() throws {
    let data = try JSONSerialization.data(withJSONObject: [
      "@type": "Recipe",
      "name": "Nested",
      "recipeInstructions": [
        [
          "@type": "HowToSection",
          "name": "Outer",
          "itemListElement": [
            [
              "@type": "HowToSection",
              "itemListElement": ["Nested text"],
            ],
            ["@type": "HowToSection", "name": "Empty nested"],
            ["@type": "HowToStep", "name": "Named step"],
            ["@type": "HowToStep"],
          ],
        ],
        ["@type": "HowToSection", "name": "Empty"],
      ],
    ])

    let sections = try XCTUnwrap(
      SchemaOrgRecipeImporter().importJSONLD(data).unambiguousCandidate
    ).draft.instructionSections

    XCTAssertEqual(sections.count, 1)
    XCTAssertEqual(sections[0].title, "Outer")
    XCTAssertEqual(sections[0].steps.map(\.text), ["Nested text", "Named step"])
    XCTAssertEqual(sections[0].steps[1].name, "Named step")
  }

  func testImageObjectsPreferURLAndFallBackToContentURL() throws {
    let data = try JSONSerialization.data(withJSONObject: [
      "@type": "Recipe",
      "name": "Images",
      "image": [
        ["url": "/preferred.jpg", "contentUrl": "/ignored.jpg"],
        ["contentUrl": "/fallback.jpg"],
      ],
    ])
    let baseURL = try XCTUnwrap(URL(string: "https://publisher.example/recipe"))

    let urls = try XCTUnwrap(
      SchemaOrgRecipeImporter().importJSONLD(data, documentURL: baseURL)
        .unambiguousCandidate
    ).draft.imageURLs

    XCTAssertEqual(urls.map(\.absoluteString), [
      "https://publisher.example/preferred.jpg",
      "https://publisher.example/fallback.jpg",
    ])
  }

  func testScannerRejectsMalformedOrNonJSONLDScriptShapes() {
    let cases = [
      #"<scripture type="application/ld+json">{"@type":"Recipe","name":"No"}</scripture>"#,
      #"<script type> {"@type":"Recipe","name":"No"} </script>"#,
      #"<script defer> {"@type":"Recipe","name":"No"} </script>"#,
      #"<script ///></script>"#,
      #"<script data-label=recipe> {"@type":"Recipe","name":"No"} </script>"#,
      #"<script type="application/ld+json data-x='broken'> {"@type":"Recipe"} </script>"#,
      #"<!-- never closes <script type="application/ld+json">{"@type":"Recipe"}</script>"#,
    ]

    for html in cases {
      XCTAssertTrue(SchemaOrgRecipeImporter().importHTML(html).candidates.isEmpty, html)
    }
  }

  func testScannerSkipsFalseClosingScriptPrefixes() throws {
    let html = #"""
      <script type="application/ld+json">
      {"@type":"Recipe","name":"Right </scripture> still"}</SCRIPT />
      """#

    let candidate = try XCTUnwrap(SchemaOrgRecipeImporter().importHTML(html).unambiguousCandidate)
    XCTAssertEqual(candidate.draft.title, "Right still")
  }

  private func assertLimit(
    _ result: RecipeImportResult,
    _ limit: RecipeImportDiagnostic.ProcessingLimit,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertTrue(result.candidates.isEmpty, file: file, line: line)
    XCTAssertEqual(
      result.diagnostics.last?.kind,
      .processingLimitExceeded(limit),
      file: file,
      line: line
    )
  }
}
