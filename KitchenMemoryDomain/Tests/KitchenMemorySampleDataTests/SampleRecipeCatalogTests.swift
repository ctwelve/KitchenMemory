// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import KitchenMemorySampleData
import XCTest

final class SampleRecipeCatalogTests: XCTestCase {
    func testManifestLoadsFromAssetCatalog() throws {
        let manifest = try SampleRecipeCatalog.loadManifest()

        XCTAssertEqual(manifest.name, "Kitchen Memory Samples")
        XCTAssertEqual(manifest.formatVersion, 1)
        XCTAssertEqual(manifest.recipes.count, 1)
        XCTAssertEqual(manifest.recipes.first?.dataAssetName, "TunaNoodleHotdish")
    }

    func testTunaNoodleHotdishUsesFullRecipeContentAndDestinationKitchen() throws {
        let reference = try XCTUnwrap(SampleRecipeCatalog.loadManifest().recipes.first)
        let document = try SampleRecipeCatalog.loadRecipe(reference)
        let destinationKitchenID = Kitchen.ID()
        let materialization = try document.materialize(in: destinationKitchenID)

        XCTAssertEqual(materialization.recipe.kitchenID, destinationKitchenID)
        XCTAssertEqual(materialization.revision.title, "Tuna Noodle Hotdish")
        XCTAssertEqual(materialization.revision.recipeYield?.originalText, "6 servings")
        XCTAssertEqual(materialization.revision.media.first?.assetName, "TunaNoodleHotdishHero")
        XCTAssertEqual(materialization.revision.ingredientSections.first?.ingredients.count, 9)
        XCTAssertEqual(materialization.revision.instructionSections.first?.steps.count, 6)
        XCTAssertEqual(
            materialization.revision.ingredientSections.first?.ingredients[6].quantity?.lowerBound,
            RationalQuantity(numerator: 1, denominator: 2)
        )
    }
}
