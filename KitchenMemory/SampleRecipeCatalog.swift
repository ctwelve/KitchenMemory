// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import DeveloperToolsSupport
import Foundation
import KitchenKit

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
    public let familyID: UUID
    public let variants: [LocalizedSampleRecipeReference]
}

public struct LocalizedSampleRecipeReference: Codable, Equatable, Sendable {
    public let localeIdentifier: String
    public let recipeID: Recipe.ID
    public let dataAssetName: String
    public let heroImageAssetName: String?
}

public extension SampleRecipeReference {
    func variant(preferredLanguages: [String]) -> LocalizedSampleRecipeReference? {
        let preferences = preferredLanguages.map(Self.canonicalLocale)
        for preference in preferences {
            if let exact = variants.first(where: {
                Self.canonicalLocale($0.localeIdentifier) == preference
            }) {
                return exact
            }
            if let language = variants.first(where: {
                Self.language(of: $0.localeIdentifier) == Self.language(of: preference)
            }) {
                return language
            }
        }
        return variants.first { Self.language(of: $0.localeIdentifier) == "en" }
    }

    private static func canonicalLocale(_ identifier: String) -> String {
        Locale(identifier: identifier).identifier(.bcp47).lowercased()
    }

    private static func language(of identifier: String) -> String {
        canonicalLocale(identifier).split(separator: "-").first.map(String.init) ?? ""
    }
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

/// Loads deterministic sample content from the application's asset catalog.
public enum SampleRecipeCatalog {
    private static let resourceBundle = Bundle(for: SampleRecipeCatalogBundleToken.self)

    public static func loadManifest() throws -> SampleRecipePackManifest {
        try decodeAsset(named: "SampleManifest", as: SampleRecipePackManifest.self)
    }

    public static func loadRecipe(
        _ reference: LocalizedSampleRecipeReference
    ) throws -> SampleRecipeDocument {
        let document = try decodeAsset(named: reference.dataAssetName, as: SampleRecipeDocument.self)
        guard document.recipeID == reference.recipeID else {
            throw SampleRecipeCatalogError.inconsistentRecipeIdentity
        }
        return document
    }

    public static func localizedRecipes(
        in manifest: SampleRecipePackManifest,
        preferredLanguages: [String]
    ) throws -> [LocalizedSampleRecipeReference] {
        try manifest.recipes.map { reference in
            guard let variant = reference.variant(preferredLanguages: preferredLanguages) else {
                throw SampleRecipeCatalogError.missingAsset(reference.familyID.uuidString)
            }
            return variant
        }
    }

    /// Locates an image in the bundled sample pack.
    ///
    /// Production media storage will eventually supply recipe images. This
    /// bridge keeps deterministic sample media available to previews and the
    /// first read-only recipe surface without exposing bundle lookup details.
    public static func imageResource(named name: String) -> ImageResource {
        ImageResource(name: name, bundle: resourceBundle)
    }

    private static func decodeAsset<Value: Decodable>(named name: String, as type: Value.Type) throws -> Value {
        try PropertyListDecoder().decode(Value.self, from: data(named: name))
    }

    private static func data(named name: String) throws -> Data {
#if canImport(AppKit)
        if let asset = NSDataAsset(name: NSDataAsset.Name(name), bundle: resourceBundle) {
            return asset.data
        }
#elseif canImport(UIKit)
        if let asset = NSDataAsset(name: name, bundle: resourceBundle) {
            return asset.data
        }
#endif

        if let url = resourceBundle.url(
            forResource: name,
            withExtension: "plist",
            subdirectory: "SampleRecipes.xcassets/\(name).dataset"
        ) {
            return try Data(contentsOf: url)
        }

        if let url = copiedDataSetURL(named: name) {
            return try Data(contentsOf: url)
        }

#if canImport(AppKit) || canImport(UIKit)
        throw SampleRecipeCatalogError.missingAsset(name)
#else
        throw SampleRecipeCatalogError.unsupportedPlatform
#endif
    }

    private static func copiedDataSetURL(named name: String) -> URL? {
        guard let catalogURL = resourceBundle.url(
            forResource: "SampleRecipes",
            withExtension: "xcassets"
        ) else {
            return nil
        }

        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: catalogURL,
            includingPropertiesForKeys: keys
        ) else {
            return nil
        }

        return enumerator.compactMap { $0 as? URL }.first { url in
            url.pathExtension == "plist"
                && url.deletingLastPathComponent().lastPathComponent == "\(name).dataset"
        }
    }
}

/// Resolves resources from the bundle containing the application-owned catalog.
private final class SampleRecipeCatalogBundleToken: NSObject {}
