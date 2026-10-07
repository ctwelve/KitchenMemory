// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

// Import interpretation is product logic; networking and JSON-LD discovery
// remain behind KitchenKit's Import responsibility.

import Foundation

/// A review concern discovered while translating imported content into a draft.
///
/// Concerns preserve uncertainty for presentation; they are not silent repairs
/// and do not authorize saving an import into the library.
public enum RecipeImportConcern: Codable, Equatable, Sendable {
  /// No nonblank title was provided by the imported candidate.
  case missingTitle
  /// The imported candidate has no ingredient rows.
  case missingIngredients
  /// The imported candidate has no instruction steps.
  case missingInstructions
  /// Ingredient wording could not be interpreted into structured fields.
  case unparsedIngredients(count: Int)
  /// Machine-parsed ingredient fields still require human review.
  case provisionalIngredients(count: Int)
  /// Malformed or unsupported source blocks were excluded from candidate discovery.
  case ignoredSourceBlocks(count: Int)
  /// Source taxonomy was retained as authored wording rather than converted into Kitchen Tags.
  case preservedTaxonomy(cuisines: [String], categories: [String], keywords: [String])
  /// The source names images; those references do not mean private image bytes were imported.
  case referencedImages(count: Int)

  /// Whether the concern describes retained source information rather than missing or uncertain content.
  public var isInformational: Bool {
    switch self {
    case .preservedTaxonomy, .referencedImages: true
    default: false
    }
  }
}

/// One reviewable recipe candidate and the concerns a person should consider.
public struct RecipeImportOption: Codable, Equatable, Identifiable, Sendable {
  /// Candidate location within one captured document, distinct from a durable Recipe identity.
  public struct Identifier: Codable, Hashable, Sendable {
    /// Index of the source JSON-LD block that supplied the candidate.
    public var blockIndex: Int
    /// Index of the candidate object within its source block.
    public var objectIndex: Int

    /// Creates a source-location identifier without generating Recipe authority.
    public init(blockIndex: Int, objectIndex: Int) {
      self.blockIndex = blockIndex
      self.objectIndex = objectIndex
    }
  }

  /// Source-location identity within this import result.
  public var id: Identifier
  /// Editable candidate contents and retained source capture, awaiting review and explicit Save.
  public var draft: RecipeDraft
  /// Review concerns and informational source observations accompanying this candidate.
  public var concerns: [RecipeImportConcern]

  /// Creates a reviewable candidate without accepting it into draft storage or Recipe authority.
  public init(id: Identifier, draft: RecipeDraft, concerns: [RecipeImportConcern]) {
    self.id = id
    self.draft = draft
    self.concerns = concerns
  }
}

/// Product-facing access to person-initiated recipe import.
public protocol RecipeImportServing: Sendable {
  /// Retrieves bounded source content and returns candidates for explicit review.
  /// Does not persist or publish a Recipe; cancellation and import failures are thrown.
  func importRecipe(from url: URL) async throws -> [RecipeImportOption]
}

/// Product-level import failures after transport and parsing limits are classified.
public enum RecipeImportServiceError: Error, Equatable, Sendable {
  /// No supported Recipe candidate was found in the retrieved document.
  case noRecipeCandidates
  /// The requested address or redirect chain is outside the bounded fetch policy.
  case disallowedAddress
  /// Input size, candidate count, or processing limits were exceeded.
  case pageTooLarge
  /// The response or document encoding cannot be interpreted as supported recipe content.
  case unsupportedPage
  /// Retrieval failed for a reason outside the recognized policy failures.
  case networkFailure
}
