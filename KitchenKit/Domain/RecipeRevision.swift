// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// A canonical BCP 47 tag describing a recipe revision's authored language.
public struct RecipeContentLanguage: Codable, Equatable, Hashable, RawRepresentable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let canonical = Locale(identifier: trimmed).identifier(.bcp47)
        guard canonical != "und" else { return nil }
        self.rawValue = canonical
    }

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

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// One intentional representation of a recipe at a point in its history.
public struct RecipeRevision: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<RecipeRevision>

    public let id: ID
    public let recipeID: Recipe.ID
    public let revisionNumber: Int
    public var title: String
    public var summary: String?
    public var authorName: String?
    public var contentLanguage: RecipeContentLanguage?
    public var source: RecipeSource?
    public var sourceCapture: RecipeSourceCapture?
    public var recipeYield: RecipeYield?
    public var prepDuration: RecipeDuration?
    public var cookDuration: RecipeDuration?
    public var totalDuration: RecipeDuration?
    public var cuisines: [String]
    public var categories: [String]
    public var keywords: [String]
    public var media: [RecipeMedia]
    public var equipment: [EquipmentItem]
    public var ingredientSections: [IngredientSection]
    public var instructionSections: [InstructionSection]

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
