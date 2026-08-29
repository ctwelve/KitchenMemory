// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain

/// Resource limits applied while interpreting untrusted recipe JSON-LD.
///
/// The same byte ceiling applies to fetched and direct inputs, while the other
/// limits bound structural expansion after acquisition. Defaults are
/// intentionally generous for real recipes but finite so a compact document
/// cannot create an unbounded object graph, candidate list, or editor model.
public struct RecipeImportLimits: Equatable, Sendable {
    /// Maximum encoded bytes accepted by a direct HTML or JSON-LD import call.
    public let maximumInputBytes: Int
    public let maximumJSONLDBlocks: Int
    public let maximumJSONDepth: Int
    public let maximumJSONTokens: Int
    public let maximumTopLevelObjects: Int
    public let maximumCandidates: Int
    public let maximumFieldCharacters: Int
    /// Total UTF-8 bytes retained across every candidate returned by one import.
    public let maximumNormalizedUTF8Bytes: Int
    /// Maximum emitted cuisine, category, and keyword values per recipe.
    public let maximumTaxonomyItems: Int
    /// Maximum emitted image URLs per recipe.
    public let maximumImageURLs: Int
    public let maximumIngredients: Int
    public let maximumInstructionItems: Int

    public init(
        maximumInputBytes: Int = 2 * 1_024 * 1_024,
        maximumJSONLDBlocks: Int = 32,
        maximumJSONDepth: Int = 32,
        maximumJSONTokens: Int = 100_000,
        maximumTopLevelObjects: Int = 1_000,
        maximumCandidates: Int = 25,
        maximumFieldCharacters: Int = 20_000,
        maximumNormalizedUTF8Bytes: Int = 2 * 1_024 * 1_024,
        maximumTaxonomyItems: Int = 2_000,
        maximumImageURLs: Int = 500,
        maximumIngredients: Int = 500,
        maximumInstructionItems: Int = 1_000
    ) {
        precondition(maximumInputBytes > 0)
        precondition(maximumJSONLDBlocks > 0)
        precondition(maximumJSONDepth > 0)
        precondition(maximumJSONTokens > 0)
        precondition(maximumTopLevelObjects > 0)
        precondition(maximumCandidates > 0)
        precondition(maximumFieldCharacters > 0)
        precondition(maximumNormalizedUTF8Bytes > 0)
        precondition(maximumTaxonomyItems > 0)
        precondition(maximumImageURLs > 0)
        precondition(maximumIngredients > 0)
        precondition(maximumInstructionItems > 0)
        self.maximumInputBytes = maximumInputBytes
        self.maximumJSONLDBlocks = maximumJSONLDBlocks
        self.maximumJSONDepth = maximumJSONDepth
        self.maximumJSONTokens = maximumJSONTokens
        self.maximumTopLevelObjects = maximumTopLevelObjects
        self.maximumCandidates = maximumCandidates
        self.maximumFieldCharacters = maximumFieldCharacters
        self.maximumNormalizedUTF8Bytes = maximumNormalizedUTF8Bytes
        self.maximumTaxonomyItems = maximumTaxonomyItems
        self.maximumImageURLs = maximumImageURLs
        self.maximumIngredients = maximumIngredients
        self.maximumInstructionItems = maximumInstructionItems
    }

    func limitingCandidates(to maximum: Int) -> Self {
        Self(
            maximumInputBytes: maximumInputBytes,
            maximumJSONLDBlocks: maximumJSONLDBlocks,
            maximumJSONDepth: maximumJSONDepth,
            maximumJSONTokens: maximumJSONTokens,
            maximumTopLevelObjects: maximumTopLevelObjects,
            maximumCandidates: min(maximumCandidates, maximum),
            maximumFieldCharacters: maximumFieldCharacters,
            maximumNormalizedUTF8Bytes: maximumNormalizedUTF8Bytes,
            maximumTaxonomyItems: maximumTaxonomyItems,
            maximumImageURLs: maximumImageURLs,
            maximumIngredients: maximumIngredients,
            maximumInstructionItems: maximumInstructionItems
        )
    }
}

/// Immutable evidence retained alongside an interpreted import candidate.
///
/// Keeping a UTF-8 transcription of the containing JSON-LD block makes the
/// first interpretation reversible: fields that Kitchen Memory does not
/// understand yet are not discarded. The candidate's block and object indices
/// identify the selected interpretation without retaining a second serialized
/// copy of its subtree.
public struct RecipeImportSourceSnapshot: Equatable, Sendable {
    public let documentURL: URL?
    /// Source-faithful UTF-8 text from the containing JSON-LD script block.
    ///
    /// The data preserves JSON spelling, whitespace, key order, unknown
    /// properties, and Unicode scalar content after the surrounding document is
    /// decoded. It does not preserve the HTTP response's original byte encoding,
    /// byte-order mark, or surrounding HTML.
    public let jsonLD: Data

    public init(documentURL: URL?, jsonLD: Data) {
        self.documentURL = documentURL
        self.jsonLD = jsonLD
    }
}

public struct RecipeImportDraft: Equatable, Sendable {
    public var title: String
    public var summary: String?
    public var authorName: String?
    public var contentLanguage: RecipeContentLanguage?
    public var source: RecipeSource
    public var recipeYield: RecipeYield?
    public var prepDuration: RecipeDuration?
    public var cookDuration: RecipeDuration?
    public var totalDuration: RecipeDuration?
    public var cuisines: [String]
    public var categories: [String]
    public var keywords: [String]
    public var imageURLs: [URL]
    public var ingredientSections: [IngredientSection]
    public var instructionSections: [InstructionSection]

    public init(
        title: String,
        summary: String? = nil,
        authorName: String? = nil,
        contentLanguage: RecipeContentLanguage? = nil,
        source: RecipeSource,
        recipeYield: RecipeYield? = nil,
        prepDuration: RecipeDuration? = nil,
        cookDuration: RecipeDuration? = nil,
        totalDuration: RecipeDuration? = nil,
        cuisines: [String] = [],
        categories: [String] = [],
        keywords: [String] = [],
        imageURLs: [URL] = [],
        ingredientSections: [IngredientSection] = [],
        instructionSections: [InstructionSection] = []
    ) {
        self.title = title
        self.summary = summary
        self.authorName = authorName
        self.contentLanguage = contentLanguage
        self.source = source
        self.recipeYield = recipeYield
        self.prepDuration = prepDuration
        self.cookDuration = cookDuration
        self.totalDuration = totalDuration
        self.cuisines = cuisines
        self.categories = categories
        self.keywords = keywords
        self.imageURLs = imageURLs
        self.ingredientSections = ingredientSections
        self.instructionSections = instructionSections
    }
}

public struct RecipeImportCandidate: Equatable, Identifiable, Sendable {
    public struct ID: Hashable, Sendable {
        public var blockIndex: Int
        public var objectIndex: Int

        public init(blockIndex: Int, objectIndex: Int) {
            self.blockIndex = blockIndex
            self.objectIndex = objectIndex
        }
    }

    public var id: ID
    public var draft: RecipeImportDraft
    public var snapshot: RecipeImportSourceSnapshot

    public init(id: ID, draft: RecipeImportDraft, snapshot: RecipeImportSourceSnapshot) {
        self.id = id
        self.draft = draft
        self.snapshot = snapshot
    }
}

public struct RecipeImportDiagnostic: Equatable, Sendable {
    public enum ProcessingLimit: Equatable, Sendable {
        case inputBytes
        case jsonLDBlocks
        case jsonStructure
        case topLevelObjects
        case candidates
        case consumedFields
        case normalizedOutput
    }

    public enum Kind: Equatable, Sendable {
        case malformedJSONLD
        case unsupportedTopLevel
        case missingTitle
        case processingLimitExceeded(ProcessingLimit)
    }

    public var blockIndex: Int
    public var kind: Kind

    public init(blockIndex: Int, kind: Kind) {
        self.blockIndex = blockIndex
        self.kind = kind
    }
}

public struct RecipeImportResult: Equatable, Sendable {
    public var candidates: [RecipeImportCandidate]
    public var diagnostics: [RecipeImportDiagnostic]

    public init(
        candidates: [RecipeImportCandidate],
        diagnostics: [RecipeImportDiagnostic] = []
    ) {
        self.candidates = candidates
        self.diagnostics = diagnostics
    }

    /// A caller may skip candidate choice only when discovery found one recipe.
    public var unambiguousCandidate: RecipeImportCandidate? {
        candidates.count == 1 ? candidates[0] : nil
    }
}
