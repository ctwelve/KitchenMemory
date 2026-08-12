// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

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
  public var recipeYield: RecipeYield?
  public var prepDuration: RecipeDuration?
  public var cookDuration: RecipeDuration?
  public var totalDuration: RecipeDuration?
  public var ingredientSections: [IngredientSection]
  public var instructionSections: [InstructionSection]

  public init(
    title: String = "",
    summary: String? = nil,
    authorName: String? = nil,
    source: RecipeSource? = nil,
    recipeYield: RecipeYield? = nil,
    prepDuration: RecipeDuration? = nil,
    cookDuration: RecipeDuration? = nil,
    totalDuration: RecipeDuration? = nil,
    ingredientSections: [IngredientSection] = [],
    instructionSections: [InstructionSection] = []
  ) {
    self.title = title
    self.summary = summary
    self.authorName = authorName
    self.source = source
    self.recipeYield = recipeYield
    self.prepDuration = prepDuration
    self.cookDuration = cookDuration
    self.totalDuration = totalDuration
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
      ingredientSections: ingredientLines.isEmpty ? [] : [IngredientSection(ingredients: ingredientLines.map {
        RecipeIngredient(originalText: $0, presentationMode: .original, parseState: .edited)
      })],
      instructionSections: instructionLines.isEmpty ? [] : [InstructionSection(steps: instructionLines.map { InstructionStep(text: $0) })]
    )
  }

  public init(revision: RecipeRevision) {
    self.init(
      title: revision.title,
      summary: revision.summary,
      authorName: revision.authorName,
      source: revision.source,
      recipeYield: revision.recipeYield,
      prepDuration: revision.prepDuration,
      cookDuration: revision.cookDuration,
      totalDuration: revision.totalDuration,
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

/// Write operations for manually created and edited recipes.
///
/// Saving an edit never changes an existing ``RecipeRevision``. It writes a
/// new revision, makes that revision current, and leaves previous content for
/// recipe history and later comparison.
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
      recipeYield: draft.recipeYield,
      prepDuration: draft.prepDuration,
      cookDuration: draft.cookDuration,
      totalDuration: draft.totalDuration,
      cuisines: existing?.cuisines ?? [],
      categories: existing?.categories ?? [],
      keywords: existing?.keywords ?? [],
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
        ingredient.unitText = optional(ingredient.unitText)
        ingredient.preparation = optional(ingredient.preparation)
        ingredient.note = optional(ingredient.note)
        guard ingredient.effectiveDisplayText != "Ingredient" else { return nil }
        return ingredient
      }
      return section.ingredients.isEmpty && section.title == nil ? nil : section
    }
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
