// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemorySampleData
import XCTest

final class SampleRecipeCatalogTests: XCTestCase {
    func testManifestLoadsFromAssetCatalogWithStableKitchenIdentity() throws {
        let manifest = try SampleRecipeCatalog.loadManifest()

        XCTAssertEqual(manifest.formatVersion, 1)
        XCTAssertEqual(
            manifest.kitchenID.rawValue,
            UUID(uuidString: "5F366829-6A6A-4F88-87F8-43BDFD2E88F4")
        )
        XCTAssertTrue(manifest.recipeIDs.isEmpty)
    }
}
