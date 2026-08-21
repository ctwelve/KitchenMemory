// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import KitchenMemoryPersistence

/// The editable representation of a recipe revision.
///
/// It deliberately carries the recipe's authored structure rather than a
/// flattened transcription. This lets an editor make local corrections without
/// losing section headings, ingredient provenance, or incomplete details.
public struct RecipeDraft: Equatable, Sendable {
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
  public var ingredientSections: [IngredientSection]
  public var instructionSections: [InstructionSection]

  public init(
    title: String = "",
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
    ingredientSections: [IngredientSection] = [],
    instructionSections: [InstructionSection] = []
  ) {
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
    self.ingredientSections = ingredientSections
    self.instructionSections = instructionSections
  }

  /// Convenience for callers that collect a simple, unsectioned recipe.
  public init(
    title: String = "",
    summary: String? = nil,
    ingredientLines: [String],
    instructionLines: [String] = []
  ) {
    self.init(
      title: title,
      summary: summary,
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
      source: revision.source,
      sourceCapture: revision.sourceCapture,
      recipeYield: revision.recipeYield,
      prepDuration: revision.prepDuration,
      cookDuration: revision.cookDuration,
      totalDuration: revision.totalDuration,
      cuisines: revision.cuisines,
      categories: revision.categories,
      keywords: revision.keywords,
      ingredientSections: revision.ingredientSections,
      instructionSections: revision.instructionSections
    )
  }
}

/// Validation failures for the initial text-first editor.
public enum RecipeEditorError: Error, Equatable {
  case missingTitle
  case missingRecipe
}

/// A high-level, main-actor–bound coordinator for creating and revising recipes.
///
/// RecipeEditor encapsulates the domain logic required to transform an editable
/// in-memory draft (RecipeDraft) into an immutable RecipeRevision and persist it
/// alongside its parent Recipe. It ensures that user-entered text is normalized,
/// empty fields are discarded, and section/child identifiers are handled safely
/// across revisions.
///
/// Responsibilities:
/// - Validates essential fields (for example, non-empty title) and surfaces
///   domain-specific validation failures via RecipeEditorError.
/// - Normalizes and cleans draft content by trimming whitespace, removing empty
///   sections/steps/ingredients, and stripping placeholder values.
/// - Creates a new Recipe with its initial revision, or appends a new immutable
///   revision to an existing Recipe while preserving non-authored metadata
///   (e.g., cuisines, categories, keywords, media, equipment).
/// - Prevents identifier collisions across revisions by re-identifying section
///   and child entities when creating subsequent revisions.
///
/// Concurrency:
/// - Constrained to the main actor because it is typically driven by UI flows
///   and interacts with UI-owned state. Persistence calls should be designed to
///   be main-actor–safe by the repository implementation.
///
/// Persistence:
/// - Delegates storage and retrieval to an injected RecipeRepository, allowing
///   the editor to remain platform- and storage-agnostic.
///
/// Typical usage:
/// - Build a RecipeDraft from user input or an existing RecipeRevision.
/// - Call create(in:from:) to persist an entirely new Recipe with its initial
///   revision.
/// - Call revise(recipeID:from:) to append a new revision to an existing Recipe,
///   preserving non-authored metadata and re-identifying section/child content.
///
/// Errors:
/// - Throws RecipeEditorError.missingTitle when the draft lacks a valid title.
/// - Throws RecipeEditorError.missingRecipe when attempting to revise a recipe
///   that cannot be found in the repository.
///
/// Testing considerations:
/// - Provide a test double for RecipeRepository to verify that the editor emits
///   the expected Recipe and RecipeRevision given a draft, including cleanup of
///   whitespace and removal of empty sections/steps/ingredients.
/// - Assert that follow-up revisions preserve non-authored metadata and do not
///   reuse section/child identifiers from previous revisions.
///
/// Dependencies:
/// - KitchenMemoryDomain for Recipe, RecipeRevision, and related value types.
/// - KitchenMemoryPersistence for RecipeRepository and storage operations.
@MainActor
public struct RecipeEditor {
  private let repository: any RecipeRepository

  public init(repository: any RecipeRepository) {
    self.repository = repository
  }

  public func create(in kitchenID: Kitchen.ID, from draft: RecipeDraft) throws -> StoredRecipe {
    let recipeID = Recipe.ID()
    let revision = try revision(recipeID: recipeID, number: 1, from: draft)
    let recipe = Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id)
    try repository.save(recipe: recipe, revision: revision)
    return StoredRecipe(recipe: recipe, revision: revision)
  }

    public func revise(recipeID: Recipe.ID, from draft: RecipeDraft) throws -> StoredRecipe {
    guard let stored = try repository.recipe(id: recipeID) else {
      throw RecipeEditorError.missingRecipe
    }
        let revision = try revision(
          recipeID: recipeID,
          number: stored.revision.revisionNumber + 1,
          from: draft,
          preserving: stored.revision
        )
    var recipe = stored.recipe
    recipe.currentRevisionID = revision.id
    try repository.save(recipe: recipe, revision: revision)
    return StoredRecipe(recipe: recipe, revision: revision)
  }

  private func revision(
    recipeID: Recipe.ID,
    number: Int,
    from draft: RecipeDraft,
    preserving existing: RecipeRevision? = nil
  ) throws -> RecipeRevision {
    let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw RecipeEditorError.missingTitle }
    let summary = draft.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
    let ingredientSections = cleaned(draft.ingredientSections)
    let instructionSections = cleaned(draft.instructionSections)
    return RecipeRevision(
      recipeID: recipeID,
      revisionNumber: number,
      title: title,
      summary: summary?.isEmpty == true ? nil : summary,
      authorName: optional(draft.authorName),
      source: draft.source,
      sourceCapture: draft.sourceCapture ?? existing?.sourceCapture,
      recipeYield: draft.recipeYield,
      prepDuration: draft.prepDuration,
      cookDuration: draft.cookDuration,
      totalDuration: draft.totalDuration,
      cuisines: draft.cuisines,
      categories: draft.categories,
      keywords: draft.keywords,
      media: existing?.media ?? [],
      equipment: existing?.equipment ?? [],
      // Section and child identifiers are local to one immutable revision.
      // Reusing them would make persistence queries for an older section pull
      // in rows from every later revision with the same section identifier.
      ingredientSections: existing == nil ? ingredientSections : reidentified(ingredientSections),
      instructionSections: existing == nil ? instructionSections : reidentified(instructionSections)
    )
  }

  private func text(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func optional(_ text: String?) -> String? {
    text.flatMap(self.text)
  }

  private func cleaned(_ sections: [IngredientSection]) -> [IngredientSection] {
    sections.compactMap { section in
      var section = section
      section.title = optional(section.title)
      section.ingredients = section.ingredients.compactMap { ingredient in
        var ingredient = ingredient
        ingredient.originalText = text(ingredient.originalText) ?? ""
        ingredient.customDisplayText = optional(ingredient.customDisplayText)
        ingredient.ingredientText = optional(ingredient.ingredientText)
        ingredient.quantity = cleaned(ingredient.quantity)
        ingredient.unitText = optional(ingredient.unitText)
        ingredient.package = cleaned(ingredient.package)
        ingredient.preparation = optional(ingredient.preparation)
        ingredient.note = optional(ingredient.note)
        guard ingredient.effectiveDisplayText != "Ingredient" else { return nil }
        return ingredient
      }
      return section.ingredients.isEmpty && section.title == nil ? nil : section
    }
  }

  private func cleaned(_ quantity: QuantityExpression?) -> QuantityExpression? {
    guard var quantity else { return nil }
    quantity.text = optional(quantity.text)

    switch quantity.kind {
    case .none:
      return nil
    case .exact:
      guard let lowerBound = cleaned(quantity.lowerBound) else {
        return textualFallback(for: quantity)
      }
      quantity.lowerBound = lowerBound
      quantity.upperBound = nil
    case .range:
      guard let lowerBound = cleaned(quantity.lowerBound),
        let upperBound = cleaned(quantity.upperBound)
      else {
        return textualFallback(for: quantity)
      }
      quantity.lowerBound = lowerBound
      quantity.upperBound = upperBound
    case .approximate:
      guard let lowerBound = cleaned(quantity.lowerBound) else {
        return textualFallback(for: quantity)
      }
      quantity.lowerBound = lowerBound
      quantity.upperBound = nil
    case .text:
      guard quantity.text != nil else { return nil }
      quantity.lowerBound = nil
      quantity.upperBound = nil
    }

    return quantity
  }

  private func cleaned(_ quantity: RationalQuantity?) -> RationalQuantity? {
    guard let quantity,
      quantity.numerator >= 0,
      quantity.denominator > 0
    else { return nil }
    return quantity
  }

  private func cleaned(_ package: PackageDescription?) -> PackageDescription? {
    guard let package,
      let quantity = cleaned(package.quantity),
      let unit = optional(package.unitText)
    else { return nil }
    return PackageDescription(quantity: quantity, unitText: unit)
  }

  private func textualFallback(for quantity: QuantityExpression) -> QuantityExpression? {
    quantity.text.map { QuantityExpression(kind: .text, text: $0) }
  }

  private func cleaned(_ sections: [InstructionSection]) -> [InstructionSection] {
    sections.compactMap { section in
      var section = section
      section.title = optional(section.title)
      section.steps = section.steps.compactMap { step in
        var step = step
        guard let text = text(step.text) else { return nil }
        step.text = text
        step.name = optional(step.name)
        return step
      }
      return section.steps.isEmpty && section.title == nil ? nil : section
    }
  }

  private func reidentified(_ sections: [IngredientSection]) -> [IngredientSection] {
    sections.map { section in
      IngredientSection(
        title: section.title,
        ingredients: section.ingredients.map { ingredient in
          RecipeIngredient(
            originalText: ingredient.originalText,
            presentationMode: ingredient.presentationMode,
            customDisplayText: ingredient.customDisplayText,
            quantity: ingredient.quantity,
            unitText: ingredient.unitText,
            package: ingredient.package,
            ingredientText: ingredient.ingredientText,
            preparation: ingredient.preparation,
            note: ingredient.note,
            isOptional: ingredient.isOptional,
            scalingBehavior: ingredient.scalingBehavior,
            parseState: ingredient.parseState
          )
        }
      )
    }
  }

  private func reidentified(_ sections: [InstructionSection]) -> [InstructionSection] {
    sections.map { section in
      InstructionSection(
        title: section.title,
        steps: section.steps.map { step in
          InstructionStep(
            name: step.name,
            text: step.text,
            duration: step.duration,
            temperature: step.temperature
          )
        }
      )
    }
  }
}
