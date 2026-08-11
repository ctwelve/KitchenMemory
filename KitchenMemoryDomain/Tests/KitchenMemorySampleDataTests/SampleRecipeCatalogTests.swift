// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemorySampleData
import XCTest

final class SampleRecipeCatalogTests: XCTestCase {
    func testManifestLoadsFromAssetCatalog() throws {
        let manifest = try SampleRecipeCatalog.loadManifest()

        XCTAssertEqual(manifest.formatVersion, 1)
        XCTAssertTrue(manifest.recipeIDs.isEmpty)
    }
}
