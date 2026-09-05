// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// The editable representation of a recipe revision.
///
/// It deliberately carries the recipe's authored structure rather than a
/// flattened transcription. This lets an editor make local corrections without
/// losing section headings, ingredient provenance, or incomplete details.
public struct RecipeDraft: Codable, Equatable, Sendable {
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
  /// Nil preserves Equipment for legacy callers; an explicit empty array removes it.
  public var equipment: [EquipmentItem]?
  public var ingredientSections: [IngredientSection]
  public var instructionSections: [InstructionSection]

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
      equipment: revision.equipment,
      ingredientSections: revision.ingredientSections,
      instructionSections: revision.instructionSections
    )
  }
}
