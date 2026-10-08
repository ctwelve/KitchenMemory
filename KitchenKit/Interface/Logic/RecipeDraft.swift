// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// The editable representation of a recipe revision.
///
/// It deliberately carries the recipe's authored structure rather than a
/// flattened transcription. This lets an editor make local corrections without
/// losing section headings, ingredient provenance, or incomplete details.
public struct RecipeDraft: Codable, Equatable, Sendable {
  /// Authored title, validated as nonblank when preparing a Save.
  public var title: String
  /// Optional authored description of the dish.
  public var summary: String?
  /// Authored attribution for the person or source responsible for the recipe.
  public var authorName: String?
  /// Authored content language, independent of the interface locale.
  public var contentLanguage: RecipeContentLanguage?
  /// Editable source attribution, separate from retained import evidence.
  public var source: RecipeSource?
  /// Retained source evidence; editing attribution does not rewrite the capture.
  public var sourceCapture: RecipeSourceCapture?
  /// Authored yield and any structured quantity available for scaling.
  public var recipeYield: RecipeYield?
  /// Optional authored preparation duration.
  public var prepDuration: RecipeDuration?
  /// Optional authored cooking duration.
  public var cookDuration: RecipeDuration?
  /// Optional authored total duration; no sum is inferred from other durations.
  public var totalDuration: RecipeDuration?
  /// Source or author supplied cuisine wording, retained without classification inference.
  public var cuisines: [String]
  /// Source or author supplied category wording, distinct from Kitchen Tags.
  public var categories: [String]
  /// Authored keyword wording, distinct from Kitchen Tag assignments.
  public var keywords: [String]
  /// Nil preserves prior media on revision; an explicit empty array removes it.
  public var media: [RecipeMedia]?
  /// Editable equipment; nil preserves prior equipment on revision, while an empty array removes it.
  public var equipment: [EquipmentItem]?
  /// Ordered authored ingredient sections and their structured, potentially incomplete values.
  public var ingredientSections: [IngredientSection]
  /// Ordered authored instruction sections and steps.
  public var instructionSections: [InstructionSection]

  /// Creates an editable value without validation, normalization, or persistence.
  public init(
    title: String = "",
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
    media: [RecipeMedia]? = nil,
    equipment: [EquipmentItem]? = nil,
    ingredientSections: [IngredientSection] = [],
    instructionSections: [InstructionSection] = []
  ) {
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

  /// Convenience for callers that collect a simple, unsectioned recipe.
  public init(
    title: String = "",
    summary: String? = nil,
    contentLanguage: RecipeContentLanguage? = nil,
    ingredientLines: [String],
    instructionLines: [String] = []
  ) {
    self.init(
      title: title,
      summary: summary,
      contentLanguage: contentLanguage,
      ingredientSections: ingredientLines.isEmpty
        ? []
        : [
          IngredientSection(ingredients: ingredientLines.map {
            RecipeIngredient(originalText: $0, presentationMode: .original, parseState: .edited)
          }),
        ],
      instructionSections: instructionLines.isEmpty
        ? []
        : [InstructionSection(steps: instructionLines.map { InstructionStep(text: $0) })]
    )
  }

  /// Copies maintained content into an editable value while retaining its provenance.
  public init(revision: RecipeRevision) {
    self.init(
      title: revision.title,
      summary: revision.summary,
      authorName: revision.authorName,
      contentLanguage: revision.contentLanguage,
      source: revision.source,
      sourceCapture: revision.sourceCapture,
      recipeYield: revision.recipeYield,
      prepDuration: revision.prepDuration,
      cookDuration: revision.cookDuration,
      totalDuration: revision.totalDuration,
      cuisines: revision.cuisines,
      categories: revision.categories,
      keywords: revision.keywords,
      media: revision.media,
      equipment: revision.equipment,
      ingredientSections: revision.ingredientSections,
      instructionSections: revision.instructionSections
    )
  }
}
