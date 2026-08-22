// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain

public enum RecipeEditDurationField: CaseIterable, Equatable, Hashable, Sendable {
  case preparation
  case cooking
  case total
}

public enum RecipeEditValidationIssue: Equatable, Hashable, Sendable {
  case missingTitle
  case invalidDuration(RecipeEditDurationField)
  case invalidSourceURL
}

public enum RecipeEditSessionError: Error, Equatable, Sendable {
  case invalid(Set<RecipeEditValidationIssue>)
}

/// UI-independent state for editing a recipe.
///
/// The current sheet and a future in-page editor can bind to the same value
/// without making SwiftUI responsible for validation or lossless draft assembly.
public struct RecipeEditSession: Equatable, Sendable {
  public static let maximumDurationMinutes = 366 * 24 * 60

  public var title: String
  public var summary: String
  public var authorName: String
  public var recipeYield: RecipeYield?
  public var prepMinutes: String
  public var cookMinutes: String
  public var totalMinutes: String
  public var sourceKind: RecipeSource.Kind
  public var sourceTitle: String
  public var sourceAuthor: String
  public var sourcePublisher: String
  public var sourceURL: String
  public var ingredientSections: [IngredientSection]
  public var instructionSections: [InstructionSection]

  private let preservedSourceCapture: RecipeSourceCapture?
  private let preservedCuisines: [String]
  private let preservedCategories: [String]
  private let preservedKeywords: [String]

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
    ingredientSections = draft.ingredientSections
    instructionSections = draft.instructionSections
    preservedSourceCapture = draft.sourceCapture
    preservedCuisines = draft.cuisines
    preservedCategories = draft.categories
    preservedKeywords = draft.keywords
  }

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

  public var canSave: Bool { validationIssues.isEmpty }

  public func validatedDraft() throws -> RecipeDraft {
    let issues = validationIssues
    guard issues.isEmpty else { throw RecipeEditSessionError.invalid(issues) }
    return RecipeDraft(
      title: title,
      summary: summary,
      authorName: authorName,
      source: source,
      sourceCapture: preservedSourceCapture,
      recipeYield: cleanedRecipeYield,
      prepDuration: duration(prepMinutes),
      cookDuration: duration(cookMinutes),
      totalDuration: duration(totalMinutes),
      cuisines: preservedCuisines,
      categories: preservedCategories,
      keywords: preservedKeywords,
      ingredientSections: ingredientSections,
      instructionSections: instructionSections
    )
  }

  public mutating func moveIngredientSection(at index: Int, by offset: Int) {
    moveElement(in: &ingredientSections, at: index, by: offset)
  }

  public mutating func moveInstructionSection(at index: Int, by offset: Int) {
    moveElement(in: &instructionSections, at: index, by: offset)
  }

  private var cleanedRecipeYield: RecipeYield? {
    guard var recipeYield else { return nil }
    recipeYield.unitText = recipeYield.unitText.flatMap(text)
    if let originalText = text(recipeYield.originalText) {
      recipeYield.originalText = originalText
    } else if let quantityText = recipeYield.quantity?.renderedText {
      recipeYield.originalText = [quantityText, recipeYield.unitText]
        .compactMap { $0 }
        .joined(separator: " ")
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
