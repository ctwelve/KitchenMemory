// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Codable device-local draft evidence, including legacy restoration fields and frozen publication intent.
/// It is recoverable working state rather than synchronized Recipe authority.
public struct RecipeEditingRecord: Codable, Equatable {
  /// Stable local draft identity retained across document writes and relaunch.
  public let id: UUID
  /// Observed maintained Recipe base, or nil when authoring a new Recipe.
  public let original: StoredRecipe?
  /// Retained import review concerns for this working copy.
  public let concerns: [RecipeImportConcern]
  /// Recoverable form and ingredient-text contents.
  public var session: RecipeEditSession
  /// Observed Selection frontier retained for explicit Save preparation.
  public var observedSelectionIDs: [RecipeSelectionCommand.ID]
  /// Legacy optional frozen Save field, used when restoring records without a phase.
  public var pendingSave: RecipeSaveCommand?
  /// Legacy optional review-phase field, used when restoring records without a phase.
  public var isImportCandidate: Bool?
  /// Encoded provenance identity used to deduplicate delivered import candidates.
  public var importIdentifier: String?
  /// Authoring phase with the current exact frozen Save, absent in legacy documents.
  public var phase: RecipeAuthoringPhase?
  /// Local first-Save organization choices, absent in legacy documents.
  public var organization: PendingRecipeOrganization?
  /// Frozen organization command retained with its exact first Save.
  public var pendingOrganization: RecipeOrganizationCommand?
  /// Retained comparison parents, Selection frontier, and chosen authored contents.
  public var reconciliation: RecipeReconciliation?

  /// Creates a recoverable draft record without encoding, validation, or storage writes.
  public init(id: UUID, original: StoredRecipe?, concerns: [RecipeImportConcern], session: RecipeEditSession,
              observedSelectionIDs: [RecipeSelectionCommand.ID], pendingSave: RecipeSaveCommand? = nil,
              isImportCandidate: Bool? = nil, importIdentifier: String? = nil, phase: RecipeAuthoringPhase? = nil,
              reconciliation: RecipeReconciliation? = nil, organization: PendingRecipeOrganization? = nil,
              pendingOrganization: RecipeOrganizationCommand? = nil) {
    self.id = id
    self.original = original
    self.concerns = concerns
    self.session = session
    self.observedSelectionIDs = observedSelectionIDs
    self.pendingSave = pendingSave
    self.isImportCandidate = isImportCandidate
    self.importIdentifier = importIdentifier
    self.phase = phase
    self.reconciliation = reconciliation
    self.organization = organization
    self.pendingOrganization = pendingOrganization
  }
}

/// Main-actor storage of complete device-local draft collections.
/// Unreadable evidence must be reported rather than silently replaced with an empty collection.
@MainActor
public protocol RecipeEditingStoring {
  /// Loads retained drafts; an absent document may be empty, but invalid evidence must throw.
  func load() throws -> [RecipeEditingRecord]
  /// Replaces the complete local draft collection or throws on encoding or storage failure.
  func save(_ drafts: [RecipeEditingRecord]) throws
}
