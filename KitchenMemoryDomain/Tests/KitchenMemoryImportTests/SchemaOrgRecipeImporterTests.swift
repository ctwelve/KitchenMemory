// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryImport
import XCTest

final class SchemaOrgRecipeImporterTests: XCTestCase {
    private let importer = SchemaOrgRecipeImporter()

    func testFlatRecipeMapsMetadataAndPreservesIngredientText() throws {
        let result = importer.importHTML(
            try fixture("minimal-flat"),
            documentURL: URL(string: "https://example.com/menu/index.html")
        )

        let candidate = try XCTUnwrap(result.unambiguousCandidate)
        XCTAssertEqual(candidate.draft.title, "Tomato Toast")
        XCTAssertEqual(candidate.draft.summary, "A quick lunch.")
        XCTAssertEqual(candidate.draft.authorName, "Ada Cook")
        XCTAssertEqual(candidate.draft.source.canonicalURL?.absoluteString, "https://example.com/recipes/tomato-toast")
        XCTAssertEqual(candidate.draft.imageURLs.first?.absoluteString, "https://example.com/images/toast.jpg")
        XCTAssertEqual(candidate.draft.prepDuration?.seconds, 600)
        XCTAssertEqual(candidate.draft.cookDuration?.seconds, 300)
        XCTAssertEqual(candidate.draft.totalDuration?.seconds, 900)
        XCTAssertEqual(candidate.draft.recipeYield?.originalText, "2 servings")
        XCTAssertEqual(candidate.draft.cuisines, ["Italian", "American"])
        XCTAssertEqual(candidate.draft.categories, ["Lunch"])
        XCTAssertEqual(candidate.draft.keywords, ["toast", "quick"])
        XCTAssertEqual(
            candidate.draft.ingredientSections[0].ingredients.map(\.originalText),
            ["2 slices bread", "1 ripe tomato", "salt, to taste"]
        )
        XCTAssertTrue(candidate.draft.ingredientSections[0].ingredients.allSatisfy {
            $0.presentationMode == .original
        })
        XCTAssertEqual(
            candidate.draft.instructionSections[0].steps.map(\.text),
            ["Toast the bread.", "Top with tomato."]
        )
    }

    func testGraphAndStructuredValuesNormalizeWithoutLosingUnknownFields() throws {
        let result = importer.importHTML(try fixture("graph-sections"))
        let candidate = try XCTUnwrap(result.unambiguousCandidate)

        XCTAssertEqual(candidate.draft.source.publisherName, "Example Kitchen")
        XCTAssertEqual(
            candidate.draft.ingredientSections[0].ingredients.map(\.originalText),
            ["2 cups flour", "1½ cups sugar"]
        )
        XCTAssertEqual(candidate.draft.instructionSections.map(\.title), ["Cake", "Finish"])
        XCTAssertEqual(candidate.draft.instructionSections[0].steps.map(\.text), ["Mix the batter.", "Bake until done."])
        XCTAssertEqual(candidate.draft.instructionSections[1].steps.map(\.text), ["Cool completely."])

        let sourceObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: candidate.snapshot.candidateJSONLD) as? [String: Any]
        )
        XCTAssertNotNil(sourceObject["nutrition"])
        XCTAssertNotNil(sourceObject["futurePublisherField"])
    }

    func testMultipleBlocksCollectCandidatesAndReportMalformedBlock() throws {
        let result = importer.importHTML(try fixture("multiple-and-malformed"))

        XCTAssertNil(result.unambiguousCandidate)
        XCTAssertEqual(result.candidates.map(\.draft.title), ["First", "Second"])
        XCTAssertEqual(result.diagnostics, [.init(blockIndex: 1, kind: .malformedJSONLD)])
    }

    func testJSONLDDiscoveryHandlesAttributeSyntaxAndIgnoresHTMLComments() throws {
        let html = #"""
        <!-- <script type="application/ld+json">{"@type":"Recipe","name":"Comment"}</script> -->
        <script data-label=recipe TYPE = 'APPLICATION/LD+JSON' data-angle=">">
          {"@type":"Recipe","name":"Visible"}
        </SCRIPT   >
        """#

        let candidate = try XCTUnwrap(importer.importHTML(html).unambiguousCandidate)

        XCTAssertEqual(candidate.draft.title, "Visible")
    }

    func testJSONLDDiscoveryIgnoresMarkupInsideOrdinaryScripts() throws {
        let html = #"""
        <script type="text/javascript">
          const example = '<script type="application/ld+json">{"@type":"Recipe","name":"Wrong"}';
        </script>
        <script type="application/ld+json">{"@type":"Recipe","name":"Right"}</script>
        """#

        let candidate = try XCTUnwrap(importer.importHTML(html).unambiguousCandidate)

        XCTAssertEqual(candidate.draft.title, "Right")
    }

    func testJSONLDDiscoveryUsesTheFirstDuplicateTypeAttribute() {
        let html = #"""
        <script type="text/plain" type="application/ld+json">
          {"@type":"Recipe","name":"Not JSON-LD"}
        </script>
        """#

        XCTAssertTrue(importer.importHTML(html).candidates.isEmpty)
    }

    func testUnclosedJSONLDOpenersAreScannedInBoundedTime() {
        let html = String(
            repeating: #"<script type="application/ld+json">"#,
            count: 5_000
        )
        let clock = ContinuousClock()
        let start = clock.now

        let result = importer.importHTML(html)

        let elapsed = start.duration(to: clock.now)
        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertLessThan(
            elapsed,
            .seconds(2),
            "Discovery must remain linear when opening tags have no closing tag."
        )
    }

    func testMissingTitleIsReviewDiagnosticAndMarkupIsRemoved() throws {
        let result = importer.importHTML(try fixture("missing-title-and-malicious"))

        XCTAssertEqual(result.candidates.map(\.draft.title), ["", "Safe Soup"])
        XCTAssertEqual(result.diagnostics, [.init(blockIndex: 0, kind: .missingTitle)])
        XCTAssertEqual(result.candidates[1].draft.summary, "Comfort & warmth")
        XCTAssertEqual(result.candidates[1].draft.instructionSections[0].steps[0].text, "Simmer.")
    }

    func testDirectJSONLDInputSupportsTopLevelArrayAndNumericYield() throws {
        let data = Data(#"[{"@type":"Recipe","name":"One","recipeYield":4}]"#.utf8)
        let result = importer.importJSONLD(data)

        XCTAssertEqual(result.unambiguousCandidate?.draft.recipeYield?.originalText, "4")
        XCTAssertEqual(result.unambiguousCandidate?.snapshot.jsonLD, data)
    }

    func testIngredientParsingIsProvisionalAndAlwaysKeepsOriginalText() throws {
        let data = Data(#"""
        {
          "@type":"Recipe",
          "name":"Quantities",
          "recipeIngredient":[
            "2 cups all-purpose flour",
            "1½–2 tablespoons olive oil",
            "3 eggs, divided",
            "salt and freshly ground black pepper, to taste",
            "a generous handful of basil"
          ]
        }
        """#.utf8)

        let ingredients = try XCTUnwrap(
            importer.importJSONLD(data).unambiguousCandidate
        ).draft.ingredientSections[0].ingredients

        XCTAssertEqual(ingredients.map(\.originalText), [
            "2 cups all-purpose flour",
            "1½–2 tablespoons olive oil",
            "3 eggs, divided",
            "salt and freshly ground black pepper, to taste",
            "a generous handful of basil",
        ])
        XCTAssertEqual(ingredients[0].quantity?.lowerBound?.numerator, 2)
        XCTAssertEqual(ingredients[0].unitText, "cups")
        XCTAssertEqual(ingredients[0].ingredientText, "all-purpose flour")
        XCTAssertEqual(ingredients[1].quantity?.kind, .range)
        XCTAssertEqual(ingredients[1].quantity?.lowerBound?.numerator, 3)
        XCTAssertEqual(ingredients[1].quantity?.lowerBound?.denominator, 2)
        XCTAssertEqual(ingredients[1].quantity?.upperBound?.numerator, 2)
        XCTAssertEqual(ingredients[2].ingredientText, "eggs")
        XCTAssertEqual(ingredients[2].preparation, "divided")
        XCTAssertEqual(ingredients[3].parseState, .unparsed)
        XCTAssertEqual(ingredients[4].parseState, .unparsed)
    }

    func testExtremeNumericValuesRemainSourceTextInsteadOfOverflowing() throws {
        let data = Data(#"""
        {
          "@type":"Recipe",
          "name":"Hostile arithmetic",
          "prepTime":"P9223372036854775807D",
          "recipeIngredient":["9223372036854775807 1/2 cups flour", "9223372036854775807½ onions"]
        }
        """#.utf8)

        let draft = try XCTUnwrap(importer.importJSONLD(data).unambiguousCandidate).draft
        XCTAssertNil(draft.prepDuration)
        XCTAssertEqual(
            draft.ingredientSections[0].ingredients.map(\.originalText),
            ["9223372036854775807 1/2 cups flour", "9223372036854775807½ onions"]
        )
        XCTAssertTrue(draft.ingredientSections[0].ingredients.allSatisfy { $0.quantity == nil })
    }

    func testRejectsJSONThatExceedsTheStructuralBudget() {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumJSONDepth: 3))
        let result = limitedImporter.importJSONLD(Data(#"[[[[{"@type":"Recipe","name":"Deep"}]]]]"#.utf8))

        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertEqual(
            result.diagnostics.last?.kind,
            .processingLimitExceeded(.jsonStructure)
        )
    }

    func testRejectsConsumedCollectionsBeforeBuildingAnOversizedDraft() {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumIngredients: 2))
        let data = Data(#"""
        {
          "@type":"Recipe","name":"Crowded",
          "recipeIngredient":["one","two","three"]
        }
        """#.utf8)
        let result = limitedImporter.importJSONLD(data)

        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertEqual(
            result.diagnostics.last?.kind,
            .processingLimitExceeded(.consumedFields)
        )
    }

    func testUntrustedLinkSchemesDoNotBecomeActiveRecipeLinks() throws {
        let data = Data(#"""
        {
          "@type":"Recipe","name":"Suspicious links",
          "url":"file:///etc/passwd",
          "image":["javascript:alert(1)","http://127.0.0.1/private.jpg"]
        }
        """#.utf8)
        let documentURL = URL(string: "https://publisher.example/recipe")!

        let draft = try XCTUnwrap(
            importer.importJSONLD(data, documentURL: documentURL).unambiguousCandidate
        ).draft
        XCTAssertEqual(draft.source.canonicalURL, documentURL)
        XCTAssertTrue(draft.imageURLs.isEmpty)
    }

    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "html"))
        return try String(contentsOf: url, encoding: .utf8)
    }
}
