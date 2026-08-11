// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryPersistence

/// The small, intentionally text-first surface of the first recipe editor.
public struct RecipeDraft: Equatable, Sendable {
  public var title: String
  public var summary: String?
  public var ingredientLines: [String]
  public var instructionLines: [String]

  public init(
    title: String = "",
    summary: String? = nil,
    ingredientLines: [String] = [],
    instructionLines: [String] = []
  ) {
    self.title = title
    self.summary = summary
    self.ingredientLines = ingredientLines
    self.instructionLines = instructionLines
  }

  public init(revision: RecipeRevision) {
    self.init(
      title: revision.title,
      summary: revision.summary,
      ingredientLines: revision.ingredientSections.flatMap(\.ingredients).map(\.originalText),
      instructionLines: revision.instructionSections.flatMap(\.steps).map(\.text)
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
    let ingredientLines = draft.ingredientLines.compactMap(text)
    let instructionLines = draft.instructionLines.compactMap(text)
    let ingredients = ingredientLines.map {
      RecipeIngredient(
        originalText: $0,
        displayText: $0,
        parseState: .edited
      )
    }
    let steps = instructionLines.map { InstructionStep(text: $0) }

    let originalIngredientLines = existing?.ingredientSections.flatMap(\.ingredients).map(\.originalText)
    let originalInstructionLines = existing?.instructionSections.flatMap(\.steps).map(\.text)
    let ingredientSections = ingredientLines == originalIngredientLines
      ? existing?.ingredientSections ?? []
      : ingredients.isEmpty ? [] : [IngredientSection(ingredients: ingredients)]
    let instructionSections = instructionLines == originalInstructionLines
      ? existing?.instructionSections ?? []
      : steps.isEmpty ? [] : [InstructionSection(steps: steps)]

    return RecipeRevision(
      recipeID: recipeID,
      revisionNumber: number,
      title: title,
      summary: summary?.isEmpty == true ? nil : summary,
      authorName: existing?.authorName,
      source: existing?.source,
      recipeYield: existing?.recipeYield,
      prepDuration: existing?.prepDuration,
      cookDuration: existing?.cookDuration,
      totalDuration: existing?.totalDuration,
      cuisines: existing?.cuisines ?? [],
      categories: existing?.categories ?? [],
      keywords: existing?.keywords ?? [],
      media: existing?.media ?? [],
      equipment: existing?.equipment ?? [],
      ingredientSections: ingredientSections,
      instructionSections: instructionSections
    )
  }

  private func text(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
