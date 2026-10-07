// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

// UI-independent recipe editing belongs to KitchenKit's Logic responsibility so every
// presentation and automation surface creates the same immutable revisions.

import Foundation

/// Validation failures for the initial text-first editor.
public enum RecipeEditorError: Error, Equatable {
  /// The draft title is blank after trimming whitespace and newlines.
  case missingTitle
  /// The Recipe to revise cannot be read as current maintained content.
  case missingRecipe
}

/// Prepares immutable Recipe revisions and accepts explicit Saves through a repository.
///
/// Ordinary saves trim optional text and remove empty content while retaining
/// structured uncertainty. Each revised section, ingredient, step, and equipment
/// row receives a revision-local identity; media references retain their identity.
/// Nil media or equipment in legacy drafts preserves the prior collection.
/// Reconciliation preserves untouched authored values rather than normalizing them.
///
/// The main actor follows the repository's actor-bound persistence contract.
/// A prepared command writes nothing: callers needing recoverable publication
/// retain it locally before acceptance and retry that identical command.
@MainActor
public struct RecipeEditor {
  private let repository: any RecipeRepository

  /// Binds revision preparation and acceptance to a main-actor Recipe repository.
  public init(repository: any RecipeRepository) {
    self.repository = repository
  }

  /// Prepares and accepts a new Recipe with a zero-parent revision and initial Selection.
  /// Throws title validation or repository errors; every invocation creates a new command.
  public func create(in kitchenID: Kitchen.ID, from draft: RecipeDraft) throws -> StoredRecipe {
    let command = try prepareSave(in: kitchenID, from: draft, original: nil, observedSelectionIDs: [])
    try repository.save(command)
    return StoredRecipe(recipe: command.recipe, revision: command.revision)
  }

  /// Reads the current Recipe and Selection frontier, then accepts a new child revision.
  /// Throws for missing Recipe, invalid title, or repository failure. Use a retained
  /// prepared Save when the operation must survive an uncertain acceptance or relaunch.
  public func revise(recipeID: Recipe.ID, from draft: RecipeDraft) throws -> StoredRecipe {
    guard let stored = try repository.recipe(id: recipeID) else {
      throw RecipeEditorError.missingRecipe
    }
    let command = try prepareSave(
      in: stored.recipe.kitchenID, from: draft, original: stored,
      observedSelectionIDs: repository.selectionHeads(for: recipeID)
    )
    try repository.save(command)
    return StoredRecipe(recipe: command.recipe, revision: command.revision)
  }

  /// Freezes an explicit save for durable retry, using the draft's observed base.
  public func prepareSave(
    in kitchenID: Kitchen.ID,
    from draft: RecipeDraft,
    original: StoredRecipe?,
    observedSelectionIDs: [RecipeSelectionCommand.ID]
  ) throws -> RecipeSaveCommand {
    let recipeID = original?.id ?? Recipe.ID()
    let revision = try revision(
      recipeID: recipeID, number: (original?.revision.revisionNumber ?? 0) + 1,
      from: draft, preserving: original?.revision
    )
    let recipe = Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id)
    let now = Date()
    return RecipeSaveCommand(
      recipe: recipe, revision: revision, savedAt: now,
      parentRevisionIDs: original.map { [$0.revision.id] } ?? [],
      selection: RecipeSelectionCommand(
        kitchenID: kitchenID, recipeID: recipeID, selectedRevisionID: revision.id,
        selectedAt: now, observedSelectionIDs: observedSelectionIDs
      )
    )
  }

  /// Reconciliation preserves authored values and names every compared parent.
  public func prepareReconciliationSave(
    _ comparison: RecipeReconciliation, session: RecipeEditSession
  ) throws -> RecipeSaveCommand {
    _ = try RecipeReconciliation(
      kitchenID: comparison.kitchenID, revisions: comparison.revisions,
      observedSelectionIDs: comparison.observedSelectionIDs
    )
    guard let original = comparison.revisions.first,
          let maximum = comparison.revisions.map(\.revisionNumber).max(), maximum < Int.max
    else { throw RecipeReconciliationError.invalidParents }
    let revision = try revision(
      recipeID: original.recipeID, number: maximum + 1,
      from: comparison.editedDraft(from: session), preserving: original, preserveAuthoredValues: true
    )
    let recipe = Recipe(id: original.recipeID, kitchenID: comparison.kitchenID, currentRevisionID: revision.id)
    let now = Date()
    return RecipeSaveCommand(
      recipe: recipe, revision: revision, savedAt: now, parentRevisionIDs: comparison.parentRevisionIDs,
      selection: RecipeSelectionCommand(
        kitchenID: recipe.kitchenID, recipeID: recipe.id, selectedRevisionID: revision.id,
        selectedAt: now, observedSelectionIDs: comparison.observedSelectionIDs
      )
    )
  }

  private func revision(
    recipeID: Recipe.ID,
    number: Int,
    from draft: RecipeDraft,
    preserving existing: RecipeRevision? = nil,
    preserveAuthoredValues: Bool = false
  ) throws -> RecipeRevision {
    let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw RecipeEditorError.missingTitle }
    let summary = draft.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
    let ingredientSections = preserveAuthoredValues ? draft.ingredientSections : cleaned(draft.ingredientSections)
    let instructionSections = preserveAuthoredValues ? draft.instructionSections : cleaned(draft.instructionSections)
    return RecipeRevision(
      recipeID: recipeID,
      revisionNumber: number,
      title: preserveAuthoredValues ? draft.title : title,
      summary: preserveAuthoredValues ? draft.summary : (summary?.isEmpty == true ? nil : summary),
      authorName: preserveAuthoredValues ? draft.authorName : optional(draft.authorName),
      contentLanguage: draft.contentLanguage,
      source: draft.source,
      sourceCapture: preserveAuthoredValues ? draft.sourceCapture : (draft.sourceCapture ?? existing?.sourceCapture),
      recipeYield: draft.recipeYield,
      prepDuration: draft.prepDuration,
      cookDuration: draft.cookDuration,
      totalDuration: draft.totalDuration,
      cuisines: draft.cuisines,
      categories: draft.categories,
      keywords: draft.keywords,
      media: draft.media ?? existing?.media ?? [],
      equipment: preserveAuthoredValues ? reidentifiedEquipment(draft.equipment ?? [])
        : cleaned(draft.equipment ?? existing?.equipment ?? [], reidentify: existing != nil),
      // Section and child identifiers are local to one immutable revision.
      // Reusing them would make persistence queries for an older section pull
      // in rows from every later revision with the same section identifier.
      ingredientSections: existing == nil ? ingredientSections : reidentified(ingredientSections),
      instructionSections: existing == nil ? instructionSections : reidentified(instructionSections)
    )
  }

  private func reidentifiedEquipment(_ equipment: [EquipmentItem]) -> [EquipmentItem] {
    equipment.map {
      EquipmentItem(originalText: $0.originalText, quantity: $0.quantity, name: $0.name, isOptional: $0.isOptional)
    }
  }

  private func text(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func cleaned(_ items: [EquipmentItem], reidentify: Bool) -> [EquipmentItem] {
    items.compactMap { item in
      let original = text(item.originalText) ?? ""
      let name = text(item.name) ?? ""
      let quantity = cleaned(item.quantity)
      guard !original.isEmpty || !name.isEmpty || quantity != nil else { return nil }
      return EquipmentItem(
        id: reidentify ? EquipmentItem.ID() : item.id,
        originalText: original, quantity: quantity, name: name, isOptional: item.isOptional
      )
    }
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
        guard ingredient.hasMeaningfulDisplayContent else { return nil }
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

extension RecipeEditor {
  func copyForRecovery(_ revision: RecipeRevision) -> RecipeDraft {
    var draft = RecipeDraft(revision: revision)
    draft.ingredientSections = reidentified(revision.ingredientSections)
    draft.instructionSections = reidentified(revision.instructionSections)
    draft.equipment = reidentifiedEquipment(revision.equipment)
    return draft
  }
}
