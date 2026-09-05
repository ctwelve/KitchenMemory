// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import Observation

/// Editable contents and durable phase; applications own selection and dialogs.
@MainActor
@Observable
public final class RecipeEditingDraft: Identifiable {
  public let id: UUID
  public let original: StoredRecipe?
  public let concerns: [RecipeImportConcern]
  public internal(set) var observedSelectionIDs: [RecipeSelectionCommand.ID]
  public internal(set) var phase: RecipeAuthoringPhase
  public internal(set) var importIdentifier: String?
  private var contents: RecipeEditSession
  @ObservationIgnored var changed: () -> Void = {}

  public var session: RecipeEditSession {
    get { contents }
    set {
      guard pendingSave == nil else { return }
      contents = newValue
      changed()
    }
  }

  public var pendingSave: RecipeSaveCommand? {
    guard case .saving(let command) = phase else { return nil }
    return command
  }
  public var isImportCandidate: Bool { phase == .importCandidate }
  public var canSaveRevision: Bool { !isImportCandidate && (pendingSave != nil || session.canSave) }

  var record: RecipeEditingRecord {
    RecipeEditingRecord(id: id, original: original, concerns: concerns, session: session,
                        observedSelectionIDs: observedSelectionIDs, importIdentifier: importIdentifier, phase: phase)
  }

  init(record: RecipeEditingRecord) {
    id = record.id
    original = record.original
    concerns = record.concerns
    phase = record.phase ?? record.pendingSave.map(RecipeAuthoringPhase.saving)
      ?? (record.isImportCandidate == true ? .importCandidate : .editing)
    observedSelectionIDs = record.observedSelectionIDs
    importIdentifier = record.importIdentifier
    var session = record.session
    if session.equipment == nil { session.equipment = record.original?.revision.equipment ?? [] }
    if session.media == nil { session.media = record.original?.revision.media ?? [] }
    contents = session
  }

  init(original: StoredRecipe? = nil, draft: RecipeDraft? = nil,
       concerns: [RecipeImportConcern] = [], phase: RecipeAuthoringPhase = .editing) {
    id = UUID()
    self.original = original
    self.concerns = concerns
    self.phase = phase
    observedSelectionIDs = []
    importIdentifier = nil
    var session = RecipeEditSession(
      draft: draft ?? original.map { RecipeDraft(revision: $0.revision) } ?? RecipeDraft()
    )
    if session.equipment == nil { session.equipment = [] }
    if session.media == nil { session.media = [] }
    contents = session
  }
}
