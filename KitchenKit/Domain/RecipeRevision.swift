// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// A canonical BCP 47 tag describing a recipe revision's authored language.
public struct RecipeContentLanguage: Codable, Equatable, Hashable, RawRepresentable, Sendable {
    /// Foundation’s canonical BCP 47 spelling of the authored content language.
    public let rawValue: String

    /// Trims and canonicalizes a language identifier through Foundation.
    ///
    /// Returns nil for empty input or the undetermined `und` result; this is not an
    /// exhaustive language-tag validator.
    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let canonical = Locale(identifier: trimmed).identifier(.bcp47)
        guard canonical != "und" else { return nil }
        self.rawValue = canonical
    }

    /// Decodes one string through the same Foundation canonicalization as direct construction.
    ///
    /// Throws `DecodingError.dataCorrupted` for an empty or undetermined tag.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let language = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a valid BCP 47 language tag."
            )
        }
        self = language
    }

    /// Encodes the canonical tag as a single string.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// One intentional representation of a recipe at a point in its history.
public struct RecipeRevision: Codable, Equatable, Identifiable, Sendable {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<RecipeRevision>

    /// This immutable content identity; a new accepted Revision receives a distinct identity.
    public let id: ID
    /// The stable maintained Recipe identity, independent of a particular Revision.
    public let recipeID: Recipe.ID
    /// A person-visible sequence value, never the authority for currentness or causal ancestry.
    public let revisionNumber: Int
    /// The authored Recipe title retained independently of the interface locale.
    public var title: String
    /// Optional authored descriptive text, without inferred cooking results.
    public var summary: String?
    /// Human-readable content attribution, independent of Kitchen ownership.
    public var authorName: String?
    /// The authored content language, or nil when unknown; it is not the interface locale.
    public var contentLanguage: RecipeContentLanguage?
    /// Optional human-readable Recipe provenance, independent of retained import evidence.
    public var source: RecipeSource?
    /// Bounded immutable import evidence, independent of editable attribution.
    public var sourceCapture: RecipeSourceCapture?
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
    /// Authored image references in retained order, with availability independent of content identity.
    public var media: [RecipeMedia]
    /// Authored tool requirements in retained order.
    public var equipment: [EquipmentItem]
    /// Ingredient groups and rows in authored order, preserving optional structure and wording.
    public var ingredientSections: [IngredientSection]
    /// Instruction groups and steps in authored order, independent of cooking progress.
    public var instructionSections: [InstructionSection]

    /// Assembles authored content without accepting a Save or validating authority.
    ///
    /// Repository publication freezes this value as an immutable Revision; mutation
    /// of a local copy does not rewrite accepted history.
    public init(
        id: ID = ID(),
        recipeID: Recipe.ID,
        revisionNumber: Int,
        title: String,
        summary: String? = nil,
        authorName: String? = nil,
        contentLanguage: RecipeContentLanguage? = nil,
        source: RecipeSource? = nil,
        sourceCapture: RecipeSourceCapture? = nil,
        recipeYield: RecipeYield? = nil,
        prepDuration: RecipeDuration? = nil,
        cookDuration: RecipeDuration? = nil,
        totalDuration: RecipeDuration? = nil,
        cuisines: [String] = [],
        categories: [String] = [],
        keywords: [String] = [],
        media: [RecipeMedia] = [],
        equipment: [EquipmentItem] = [],
        ingredientSections: [IngredientSection] = [],
        instructionSections: [InstructionSection] = []
    ) {
        self.id = id
        self.recipeID = recipeID
        self.revisionNumber = revisionNumber
        self.title = title
        self.summary = summary
        self.authorName = authorName
        self.contentLanguage = contentLanguage
        self.source = source
        self.sourceCapture = sourceCapture
        self.recipeYield = recipeYield
        self.prepDuration = prepDuration
        self.cookDuration = cookDuration
        self.totalDuration = totalDuration
        self.cuisines = cuisines
        self.categories = categories
        self.keywords = keywords
        self.media = media
        self.equipment = equipment
        self.ingredientSections = ingredientSections
        self.instructionSections = instructionSections
    }
}
