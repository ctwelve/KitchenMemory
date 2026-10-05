// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Identifies the duration input requiring correction before a Recipe Save.
public enum RecipeEditDurationField: CaseIterable, Equatable, Hashable, Sendable {
  /// The preparation-duration input in whole minutes.
  case preparation
  /// The cooking-duration input in whole minutes.
  case cooking
  /// The independently authored total-duration input in whole minutes.
  case total
}

/// A form validation problem; sparse ingredients or instructions remain valid authored content.
public enum RecipeEditValidationIssue: Equatable, Hashable, Sendable {
  /// The title is empty after trimming whitespace and newlines.
  case missingTitle
  /// A duration is not a whole number in the supported minute range.
  case invalidDuration(RecipeEditDurationField)
  /// A nonblank source URL does not satisfy the link activation policy.
  case invalidSourceURL
}

/// Failures when extracting a publishable draft from editable input.
public enum RecipeEditSessionError: Error, Equatable, Sendable {
  /// The complete set of form issues that prevents draft extraction.
  case invalid(Set<RecipeEditValidationIssue>)
}

/// UI-independent state for editing a recipe.
///
/// Clients may edit non-ingredient fields on a copy and submit them through
/// `RecipeEditingDraft.updateRecipeDetails(from:)`. Ingredient state is externally
/// read-only and is maintained by the live draft's explicit operations.
public struct RecipeEditSession: Codable, Equatable, Sendable {
  /// Largest accepted whole-minute duration, equivalent to 366 days.
  public static let maximumDurationMinutes = 366 * 24 * 60

  /// Editable title input; a nonblank value is required for Save.
  public var title: String
  /// Editable summary input; publication normalizes blank optional text.
  public var summary: String
  /// Editable author attribution input.
  public var authorName: String
  /// Editable yield, retaining authored wording and optional structured quantity.
  public var recipeYield: RecipeYield?
  /// Preparation duration input in whole minutes; blank means unspecified.
  public var prepMinutes: String
  /// Cooking duration input in whole minutes; blank means unspecified.
  public var cookMinutes: String
  /// Independent total duration input in whole minutes; blank means unspecified.
  public var totalMinutes: String
  /// Source attribution kind retained when creating the resulting source value.
  public var sourceKind: RecipeSource.Kind
  /// Editable source title input.
  public var sourceTitle: String
  /// Editable source-author attribution input.
  public var sourceAuthor: String
  /// Editable publisher attribution input.
  public var sourcePublisher: String
  /// Editable absolute HTTP or HTTPS source URL; blank means no link.
  public var sourceURL: String
  /// Editable media; nil permits legacy preservation when revising.
  public var media: [RecipeMedia]?
  /// Editable equipment; nil permits legacy preservation when revising.
  public var equipment: [EquipmentItem]?
  /// Read-only ingredient contents; mutate the live draft through its ingredient operations.
  public internal(set) var ingredientSections: [IngredientSection]
  /// Ordered instructions editable on a session copy before submitting recipe details.
  public var instructionSections: [InstructionSection]
  /// Recoverable simple-editor state; absent in drafts created before this editor existed.
  public internal(set) var ingredientText: RecipeIngredientTextDraft?

  private let preservedSourceCapture: RecipeSourceCapture?
  private let preservedContentLanguage: RecipeContentLanguage?
  private let preservedCuisines: [String]
  private let preservedCategories: [String]
  private let preservedKeywords: [String]

  /// Creates form inputs from a draft, retaining captured metadata and classification separately.
  public init(draft: RecipeDraft = RecipeDraft()) {
    title = draft.title
    summary = draft.summary ?? ""
    authorName = draft.authorName ?? ""
    recipeYield = draft.recipeYield
    prepMinutes = Self.minutes(draft.prepDuration)
    cookMinutes = Self.minutes(draft.cookDuration)
    totalMinutes = Self.minutes(draft.totalDuration)
    sourceKind = draft.source?.kind ?? .original
    sourceTitle = draft.source?.title ?? ""
    sourceAuthor = draft.source?.authorName ?? ""
    sourcePublisher = draft.source?.publisherName ?? ""
    sourceURL = draft.source?.canonicalURL?.absoluteString ?? ""
    media = draft.media
    equipment = draft.equipment
    ingredientSections = draft.ingredientSections
    instructionSections = draft.instructionSections
    preservedSourceCapture = draft.sourceCapture
    preservedContentLanguage = draft.contentLanguage
    preservedCuisines = draft.cuisines
    preservedCategories = draft.categories
    preservedKeywords = draft.keywords
  }

  /// All current title, duration, and source-link issues, without changing the input.
  public var validationIssues: Set<RecipeEditValidationIssue> {
    var issues: Set<RecipeEditValidationIssue> = []
    if text(title) == nil { issues.insert(.missingTitle) }
    if !isValidDuration(prepMinutes) { issues.insert(.invalidDuration(.preparation)) }
    if !isValidDuration(cookMinutes) { issues.insert(.invalidDuration(.cooking)) }
    if !isValidDuration(totalMinutes) { issues.insert(.invalidDuration(.total)) }
    if text(sourceURL) != nil, RecipeSourceURLPolicy.validatedURL(from: sourceURL) == nil {
      issues.insert(.invalidSourceURL)
    }
    return issues
  }

  /// Whether the current form inputs pass validation; this does not prove storage availability.
  public var canSave: Bool { validationIssues.isEmpty }

  /// Extracts a validated draft, completing pending ingredient interpretation on a copy.
  ///
  /// Throws ``RecipeEditSessionError/invalid(_:)`` with every detected form issue.
  /// The live editing session and its native history are unchanged.
  public func validatedDraft() throws -> RecipeDraft {
    let issues = validationIssues
    guard issues.isEmpty else { throw RecipeEditSessionError.invalid(issues) }
    return RecipeDraft(
      title: title,
      summary: summary,
      authorName: authorName,
      contentLanguage: preservedContentLanguage,
      source: source,
      sourceCapture: preservedSourceCapture,
      recipeYield: cleanedRecipeYield,
      prepDuration: duration(prepMinutes),
      cookDuration: duration(cookMinutes),
      totalDuration: duration(totalMinutes),
      cuisines: preservedCuisines,
      categories: preservedCategories,
      keywords: preservedKeywords,
      media: media,
      equipment: equipment,
      ingredientSections: finishedIngredientSections,
      instructionSections: instructionSections
    )
  }

  private var completedIngredientText: RecipeIngredientTextDraft? {
    var text = ingredientText
    if let current = text, current.sections != ingredientSections {
      text = current.incorporating(ingredientSections)
    }
    text?.finishEditing()
    return text
  }

  private var finishedIngredientSections: [IngredientSection] {
    completedIngredientText?.sections ?? ingredientSections
  }

  mutating func moveIngredientSection(at index: Int, by offset: Int) {
    moveElement(in: &ingredientSections, at: index, by: offset)
  }

  /// Swaps equipment with the row at the requested offset; absent equipment or invalid indices do nothing.
  public mutating func moveEquipment(at index: Int, by offset: Int) {
    guard var items = equipment else { return }
    moveElement(in: &items, at: index, by: offset)
    equipment = items
  }

  /// Swaps instruction sections at the requested offset; invalid source or destination indices do nothing.
  public mutating func moveInstructionSection(at index: Int, by offset: Int) {
    moveElement(in: &instructionSections, at: index, by: offset)
  }

  private var cleanedRecipeYield: RecipeYield? {
    guard var recipeYield else { return nil }
    recipeYield.unitText = recipeYield.unitText.flatMap(text)
    if let originalText = text(recipeYield.originalText) {
      recipeYield.originalText = originalText
    } else if recipeYield.quantity != nil {
      recipeYield.originalText = ""
    } else {
      return nil
    }
    return recipeYield
  }

  private var source: RecipeSource? {
    let canonicalURL = RecipeSourceURLPolicy.validatedURL(from: sourceURL)
    guard text(sourceTitle) != nil || text(sourceAuthor) != nil
      || text(sourcePublisher) != nil || canonicalURL != nil
    else { return nil }
    return RecipeSource(
      kind: sourceKind,
      title: text(sourceTitle),
      authorName: text(sourceAuthor),
      publisherName: text(sourcePublisher),
      canonicalURL: canonicalURL
    )
  }

  private func duration(_ input: String) -> RecipeDuration? {
    guard let value = text(input).flatMap(Int.init) else { return nil }
    return RecipeDuration(seconds: value * 60)
  }

  private func isValidDuration(_ input: String) -> Bool {
    guard let trimmed = text(input) else { return true }
    guard let value = Int(trimmed) else { return false }
    return (0...Self.maximumDurationMinutes).contains(value)
  }

  private func text(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func minutes(_ duration: RecipeDuration?) -> String {
    duration.map { String($0.seconds / 60) } ?? ""
  }

  private func moveElement<Element>(in values: inout [Element], at index: Int, by offset: Int) {
    let destination = index + offset
    guard values.indices.contains(index), values.indices.contains(destination) else { return }
    values.swapAt(index, destination)
  }
}
