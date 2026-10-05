// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// An authored content field that can be compared and copied independently during reconciliation.
public enum RecipeComparisonField: String, Codable, CaseIterable, Identifiable, Sendable {
  /// Title, summary, attribution, language, source evidence, and authored yield choices.
  case title, summary, author, language, source, yield
  /// Independent durations and source-provided taxonomy choices.
  case preparation, cooking, total, cuisines, categories, keywords
  /// Complete ordered content collections; selecting ingredients replaces that collection.
  case ingredients, instructions, equipment, media
  /// Stable field name suitable for presenting comparison choices.
  public var id: String { rawValue }

  // Each supported field has one explicit, lossless copy operation.
  // swiftlint:disable:next cyclomatic_complexity
  func copy(from source: RecipeDraft, to result: inout RecipeDraft) {
    switch self {
    case .title: result.title = source.title
    case .summary: result.summary = source.summary
    case .author: result.authorName = source.authorName
    case .language: result.contentLanguage = source.contentLanguage
    case .source:
      result.source = source.source
      result.sourceCapture = source.sourceCapture
    case .yield: result.recipeYield = source.recipeYield
    case .preparation: result.prepDuration = source.prepDuration
    case .cooking: result.cookDuration = source.cookDuration
    case .total: result.totalDuration = source.totalDuration
    case .cuisines: result.cuisines = source.cuisines
    case .categories: result.categories = source.categories
    case .keywords: result.keywords = source.keywords
    case .ingredients: result.ingredientSections = source.ingredientSections
    case .instructions: result.instructionSections = source.instructionSections
    case .equipment: result.equipment = source.equipment
    case .media: result.media = source.media
    }
  }
}

/// Failures in forming or editing an explicit local revision comparison.
public enum RecipeReconciliationError: Error, Equatable {
  /// The comparison lacks distinct revisions of one Recipe, or cannot supply valid reconciliation parents.
  case invalidParents
  /// No starting revision has yet been selected for the local draft.
  case missingChoice
  /// The requested revision, row, or editing state is not a valid comparison choice.
  case invalidChoice
  /// An ordinary draft already owns this Recipe and must be finished or discarded first.
  case existingDraft
}

/// A recoverable local comparison. Choosing content never creates shared authority.
public struct RecipeReconciliation: Codable, Equatable, Sendable {
  /// Kitchen scope used to validate publication of the reconciliation.
  public let kitchenID: Kitchen.ID
  /// Stable Recipe shared by every compared revision.
  public let recipeID: Recipe.ID
  /// Distinct revisions offered for explicit authored-content choices.
  public let revisions: [RecipeRevision]
  /// Selection frontier observed by the comparison; later unseen choices remain concurrent.
  public let observedSelectionIDs: [RecipeSelectionCommand.ID]
  /// Chosen local content, or nil until a starting revision is selected.
  public private(set) var draft: RecipeDraft?
  /// Every compared revision identity to name as a parent in a reconciliation Save.
  public var parentRevisionIDs: [RecipeRevision.ID] { revisions.map(\.id) }

  /// Creates a comparison of at least two distinct revisions belonging to one Recipe.
  /// Throws ``RecipeReconciliationError/invalidParents`` for an invalid parent collection;
  /// no revision is selected and no shared authority is written.
  public init(
    kitchenID: Kitchen.ID, revisions: [RecipeRevision], observedSelectionIDs: [RecipeSelectionCommand.ID]
  ) throws {
    guard let first = revisions.first, revisions.count >= 2, Set(revisions.map(\.id)).count == revisions.count,
          Set(revisions.map(\.recipeID)).count == 1 else { throw RecipeReconciliationError.invalidParents }
    self.kitchenID = kitchenID
    recipeID = first.recipeID
    self.revisions = revisions
    self.observedSelectionIDs = observedSelectionIDs
  }

  /// Starts or replaces local content from one compared revision; an unknown revision throws.
  public mutating func chooseRevision(_ id: RecipeRevision.ID) throws {
    draft = RecipeDraft(revision: try revision(id))
  }

  /// Copies one authored field from a compared revision into the selected draft.
  /// Throws before a starting choice or when the revision is not a comparison candidate.
  public mutating func choose(_ field: RecipeComparisonField, from id: RecipeRevision.ID) throws {
    guard var draft else { throw RecipeReconciliationError.missingChoice }
    field.copy(from: RecipeDraft(revision: try revision(id)), to: &draft)
    self.draft = draft
  }

  /// Explicitly replaces a selected row or appends the chosen row to a section.
  public mutating func chooseIngredient(
    from id: RecipeRevision.ID, section: Int, ingredient: Int,
    targetSection: Int, replacing targetIngredient: Int? = nil
  ) throws {
    guard var draft else { throw RecipeReconciliationError.missingChoice }
    let source = try revision(id)
    guard source.ingredientSections.indices.contains(section),
          source.ingredientSections[section].ingredients.indices.contains(ingredient),
          draft.ingredientSections.indices.contains(targetSection)
    else { throw RecipeReconciliationError.invalidChoice }
    let sourceItem = source.ingredientSections[section].ingredients[ingredient]
    let item = RecipeIngredient(
      originalText: sourceItem.originalText, presentationMode: sourceItem.presentationMode,
      customDisplayText: sourceItem.customDisplayText, quantity: sourceItem.quantity,
      unitText: sourceItem.unitText, package: sourceItem.package, ingredientText: sourceItem.ingredientText,
      preparation: sourceItem.preparation, note: sourceItem.note, isOptional: sourceItem.isOptional,
      scalingBehavior: sourceItem.scalingBehavior, parseState: sourceItem.parseState
    )
    if let targetIngredient {
      guard draft.ingredientSections[targetSection].ingredients.indices.contains(targetIngredient)
      else { throw RecipeReconciliationError.invalidChoice }
      draft.ingredientSections[targetSection].ingredients[targetIngredient] = item
    } else {
      draft.ingredientSections[targetSection].ingredients.append(item)
    }
    self.draft = draft
  }

  /// Returns authored fields that differ, ignoring revision-local row identities and image-byte availability.
  /// Throws for unknown revisions or encoding failures; collection order remains meaningful.
  public func differences(between first: RecipeRevision.ID, and second: RecipeRevision.ID) throws
    -> [RecipeComparisonField] {
    try Self.differences(RecipeDraft(revision: revision(first)), RecipeDraft(revision: revision(second)))
  }

  /// Editor round-trip conversions do not count as deliberate changes.
  public func editedDraft(from session: RecipeEditSession) throws -> RecipeDraft {
    guard var result = draft else { throw RecipeReconciliationError.missingChoice }
    let original = RecipeEditSession(draft: result)
    let baseline = try original.validatedDraft()
    var edited = try session.validatedDraft()
    edited.recipeYield = session.recipeYield
    if var source = edited.source {
      if session.sourceTitle == original.sourceTitle { source.title = result.source?.title }
      if session.sourceAuthor == original.sourceAuthor { source.authorName = result.source?.authorName }
      if session.sourcePublisher == original.sourcePublisher { source.publisherName = result.source?.publisherName }
      edited.source = source
    }
    for field in try Self.differences(baseline, edited) { field.copy(from: edited, to: &result) }
    return result
  }

  /// Retains deliberate changes from validated editor inputs without normalizing untouched authored values.
  public mutating func retainEdits(from session: RecipeEditSession) throws {
    draft = try editedDraft(from: session)
  }

  /// Live reconciliation retains unfinished text and editing identities until publication.
  mutating func retainEditingContents(from session: RecipeEditSession) throws {
    try retainEdits(from: session)
    draft?.ingredientSections = session.ingredientSections
  }

  private func revision(_ id: RecipeRevision.ID) throws -> RecipeRevision {
    guard let value = revisions.first(where: { $0.id == id }) else {
      throw RecipeReconciliationError.invalidChoice
    }
    return value
  }

  private static func differences(_ first: RecipeDraft, _ second: RecipeDraft) throws -> [RecipeComparisonField] {
    let baseline = try semanticData(first)
    return try RecipeComparisonField.allCases.filter { field in
      var candidate = first
      field.copy(from: second, to: &candidate)
      return try semanticData(candidate) != baseline
    }
  }

  // Revision-local row identities are not authored differences. Media identities
  // are retained references, while image delivery availability is not authority.
  private static func semanticData(_ draft: RecipeDraft) throws -> Data {
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft))
    return try JSONSerialization.data(withJSONObject: normalized(object), options: [.sortedKeys])
  }

  private static func normalized(_ value: Any, media: Bool = false) -> Any {
    if let object = value as? [String: Any] {
      return object.reduce(into: [String: Any]()) { result, pair in
        guard pair.key != "imageData", pair.key != "id" || media else { return }
        result[pair.key] = normalized(pair.value, media: media || pair.key == "media")
      }
    }
    if let array = value as? [Any] { return array.map { normalized($0, media: media) } }
    return value
  }
}
