// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import XCTest

final class DomainSkeletonTests: XCTestCase {
    func testInitialRecipeRelationshipsUseStableIdentifiers() throws {
        let kitchenID = Kitchen.ID(rawValue: UUID(uuidString: "5F366829-6A6A-4F88-87F8-43BDFD2E88F4")!)
        let recipeID = Recipe.ID(rawValue: UUID(uuidString: "95781805-F5D3-46B0-B685-A660F8AC69F2")!)
        let revisionID = RecipeRevision.ID(rawValue: UUID(uuidString: "CD477A1F-A876-4C08-8AC9-1915ACD71E88")!)

        let kitchen = Kitchen(id: kitchenID, name: "Home")
        let recipe = Recipe(id: recipeID, kitchenID: kitchen.id, currentRevisionID: revisionID)
        let revision = RecipeRevision(
            id: revisionID,
            recipeID: recipe.id,
            revisionNumber: 1,
            title: "Tuna Noodle Hotdish"
        )

        XCTAssertEqual(recipe.kitchenID, kitchen.id)
        XCTAssertEqual(recipe.currentRevisionID, revision.id)
        XCTAssertEqual(revision.recipeID, recipe.id)
    }

    func testDomainValuesRoundTripThroughJSON() throws {
        let kitchen = Kitchen(name: "Home")
        let data = try JSONEncoder().encode(kitchen)

        XCTAssertEqual(try JSONDecoder().decode(Kitchen.self, from: data), kitchen)
    }
}
