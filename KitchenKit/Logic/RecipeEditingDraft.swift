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
  public private(set) var reconciliation: RecipeReconciliation?
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
  public var canSaveRevision: Bool {
    !isImportCandidate && (reconciliation == nil || reconciliation?.draft != nil)
      && (pendingSave != nil || session.canSave)
  }

  var record: RecipeEditingRecord {
    RecipeEditingRecord(id: id, original: original, concerns: concerns, session: session,
                        observedSelectionIDs: observedSelectionIDs, importIdentifier: importIdentifier,
                        phase: phase, reconciliation: reconciliation)
  }

  init(record: RecipeEditingRecord) {
    id = record.id
    reconciliation = record.reconciliation
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
       concerns: [RecipeImportConcern] = [], phase: RecipeAuthoringPhase = .editing,
       reconciliation: RecipeReconciliation? = nil) {
    id = UUID()
    self.original = original
    self.reconciliation = reconciliation
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
  public func chooseRevision(_ id: RecipeRevision.ID) throws {
    try reconcile { try $0.chooseRevision(id) }
  }

  public func choose(_ field: RecipeComparisonField, from id: RecipeRevision.ID) throws {
    try reconcile { try $0.choose(field, from: id) }
  }

  public func chooseIngredient(
    from id: RecipeRevision.ID, section: Int, ingredient: Int,
    targetSection: Int, replacing targetIngredient: Int? = nil
  ) throws {
    try reconcile {
      try $0.chooseIngredient(from: id, section: section, ingredient: ingredient,
                              targetSection: targetSection, replacing: targetIngredient)
    }
  }

  private func reconcile(_ change: (inout RecipeReconciliation) throws -> Void) throws {
    guard pendingSave == nil, var comparison = reconciliation else { throw RecipeReconciliationError.invalidChoice }
    if comparison.draft != nil { try comparison.retainEdits(from: session) }
    try change(&comparison)
    guard let selected = comparison.draft else { throw RecipeReconciliationError.missingChoice }
    reconciliation = comparison
    contents = RecipeEditSession(draft: selected)
    changed()
  }

}
