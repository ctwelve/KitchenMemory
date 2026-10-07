// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
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

/// One recipe family with localized, independently identified bundled variants.
public struct SampleRecipeReference: Codable, Equatable, Sendable {
    public let familyID: UUID
    public let variants: [LocalizedSampleRecipeReference]
}

/// Asset names and stable recipe identity for one bundled language variant.
public struct LocalizedSampleRecipeReference: Codable, Equatable, Sendable {
    public let localeIdentifier: String
    public let recipeID: Recipe.ID
    public let dataAssetName: String
    public let heroImageAssetName: String?
}

public extension SampleRecipeReference {
    /// Selects exact locale, then language matches in preference order, then English.
    /// Returns no variant if neither the preferences nor the English fallback match.
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

/// Decoded bundle content awaiting attachment to a prepared Kitchen.
/// Loading this value does not install or save a recipe.
public struct SampleRecipeDocument: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let recipeID: Recipe.ID
    public let revision: RecipeRevision

    /// Attaches the bundled recipe identity to a Kitchen without changing its Revision.
    /// Identity mismatch throws before a value can reach the install service.
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

/// A Kitchen-scoped recipe and its unchanged bundled Revision, ready for installation.
public struct SampleRecipeMaterialization: Equatable, Sendable {
    public let recipe: Recipe
    public let revision: RecipeRevision
}

/// Classifies resource lookup and identity failures at the application bundle boundary.
public enum SampleRecipeCatalogError: Error, Equatable {
    case missingAsset(String)
    case inconsistentRecipeIdentity
    case unsupportedPlatform
}

/// Loads deterministic sample content from the application's asset catalog.
///
/// ``BundledSampleRecipeProvider`` implements KitchenKit's sample capability
/// with this catalog. Resource loading and locale choice remain app-owned;
/// KitchenKit's install service decides whether to save materialized recipes.
/// The catalog resolves its own bundle so a hosted test's main bundle cannot
/// silently redirect lookup away from application resources.
public enum SampleRecipeCatalog {
    static let resourceBundle = Bundle(for: SampleRecipeCatalogBundleToken.self)

    /// Decodes the pack index from the catalog's containing bundle.
    public static func loadManifest() throws -> SampleRecipePackManifest {
        try decodeAsset(named: "SampleManifest", as: SampleRecipePackManifest.self)
    }

    /// Decodes a selected variant and verifies that the asset matches its recipe identity.
    public static func loadRecipe(
        _ reference: LocalizedSampleRecipeReference
    ) throws -> SampleRecipeDocument {
        let document = try decodeAsset(named: reference.dataAssetName, as: SampleRecipeDocument.self)
        guard document.recipeID == reference.recipeID else {
            throw SampleRecipeCatalogError.inconsistentRecipeIdentity
        }
        return document
    }

    /// Resolves one variant per manifest family, preserving manifest order.
    /// Missing language fallbacks fail the complete request rather than skipping a family.
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
