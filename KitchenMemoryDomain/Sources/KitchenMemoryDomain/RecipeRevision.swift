// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

/// One intentional representation of a recipe at a point in its history.
public struct RecipeRevision: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<RecipeRevision>

    public let id: ID
    public let recipeID: Recipe.ID
    public let revisionNumber: Int
    public var title: String
    public var summary: String?
    public var authorName: String?
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
