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

/// The versioned index of a bundled recipe pack.
public struct SampleRecipePackManifest: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let formatVersion: Int
    public let name: String
    public let recipes: [SampleRecipeReference]

    public init(id: UUID, formatVersion: Int, name: String, recipes: [SampleRecipeReference]) {
        self.id = id
        self.formatVersion = formatVersion
        self.name = name
        self.recipes = recipes
    }
}

public struct SampleRecipeReference: Codable, Equatable, Sendable {
    public let recipeID: Recipe.ID
    public let dataAssetName: String
    public let heroImageAssetName: String?
}

public struct SampleRecipeDocument: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let recipeID: Recipe.ID
    public let revision: RecipeRevision

    public func materialize(in kitchenID: Kitchen.ID) throws -> SampleRecipeMaterialization {
        guard revision.recipeID == recipeID else {
            throw SampleRecipeCatalogError.inconsistentRecipeIdentity
        }
        return SampleRecipeMaterialization(
            recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id),
            revision: revision
        )
    }
}

public struct SampleRecipeMaterialization: Equatable, Sendable {
    public let recipe: Recipe
    public let revision: RecipeRevision
}

public enum SampleRecipeCatalogError: Error, Equatable {
    case missingAsset(String)
    case inconsistentRecipeIdentity
    case unsupportedPlatform
}

/// Loads deterministic sample content from the package's asset catalog.
public enum SampleRecipeCatalog {
    public static func loadManifest() throws -> SampleRecipePackManifest {
        try decodeAsset(named: "SampleManifest", as: SampleRecipePackManifest.self)
    }

    public static func loadRecipe(_ reference: SampleRecipeReference) throws -> SampleRecipeDocument {
        let document = try decodeAsset(named: reference.dataAssetName, as: SampleRecipeDocument.self)
        guard document.recipeID == reference.recipeID else {
            throw SampleRecipeCatalogError.inconsistentRecipeIdentity
        }
        return document
    }

    private static func decodeAsset<Value: Decodable>(named name: String, as type: Value.Type) throws -> Value {
        try PropertyListDecoder().decode(Value.self, from: data(named: name))
    }

    private static func data(named name: String) throws -> Data {
#if canImport(AppKit) || canImport(UIKit)
        if let asset = NSDataAsset(name: NSDataAsset.Name(name), bundle: .module) {
            return asset.data
        }
#endif

        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "plist",
            subdirectory: "SampleRecipes.xcassets/\(name).dataset"
        ) else {
#if canImport(AppKit) || canImport(UIKit)
            throw SampleRecipeCatalogError.missingAsset(name)
#else
            throw SampleRecipeCatalogError.unsupportedPlatform
#endif
        }
        return try Data(contentsOf: url)
    }
}
