// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Foundation
import KitchenMemoryDomain

/// The versioned index of sample content bundled with the package.
public struct SampleRecipeManifest: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let recipeIDs: [Recipe.ID]

    public init(formatVersion: Int, recipeIDs: [Recipe.ID]) {
        self.formatVersion = formatVersion
        self.recipeIDs = recipeIDs
    }
}

public enum SampleRecipeCatalogError: Error, Equatable {
    case missingManifest
    case unsupportedPlatform
}

/// Loads deterministic sample content from the package's asset catalog.
public enum SampleRecipeCatalog {
    public static func loadManifest() throws -> SampleRecipeManifest {
        let data = try manifestData()
        return try JSONDecoder().decode(SampleRecipeManifest.self, from: data)
    }

    private static func manifestData() throws -> Data {
#if canImport(AppKit) || canImport(UIKit)
        if let asset = NSDataAsset(name: "SampleManifest", bundle: .module) {
            return asset.data
        }
#endif

        guard let url = Bundle.module.url(
            forResource: "sample-manifest",
            withExtension: "json",
            subdirectory: "SampleRecipes.xcassets/SampleManifest.dataset"
        ) else {
#if canImport(AppKit) || canImport(UIKit)
            throw SampleRecipeCatalogError.missingManifest
#else
            throw SampleRecipeCatalogError.unsupportedPlatform
#endif
        }
        return try Data(contentsOf: url)
    }
}
