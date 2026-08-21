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
        XCTAssertEqual(manifest.formatVersion, 1)
        XCTAssertEqual(
            manifest.recipes.map(\.dataAssetName),
            ["TunaNoodleHotdishRecipe", "DirtyFriedRiceRecipe"]
        )
    }

    func testTunaNoodleHotdishUsesFullRecipeContentAndDestinationKitchen() throws {
        let reference = try XCTUnwrap(SampleRecipeCatalog.loadManifest().recipes.first)
        let document = try SampleRecipeCatalog.loadRecipe(reference)
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

    func testDirtyFriedRicePreservesFuzzyAmountsSourceAndThermalTechnique() throws {
        let manifest = try SampleRecipeCatalog.loadManifest()
        let reference = try XCTUnwrap(
            manifest.recipes.first { $0.dataAssetName == "DirtyFriedRiceRecipe" }
        )
        let document = try SampleRecipeCatalog.loadRecipe(reference)
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
        XCTAssertTrue(revision.instructionSections[2].steps[0].name == "KILL THE HEAT")
        XCTAssertTrue(revision.instructionSections[2].steps[1].text.contains("snaps into focus"))
        XCTAssertTrue(revision.instructionSections[2].steps[3].text.contains("thermal flywheel"))
    }
}
