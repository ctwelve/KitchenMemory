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

        let sourceDocument = try XCTUnwrap(
            JSONSerialization.jsonObject(with: candidate.snapshot.jsonLD) as? [String: Any]
        )
        let sourceObjects = try XCTUnwrap(sourceDocument["@graph"] as? [[String: Any]])
        let sourceObject = try XCTUnwrap(
            sourceObjects.first { $0["futurePublisherField"] != nil }
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

    func testNestedCandidatesShareOneContainingSourceBlock() throws {
        var root: [String: Any] = ["@type": "Recipe", "name": "Recipe 0"]
        for index in 1...15 {
            root = [
                "@type": "Recipe",
                "name": "Recipe \(index)",
                "@graph": [root],
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: root)

        let result = importer.importJSONLD(data)

        XCTAssertEqual(result.candidates.count, 16)
        XCTAssertTrue(result.candidates.allSatisfy { $0.snapshot.jsonLD == data })
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

    func testTextNormalizationDecodesEntitiesAndSuppressesExecutableContent() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Text",
            "description": "One&nbsp;<b title='>'>two</b> &amp; <SCRIPT>bad()</SCRIPT>three",
        ])

        let draft = try XCTUnwrap(importer.importJSONLD(data).unambiguousCandidate).draft

        XCTAssertEqual(draft.summary, "One two & three")
    }

    func testTextNormalizationDoesNotDecodeMultipleEntityLayers() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Entities",
            "description": "Show &amp;lt;em&amp;gt; literally",
        ])

        let draft = try XCTUnwrap(importer.importJSONLD(data).unambiguousCandidate).draft

        XCTAssertEqual(draft.summary, "Show &lt;em&gt; literally")
    }

    func testMalformedMarkupNormalizationCompletesInBoundedTime() throws {
        let hostileText = String(repeating: "<", count: 20_000)
        let data = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Malformed markup",
            "description": hostileText,
        ])
        let clock = ContinuousClock()
        let start = clock.now

        let result = importer.importJSONLD(data)

        let elapsed = start.duration(to: clock.now)
        XCTAssertEqual(result.unambiguousCandidate?.draft.summary, "")
        XCTAssertLessThan(
            elapsed,
            .seconds(2),
            "Malformed tags must be consumed once rather than searched repeatedly."
        )
    }

    func testUnclosedScriptNormalizationCompletesInBoundedTime() throws {
        let hostileText = String(repeating: "<script>", count: 2_500)
        let data = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Malformed script",
            "description": hostileText,
        ])
        let clock = ContinuousClock()
        let start = clock.now

        let result = importer.importJSONLD(data)

        let elapsed = start.duration(to: clock.now)
        XCTAssertEqual(result.unambiguousCandidate?.draft.summary, "")
        XCTAssertLessThan(
            elapsed,
            .seconds(2),
            "Unclosed raw-text elements must consume their suffix only once."
        )
    }

    func testDirectJSONLDInputSupportsTopLevelArrayAndNumericYield() throws {
        let data = Data(#"[{"@type":"Recipe","name":"One","recipeYield":4}]"#.utf8)
        let result = importer.importJSONLD(data)

        XCTAssertEqual(result.unambiguousCandidate?.draft.recipeYield?.originalText, "4")
        XCTAssertEqual(result.unambiguousCandidate?.snapshot.jsonLD, data)
    }

    func testDirectJSONLDNormalizesSupportedUnicodeEncodingsToUTF8() throws {
        let json = #"{"@type":"Recipe","name":"Crème 🍲"}"#
        let variants: [(String.Encoding, [UInt8])] = [
            (.utf8, [0xEF, 0xBB, 0xBF]),
            (.utf16LittleEndian, [0xFF, 0xFE]),
            (.utf16BigEndian, [0xFE, 0xFF]),
            (.utf32LittleEndian, [0xFF, 0xFE, 0x00, 0x00]),
            (.utf32BigEndian, [0x00, 0x00, 0xFE, 0xFF]),
        ]

        for (encoding, byteOrderMark) in variants {
            let result = importer.importJSONLD(try encoded(
                json,
                as: encoding,
                byteOrderMark: byteOrderMark
            ))
            let candidate = try XCTUnwrap(result.unambiguousCandidate)

            XCTAssertEqual(candidate.draft.title, "Crème 🍲")
            XCTAssertEqual(candidate.snapshot.jsonLD, Data(json.utf8))
        }
    }

    func testDirectJSONLDRejectsMalformedAndTruncatedEncodings() {
        let malformedUTF8 = Data([0xEF, 0xBB, 0xBF, 0xC3, 0x28])
        let truncatedUTF16 = Data([0xFF, 0xFE, 0x7B])
        let truncatedUTF32 = Data([0x00, 0x00, 0xFE, 0xFF, 0x00, 0x00, 0x00])

        for data in [malformedUTF8, truncatedUTF16, truncatedUTF32] {
            let result = importer.importJSONLD(data)
            XCTAssertTrue(result.candidates.isEmpty)
            XCTAssertEqual(result.diagnostics, [
                .init(blockIndex: 0, kind: .malformedJSONLD),
            ])
        }
    }

    func testDirectJSONLDRejectsTrailingPartialUnicodeCodeUnits() throws {
        let json = #"{"@type":"Recipe","name":"Complete prefix"}"#
        let variants: [(String.Encoding, [UInt8], ClosedRange<Int>)] = [
            (.utf16LittleEndian, [0xFF, 0xFE], 1...1),
            (.utf16BigEndian, [0xFE, 0xFF], 1...1),
            (.utf32LittleEndian, [0xFF, 0xFE, 0x00, 0x00], 1...3),
            (.utf32BigEndian, [0x00, 0x00, 0xFE, 0xFF], 1...3),
        ]

        for (encoding, byteOrderMark, fragmentCounts) in variants {
            for fragmentCount in fragmentCounts {
                var data = try encoded(
                    json,
                    as: encoding,
                    byteOrderMark: byteOrderMark
                )
                data.append(contentsOf: repeatElement(UInt8(0), count: fragmentCount))

                let result = importer.importJSONLD(data)
                XCTAssertTrue(result.candidates.isEmpty)
                XCTAssertEqual(result.diagnostics.last?.kind, .malformedJSONLD)
            }
        }
    }

    func testDirectJSONLDDoesNotReplaceInvalidUnicodeScalars() throws {
        let prefix = #"{"@type":"Recipe","name":""#
        let suffix = #""}"#
        let variants: [(String.Encoding, [UInt8], [UInt8])] = [
            (.utf16LittleEndian, [0xFF, 0xFE], [0x00, 0xD8]),
            (.utf16BigEndian, [0xFE, 0xFF], [0xD8, 0x00]),
            (.utf32LittleEndian, [0xFF, 0xFE, 0x00, 0x00], [0x00, 0x00, 0x11, 0x00]),
            (.utf32BigEndian, [0x00, 0x00, 0xFE, 0xFF], [0x00, 0x11, 0x00, 0x00]),
        ]

        for (encoding, byteOrderMark, invalidScalar) in variants {
            var data = try encoded(prefix, as: encoding, byteOrderMark: byteOrderMark)
            data.append(contentsOf: invalidScalar)
            let suffixData = try encoded(suffix, as: encoding, byteOrderMark: byteOrderMark)
            data.append(suffixData.dropFirst(byteOrderMark.count))

            let result = importer.importJSONLD(data)
            XCTAssertTrue(result.candidates.isEmpty)
            XCTAssertEqual(result.diagnostics.last?.kind, .malformedJSONLD)
        }
    }

    func testBOMlessNonUTF8JSONIsNotGuessed() throws {
        let json = #"{"@type":"Recipe","name":"UTF-16"}"#
        let withBOM = try encoded(
            json,
            as: .utf16LittleEndian,
            byteOrderMark: [0xFF, 0xFE]
        )
        let data = Data(withBOM.dropFirst(2))

        let result = importer.importJSONLD(data)

        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertEqual(result.diagnostics.last?.kind, .malformedJSONLD)
    }

    func testDirectInputByteLimitAppliesBeforeAndAfterTranscoding() throws {
        let utf8JSON = Data(#"{"@type":"Recipe","name":"A"}"#.utf8)
        let exactImporter = SchemaOrgRecipeImporter(limits: .init(
            maximumInputBytes: utf8JSON.count
        ))
        let sourceLimitImporter = SchemaOrgRecipeImporter(limits: .init(
            maximumInputBytes: utf8JSON.count - 1
        ))

        XCTAssertNotNil(exactImporter.importJSONLD(utf8JSON).unambiguousCandidate)
        assertInputByteLimit(sourceLimitImporter.importJSONLD(utf8JSON))

        let expandingJSON = "[\"" + String(repeating: "€", count: 100) + "\"]"
        let utf16 = try encoded(
            expandingJSON,
            as: .utf16LittleEndian,
            byteOrderMark: [0xFF, 0xFE]
        )
        let normalizedCount = expandingJSON.utf8.count
        XCTAssertLessThan(utf16.count, normalizedCount)
        let normalizedLimitImporter = SchemaOrgRecipeImporter(limits: .init(
            maximumInputBytes: utf16.count
        ))

        assertInputByteLimit(normalizedLimitImporter.importJSONLD(utf16))
    }

    func testHTMLInputByteLimitAppliesBeforeScanning() {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumInputBytes: 32))

        assertInputByteLimit(limitedImporter.importHTML(String(repeating: " ", count: 33)))
    }

    func testUTF16QuoteBytesCannotBypassTheJSONDepthLimit() throws {
        let json = #"{"@type":"Recipe","name":"Collision","mask":"Ģ","deep":[[[[0]]]]}"#
        let data = try encoded(
            json,
            as: .utf16LittleEndian,
            byteOrderMark: [0xFF, 0xFE]
        )
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumJSONDepth: 3))

        let result = limitedImporter.importJSONLD(data)

        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertEqual(
            result.diagnostics.last?.kind,
            .processingLimitExceeded(.jsonStructure)
        )
    }

    func testMalformedCloserCannotSkipStructuralScanningOfItsSuffix() {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumJSONDepth: 3))
        let result = limitedImporter.importJSONLD(Data(#"][[[[0]]]]"#.utf8))

        XCTAssertTrue(result.candidates.isEmpty)
        XCTAssertEqual(
            result.diagnostics.last?.kind,
            .processingLimitExceeded(.jsonStructure)
        )
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

    func testInstructionScalarCannotExpandPastTheStepLimit() throws {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumInstructionItems: 2))
        let exactData = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Two steps",
            "recipeInstructions": "First\nSecond",
        ])
        let excessiveData = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Three steps",
            "recipeInstructions": "First\nSecond\nThird",
        ])

        XCTAssertEqual(
            limitedImporter.importJSONLD(exactData).unambiguousCandidate?
                .draft.instructionSections[0].steps.count,
            2
        )
        assertNormalizedOutputLimit(limitedImporter.importJSONLD(excessiveData))
    }

    func testHostileInstructionScalarStopsAtTheConfiguredStepLimit() throws {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumInstructionItems: 1_000))
        let data = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Many lines",
            "recipeInstructions": String(repeating: "a\n", count: 10_000),
        ])

        assertNormalizedOutputLimit(limitedImporter.importJSONLD(data))
    }

    func testInstructionScalarRecognizesCRLFAndUnicodeNewlines() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Newlines",
            "recipeInstructions": "First\r\n\r\nSecond\u{0085}Third\u{2028}Fourth\u{2029}Fifth",
        ])

        let steps = try XCTUnwrap(
            importer.importJSONLD(data).unambiguousCandidate
        ).draft.instructionSections[0].steps

        XCTAssertEqual(steps.map(\.text), ["First", "Second", "Third", "Fourth", "Fifth"])
    }

    func testInstructionArraysAndNestedSectionsShareOneExactStepLimit() throws {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumInstructionItems: 2))
        let exactArrayData = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Exact array",
            "recipeInstructions": ["One", "Two"],
        ])
        let arrayData = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Array steps",
            "recipeInstructions": ["One", "Two", "Three"],
        ])
        let sectionData = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Nested steps",
            "recipeInstructions": [[
                "@type": "HowToSection",
                "name": "Section",
                "itemListElement": ["One", "Two", "Three"],
            ]],
        ])
        let exactSectionData = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Exact section",
            "recipeInstructions": [[
                "@type": "HowToSection",
                "name": "Section",
                "itemListElement": ["One", "Two"],
            ]],
        ])

        XCTAssertEqual(
            limitedImporter.importJSONLD(exactArrayData).unambiguousCandidate?
                .draft.instructionSections[0].steps.count,
            2
        )
        XCTAssertEqual(
            limitedImporter.importJSONLD(exactSectionData).unambiguousCandidate?
                .draft.instructionSections[0].steps.count,
            2
        )
        assertNormalizedOutputLimit(limitedImporter.importJSONLD(arrayData))
        assertNormalizedOutputLimit(limitedImporter.importJSONLD(sectionData))
    }

    func testCommaSeparatedKeywordsCannotExpandPastTheTaxonomyLimit() throws {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumTaxonomyItems: 2))
        let exactData = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe", "name": "Exact", "keywords": "one,two",
        ])
        let excessiveData = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe", "name": "Excessive", "keywords": "one,two,three",
        ])

        XCTAssertEqual(
            limitedImporter.importJSONLD(exactData).unambiguousCandidate?.draft.keywords,
            ["one", "two"]
        )
        assertNormalizedOutputLimit(limitedImporter.importJSONLD(excessiveData))
    }

    func testEmptyNormalizedKeywordDoesNotConsumeTheTaxonomyBudget() throws {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumTaxonomyItems: 1))
        let data = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Keywords",
            "keywords": "one,, ,<script></script>,",
        ])

        XCTAssertEqual(
            limitedImporter.importJSONLD(data).unambiguousCandidate?.draft.keywords,
            ["one"]
        )
    }

    func testTaxonomyFieldsShareOneAggregateItemLimit() throws {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumTaxonomyItems: 2))
        let exactImporter = SchemaOrgRecipeImporter(limits: .init(maximumTaxonomyItems: 3))
        let data = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Taxonomy",
            "recipeCuisine": "Italian",
            "recipeCategory": "Dinner",
            "keywords": "quick",
        ])

        XCTAssertNotNil(exactImporter.importJSONLD(data).unambiguousCandidate)
        assertNormalizedOutputLimit(limitedImporter.importJSONLD(data))
    }

    func testJoinedAuthorAndStructuredIngredientRespectFinalFieldLimit() throws {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumFieldCharacters: 5))
        let exactAuthorImporter = SchemaOrgRecipeImporter(limits: .init(maximumFieldCharacters: 6))
        let exactIngredientImporter = SchemaOrgRecipeImporter(limits: .init(maximumFieldCharacters: 7))
        let authorData = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "A",
            "author": [["name": "aa"], ["name": "bb"]],
        ])
        let ingredientData = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Food",
            "recipeIngredient": [["value": "flour", "unitText": "g"]],
        ])

        XCTAssertEqual(
            exactAuthorImporter.importJSONLD(authorData).unambiguousCandidate?.draft.authorName,
            "aa, bb"
        )
        XCTAssertEqual(
            exactIngredientImporter.importJSONLD(ingredientData).unambiguousCandidate?
                .draft.ingredientSections[0].ingredients[0].originalText,
            "flour g"
        )
        assertNormalizedOutputLimit(limitedImporter.importJSONLD(authorData))
        assertNormalizedOutputLimit(limitedImporter.importJSONLD(ingredientData))
    }

    func testNormalizedUTF8BudgetCountsTheFinalStoredDraft() {
        let data = Data(#"{"@type":"Recipe","name":"é"}"#.utf8)
        let exactImporter = SchemaOrgRecipeImporter(limits: .init(maximumNormalizedUTF8Bytes: 4))
        let excessiveImporter = SchemaOrgRecipeImporter(limits: .init(maximumNormalizedUTF8Bytes: 3))

        // The two-byte title is stored as both content and source attribution.
        XCTAssertNotNil(exactImporter.importJSONLD(data).unambiguousCandidate)
        assertNormalizedOutputLimit(excessiveImporter.importJSONLD(data))
    }

    func testNormalizedUTF8BudgetIsSharedAcrossImportCandidates() {
        let data = Data(#"""
        [
          {"@type":"Recipe","name":"A"},
          {"@type":"Recipe","name":"B"}
        ]
        """#.utf8)
        let exactImporter = SchemaOrgRecipeImporter(limits: .init(maximumNormalizedUTF8Bytes: 4))
        let excessiveImporter = SchemaOrgRecipeImporter(limits: .init(maximumNormalizedUTF8Bytes: 3))

        XCTAssertEqual(exactImporter.importJSONLD(data).candidates.count, 2)
        assertNormalizedOutputLimit(excessiveImporter.importJSONLD(data))
    }

    func testImageURLsRespectTheirOwnOutputLimit() throws {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(maximumImageURLs: 1))
        let exactImporter = SchemaOrgRecipeImporter(limits: .init(maximumImageURLs: 2))
        let data = try JSONSerialization.data(withJSONObject: [
            "@type": "Recipe",
            "name": "Images",
            "image": ["https://example.com/one.jpg", "https://example.com/two.jpg"],
        ])

        XCTAssertEqual(
            exactImporter.importJSONLD(data).unambiguousCandidate?.draft.imageURLs.count,
            2
        )
        assertNormalizedOutputLimit(limitedImporter.importJSONLD(data))
    }

    func testExtremeConfiguredLimitsDoNotOverflowPreflightArithmetic() {
        let limitedImporter = SchemaOrgRecipeImporter(limits: .init(
            maximumIngredients: .max,
            maximumInstructionItems: .max
        ))

        XCTAssertNotNil(
            limitedImporter.importJSONLD(
                Data(#"{"@type":"Recipe","name":"Safe"}"#.utf8)
            ).unambiguousCandidate
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

    private func assertNormalizedOutputLimit(
        _ result: RecipeImportResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(result.candidates.isEmpty, file: file, line: line)
        XCTAssertEqual(
            result.diagnostics.last?.kind,
            .processingLimitExceeded(.normalizedOutput),
            file: file,
            line: line
        )
    }

    private func assertInputByteLimit(
        _ result: RecipeImportResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(result.candidates.isEmpty, file: file, line: line)
        XCTAssertEqual(
            result.diagnostics.last?.kind,
            .processingLimitExceeded(.inputBytes),
            file: file,
            line: line
        )
    }

    private func encoded(
        _ text: String,
        as encoding: String.Encoding,
        byteOrderMark: [UInt8]
    ) throws -> Data {
        var payload = try XCTUnwrap(text.data(using: encoding))
        if payload.starts(with: byteOrderMark) {
            payload.removeFirst(byteOrderMark.count)
        }
        var result = Data(byteOrderMark)
        result.append(payload)
        return result
    }
}
