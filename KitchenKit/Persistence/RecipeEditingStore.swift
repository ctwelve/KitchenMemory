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

/// Process-local draft store for disposable graphs; it provides no relaunch durability.
@MainActor
public final class VolatileRecipeEditingStore: RecipeEditingStoring {
  /// Creates an empty process-local draft store.
  public init() {}
  private var drafts: [RecipeEditingRecord] = []
  /// Returns the currently retained in-memory draft collection.
  public func load() throws -> [RecipeEditingRecord] { drafts }
  /// Replaces the process-local collection without file or cloud persistence.
  public func save(_ drafts: [RecipeEditingRecord]) throws { self.drafts = drafts }
}

/// A device-local atomic document, never registered in the CloudKit schema.
@MainActor
public struct FileRecipeEditingStore: RecipeEditingStoring {
  /// Device-local document location; this document is never registered with CloudKit.
  public let url: URL

  /// Selects the local draft document location without reading or creating the file.
  public init(url: URL) { self.url = url }

  private struct Document: Codable {
    var version = 1
    let drafts: [RecipeEditingRecord]
  }

  /// Structural draft-document failures that prevent safe restoration.
  public enum Failure: Error {
    /// Unsupported document version or repeated draft/edited-Recipe identities prevent safe restoration.
    case invalidDocument
  }

  /// Decodes a version-1 local document and verifies unique draft and edited-Recipe identities.
  /// An absent file returns an empty collection; unsupported or inconsistent documents,
  /// decode failures, and filesystem failures throw without replacing stored evidence.
  public func load() throws -> [RecipeEditingRecord] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
    let existing = document.drafts.compactMap { $0.original?.id }
    guard document.version == 1,
          Set(document.drafts.map(\.id)).count == document.drafts.count,
          Set(existing).count == existing.count else { throw Failure.invalidDocument }
    return document.drafts
  }

  /// Encodes the complete version-1 collection and atomically replaces the local document.
  /// Creates its parent directory if needed; encoding and filesystem failures propagate.
  public func save(_ drafts: [RecipeEditingRecord]) throws {
    let data = try JSONEncoder().encode(Document(drafts: drafts))
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
  }
}
