// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
@testable import KitchenMemory
import KitchenMemoryDomain
import XCTest

@MainActor
final class SampleRecipeCatalogTests: XCTestCase {
    func testManifestLoadsFromAssetCatalog() throws {
        let manifest = try SampleRecipeCatalog.loadManifest()

        XCTAssertEqual(manifest.name, "Kitchen Memory Samples")
        XCTAssertEqual(manifest.formatVersion, 2)
        XCTAssertEqual(
            manifest.recipes.compactMap { $0.variant(preferredLanguages: ["en-US"])?.dataAssetName },
            ["TunaNoodleHotdishRecipe", "DirtyFriedRiceRecipe", "RedEngineRecipe"]
        )
    }

    func testTunaNoodleHotdishUsesFullRecipeContentAndDestinationKitchen() throws {
        let reference = try XCTUnwrap(SampleRecipeCatalog.loadManifest().recipes.first)
        let document = try SampleRecipeCatalog.loadRecipe(
            try XCTUnwrap(reference.variant(preferredLanguages: ["en-US"]))
        )
        let destinationKitchenID = Kitchen.ID()
        let materialization = try document.materialize(in: destinationKitchenID)

        XCTAssertEqual(materialization.recipe.kitchenID, destinationKitchenID)
        XCTAssertEqual(materialization.revision.title, "Tuna Noodle Hotdish")
        XCTAssertEqual(materialization.revision.recipeYield?.originalText, "Serves 8 generously")
        XCTAssertEqual(materialization.revision.media.map(\.role), [.hero, .thumbnail, .gallery])
        XCTAssertEqual(
            materialization.revision.media.map(\.assetName),
            [
                "TunaNoodleHotdishHero",
                "TunaNoodleHotdishThumbnail",
                "TunaNoodleHotdishGallery0",
            ]
        )
        XCTAssertEqual(materialization.revision.equipment.count, 5)
        XCTAssertEqual(materialization.revision.ingredientSections.map(\.ingredients.count), [6, 10, 3])
        XCTAssertEqual(materialization.revision.instructionSections.map(\.steps.count), [6, 8, 8])
        XCTAssertEqual(
            materialization.revision.ingredientSections.last?.ingredients[1].quantity?.lowerBound,
            RationalQuantity(numerator: 1, denominator: 2)
        )
        XCTAssertTrue(materialization.revision.instructionSections[1].steps[1].text.contains("Montreal"))
        XCTAssertTrue(materialization.revision.instructionSections[1].steps[3].text.contains("cayenne"))
        XCTAssertTrue(materialization.revision.instructionSections[1].steps[5].text.contains("burned electrical wire"))
    }

    func testTunaNoodleHotdishVariantsCarryObservedTimings() throws {
        let reference = try XCTUnwrap(SampleRecipeCatalog.loadManifest().recipes.first)

        for localeIdentifier in ["en-US", "fr-CA", "es-MX"] {
            let variant = try XCTUnwrap(
                reference.variant(preferredLanguages: [localeIdentifier])
            )
            let revision = try SampleRecipeCatalog.loadRecipe(variant).revision

            XCTAssertEqual(revision.prepDuration?.seconds, 1_800)
            XCTAssertEqual(revision.cookDuration?.seconds, 1_200)
            XCTAssertEqual(revision.totalDuration?.seconds, 3_600)
        }
    }

    func testDirtyFriedRicePreservesFuzzyAmountsSourceAndThermalTechnique() throws {
        let manifest = try SampleRecipeCatalog.loadManifest()
        let reference = try XCTUnwrap(
            manifest.recipes.first {
                $0.variants.contains { $0.dataAssetName == "DirtyFriedRiceRecipe" }
            }
        )
        let document = try SampleRecipeCatalog.loadRecipe(
            try XCTUnwrap(reference.variant(preferredLanguages: ["en-US"]))
        )
        let destinationKitchenID = Kitchen.ID()
        let materialization = try document.materialize(in: destinationKitchenID)
        let revision = materialization.revision

        XCTAssertEqual(materialization.recipe.kitchenID, destinationKitchenID)
        XCTAssertEqual(revision.title, "Dirty Fried Rice")
        XCTAssertEqual(revision.authorName, "cTwelve")
        XCTAssertEqual(revision.recipeYield?.originalText, "Makes one enormous skillet")
        XCTAssertNil(revision.totalDuration)
        XCTAssertEqual(
            revision.source?.canonicalURL?.absoluteString,
            "https://x.com/theCTwelve/status/2089465462723682809"
        )
        XCTAssertEqual(revision.media.map(\.role), [.hero])
        XCTAssertEqual(revision.media.map(\.assetName), ["DirtyFriedRiceHero"])
        XCTAssertEqual(revision.equipment.count, 5)
        XCTAssertEqual(revision.ingredientSections.map(\.ingredients.count), [8, 6])
        XCTAssertEqual(revision.instructionSections.map(\.steps.count), [3, 4, 4])
        XCTAssertEqual(
            revision.ingredientSections[0].ingredients[0].quantity?.lowerBound,
            RationalQuantity(numerator: 13, denominator: 10)
        )
        XCTAssertEqual(
            revision.ingredientSections[1].ingredients[4].quantity?.text,
            "to taste"
        )
        XCTAssertEqual(revision.instructionSections[2].steps[0].name, "KILL THE HEAT")
        XCTAssertTrue(revision.instructionSections[2].steps[1].text.contains("snaps into focus"))
        XCTAssertTrue(revision.instructionSections[2].steps[3].text.contains("thermal flywheel"))
    }

    func testRedEnginePreservesObservedCookAndConditionalSeasoning() throws {
        let manifest = try SampleRecipeCatalog.loadManifest()
        let reference = try XCTUnwrap(
            manifest.recipes.first {
                $0.variants.contains { $0.dataAssetName == "RedEngineRecipe" }
            }
        )
        let document = try SampleRecipeCatalog.loadRecipe(
            try XCTUnwrap(reference.variant(preferredLanguages: ["en-US"]))
        )
        let revision = document.revision

        XCTAssertEqual(revision.title, "The Red Engine")
        XCTAssertEqual(
            revision.recipeYield?.originalText,
            "Makes one very large batch with substantial leftovers"
        )
        XCTAssertEqual(
            revision.source?.canonicalURL?.absoluteString,
            "https://chatgpt.com/share/6a8d0c0c-b420-83ea-b94d-50d5b4c13cf3"
        )
        XCTAssertNil(revision.prepDuration)
        XCTAssertNil(revision.cookDuration)
        XCTAssertNil(revision.totalDuration)
        XCTAssertNil(reference.variant(preferredLanguages: ["en-US"])?.heroImageAssetName)
        XCTAssertEqual(revision.media.map(\.role), [.gallery])
        XCTAssertEqual(revision.media.map(\.assetName), ["RedEngineGallery0"])
        XCTAssertEqual(revision.ingredientSections.map(\.ingredients.count), [11, 10])
        XCTAssertEqual(revision.instructionSections.map(\.steps.count), [3, 2, 1])
        XCTAssertTrue(revision.ingredientSections[0].ingredients[2].originalText.contains("comically large"))
        XCTAssertTrue(revision.ingredientSections[0].ingredients[9].originalText.contains("Hunt's"))
        XCTAssertEqual(
            revision.ingredientSections[1].ingredients[5].quantity?.lowerBound,
            RationalQuantity(numerator: 1, denominator: 2)
        )
        XCTAssertTrue(revision.ingredientSections[1].ingredients[7].isOptional)
        XCTAssertEqual(revision.ingredientSections[1].ingredients[7].note?.contains("tomato-bright"), true)
        XCTAssertEqual(revision.instructionSections[1].steps[1].duration?.seconds, 1_800)
        XCTAssertEqual(revision.instructionSections[1].steps[1].name?.contains("Stop screwing"), true)
    }

    func testLocaleSelectionHonorsPreferenceOrderAndFallbacks() throws {
        let reference = try XCTUnwrap(SampleRecipeCatalog.loadManifest().recipes.first)

        XCTAssertEqual(
            reference.variant(preferredLanguages: ["fr-FR", "es-MX"])?.localeIdentifier,
            "fr-CA",
            "A same-language variant should win before a later exact preference."
        )
        XCTAssertEqual(reference.variant(preferredLanguages: ["es-MX"])?.localeIdentifier, "es-MX")
        XCTAssertEqual(reference.variant(preferredLanguages: ["de-DE"])?.localeIdentifier, "en-US")
        XCTAssertEqual(reference.variant(preferredLanguages: [])?.localeIdentifier, "en-US")
    }

    func testLocalizedSamplesCarryMatchingAuthoredLanguageAndDistinctIdentity() throws {
        let manifest = try SampleRecipeCatalog.loadManifest()

        for localeIdentifier in ["en-US", "fr-CA", "es-MX"] {
            let references = try SampleRecipeCatalog.localizedRecipes(
                in: manifest,
                preferredLanguages: [localeIdentifier]
            )
            XCTAssertEqual(references.count, 3)
            XCTAssertEqual(Set(references.map(\.recipeID)).count, 3)

            for reference in references {
                let document = try SampleRecipeCatalog.loadRecipe(reference)
                XCTAssertEqual(document.revision.contentLanguage?.rawValue, localeIdentifier)
                XCTAssertEqual(document.recipeID, reference.recipeID)
            }
        }
    }
}
