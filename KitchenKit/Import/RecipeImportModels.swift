// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Resource limits applied while interpreting untrusted recipe JSON-LD.
///
/// The same byte ceiling applies to fetched and direct inputs, while the other
/// limits bound structural expansion after acquisition. Defaults are
/// intentionally generous for real recipes but finite so a compact document
/// cannot create an unbounded object graph, candidate list, or editor model.
public struct RecipeImportLimits: Equatable, Sendable {
    /// Maximum encoded bytes accepted by a direct HTML or JSON-LD import call.
    public let maximumInputBytes: Int
    /// The number of discovered JSON-LD script blocks permitted in one HTML input.
    public let maximumJSONLDBlocks: Int
    /// The maximum bracket/container nesting accepted before Foundation allocates the JSON graph.
    public let maximumJSONDepth: Int
    /// The structural token ceiling enforced by the quote-aware preflight scanner.
    public let maximumJSONTokens: Int
    /// The maximum objects visited through top-level arrays and `@graph` discovery per block.
    public let maximumTopLevelObjects: Int
    /// The maximum Recipe candidates across all blocks; exceeding it discards the candidate result.
    public let maximumCandidates: Int
    /// The grapheme-cluster ceiling for each interpreted source field, distinct from UTF-8 output bytes.
    public let maximumFieldCharacters: Int
    /// Aggregate UTF-8 allowance for normalized text and URLs across candidate drafts.
    ///
    /// Source-block transcriptions remain independently bounded by the input budget;
    /// this allowance is not a total allocation or process-memory ceiling.
    public let maximumNormalizedUTF8Bytes: Int
    /// Maximum emitted cuisine, category, and keyword values per recipe.
    public let maximumTaxonomyItems: Int
    /// Maximum emitted image URLs per recipe.
    public let maximumImageURLs: Int
    /// The per-Recipe ingredient item ceiling enforced before row construction.
    public let maximumIngredients: Int
    /// The per-Recipe emitted instruction item ceiling, including split scalar instructions.
    public let maximumInstructionItems: Int

    /// Configures independent transport-input, structural, field, and emitted-model budgets.
    ///
    /// Every ceiling must be strictly positive or construction traps. Resource failures
    /// produce diagnostics and discard candidates rather than returning truncated content.
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
    /// The acquired document location, when known; it is not a publisher-declared canonical link.
    public let documentURL: URL?
    /// Source-faithful UTF-8 text from the containing JSON-LD script block.
    ///
    /// The data preserves JSON spelling, whitespace, key order, unknown
    /// properties, and Unicode scalar content after the surrounding document is
    /// decoded. It does not preserve the HTTP response's original byte encoding,
    /// byte-order mark, or surrounding HTML.
    public let jsonLD: Data

    /// Retains one source transcription without parsing or executing its JSON text.
    public init(documentURL: URL?, jsonLD: Data) {
        self.documentURL = documentURL
        self.jsonLD = jsonLD
    }
}

/// Provisional normalized Recipe content awaiting a person’s review.
///
/// This value creates no durable Recipe identity or authority. Source evidence is
/// retained separately, and referenced images have not been downloaded.
public struct RecipeImportDraft: Equatable, Sendable {
    /// The authored Recipe title retained independently of the interface locale.
    public var title: String
    /// Optional authored descriptive text, without inferred cooking results.
    public var summary: String?
    /// Human-readable content attribution, independent of Kitchen ownership.
    public var authorName: String?
    /// The authored content language, or nil when unknown; it is not the interface locale.
    public var contentLanguage: RecipeContentLanguage?
    /// Provisional editable attribution; the containing source block remains separately retained.
    public var source: RecipeSource
    /// The authored base output with original wording and optional numeric interpretation.
    public var recipeYield: RecipeYield?
    /// Optional active preparation duration as authored, without inferring missing timing.
    public var prepDuration: RecipeDuration?
    /// Optional authored cooking duration, independent of running Session timers.
    public var cookDuration: RecipeDuration?
    /// The authored total duration, retained independently of prep-plus-cook arithmetic.
    public var totalDuration: RecipeDuration?
    /// Authored cuisine classifications, distinct from Kitchen-owned Tag identities.
    public var cuisines: [String]
    /// Authored Recipe categories, distinct from Folder placement or Tag identity.
    public var categories: [String]
    /// Authored descriptive terms, without automatically assigning Kitchen-owned Tags.
    public var keywords: [String]
    /// Referenced structurally allowed image locations; import does not download their bytes.
    public var imageURLs: [URL]
    /// Ingredient groups and rows in authored order, preserving optional structure and wording.
    public var ingredientSections: [IngredientSection]
    /// Instruction groups and steps in authored order, independent of cooking progress.
    public var instructionSections: [InstructionSection]

    /// Assembles review content without minting a Recipe identity or publishing maintained history.
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

/// One discovered Recipe interpretation paired with its containing source block.
public struct RecipeImportCandidate: Equatable, Identifiable, Sendable {
    /// Traversal coordinates identifying a candidate within this import result.
    ///
    /// These are neither durable Recipe identities nor permanent JSON Pointers.
    public struct ID: Hashable, Sendable {
        /// Zero-based JSON-LD block position in this importer’s discovery order.
        public var blockIndex: Int
        /// Zero-based discovered object position within the containing block, including non-Recipe objects.
        public var objectIndex: Int

        /// Retains discovery coordinates; reuse only within the interpretation that produced them.
        public init(blockIndex: Int, objectIndex: Int) {
            self.blockIndex = blockIndex
            self.objectIndex = objectIndex
        }
    }

    /// Traversal coordinates identifying this candidate within the current result.
    public var id: ID
    /// The provisional normalized interpretation offered for review.
    public var draft: RecipeImportDraft
    /// The containing JSON-LD block retained independently of mutable review fields.
    public var snapshot: RecipeImportSourceSnapshot

    /// Pairs an interpretation with its source block without selecting or saving a Recipe.
    public init(id: ID, draft: RecipeImportDraft, snapshot: RecipeImportSourceSnapshot) {
        self.id = id
        self.draft = draft
        self.snapshot = snapshot
    }
}

/// A block-associated concern retained alongside otherwise usable candidates.
public struct RecipeImportDiagnostic: Equatable, Sendable {
    /// The resource-budget stage that rejected the import rather than returning truncated content.
    public enum ProcessingLimit: Equatable, Sendable {
        /// Direct or normalized input exceeded the bounded byte allowance.
        case inputBytes
        /// HTML discovery found more JSON-LD blocks than permitted.
        case jsonLDBlocks
        /// Preflight found excessive JSON nesting or structural tokens.
        case jsonStructure
        /// Top-level array or `@graph` traversal exhausted its object allowance.
        case topLevelObjects
        /// Discovery found more Recipe candidates than permitted.
        case candidates
        /// An interpreted field exceeded its string or collection preflight budget.
        case consumedFields
        /// Constructed normalized values exhausted an emitted-item or aggregate UTF-8 budget.
        case normalizedOutput
    }

    /// A source or resource concern; missing titles and malformed sibling blocks can remain reviewable.
    public enum Kind: Equatable, Sendable {
        /// This source block could not decode or parse; other blocks can remain usable.
        case malformedJSONLD
        /// The parsed block yielded no traversable top-level objects.
        case unsupportedTopLevel
        /// A Recipe candidate has no usable title and retains an empty title for review.
        case missingTitle
        /// A resource ceiling was reached; the operation returns diagnostics without partial candidates.
        case processingLimitExceeded(ProcessingLimit)
    }

    /// Zero-based containing block index; whole-input limit failures use zero.
    public var blockIndex: Int
    /// The parse concern or bounded-processing failure associated with this block.
    public var kind: Kind

    /// Retains a diagnostic without altering candidate content or retained source evidence.
    public init(blockIndex: Int, kind: Kind) {
        self.blockIndex = blockIndex
        self.kind = kind
    }
}

/// All discovered candidates and diagnostics from one bounded deterministic parse.
///
/// A processing-limit failure discards candidates rather than exposing a silently
/// truncated discovery result; ordinary malformed sibling blocks remain diagnostic.
public struct RecipeImportResult: Equatable, Sendable {
    /// All usable discovered interpretations, without an automatic durable Recipe selection.
    public var candidates: [RecipeImportCandidate]
    /// Source concerns and resource failures retained for review or operation-level handling.
    public var diagnostics: [RecipeImportDiagnostic]

    /// Collects candidates and diagnostics without selecting, validating, or publishing them.
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
