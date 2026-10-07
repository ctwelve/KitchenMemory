// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import Observation

/// Editable contents and durable phase; applications own selection and dialogs.
@MainActor
@Observable
public final class RecipeEditingDraft: Identifiable {
  /// Stable device-local identity used to restore and address this editing draft.
  public let id: UUID
  /// The observed maintained Recipe and Revision, or nil when creating a new Recipe.
  public let original: StoredRecipe?
  /// Retained competing revisions and explicit content choices, when reconciling authority.
  public private(set) var reconciliation: RecipeReconciliation?
  /// Import uncertainty retained for review; concerns do not authorize publication.
  public let concerns: [RecipeImportConcern]
  /// The Selection frontier captured for this draft, retained when freezing a Save.
  public internal(set) var observedSelectionIDs: [RecipeSelectionCommand.ID]
  /// Recoverable authoring phase; saving carries the exact command to retry.
  public internal(set) var phase: RecipeAuthoringPhase
  /// Encoded candidate identity used to avoid retaining the same import twice.
  public internal(set) var importIdentifier: String?
  /// Frozen first-Save organization batch, retained alongside its Recipe command.
  public internal(set) var pendingOrganization: RecipeOrganizationCommand?
  private var organizationContents: PendingRecipeOrganization
  /// Organization choices for a new Recipe; assignments are ignored after Save freezes or for existing Recipes.
  public var organization: PendingRecipeOrganization {
    get { organizationContents }
    set {
      guard original == nil, pendingSave == nil else { return }
      organizationContents = newValue
      changed()
    }
  }
  private var contents: RecipeEditSession
  @ObservationIgnored var changed: () -> Void = {}
  @ObservationIgnored weak var ingredientTextEditing: RecipeIngredientTextEditing?
  /// Transient identity for the native editor lifetime. Recreate the control when this changes.
  /// Precision changes retain it; replacement content and completed editor lifetimes do not.
  public private(set) var ingredientTextEditorID = UUID()

  func retireIngredientTextEditing(_ editing: RecipeIngredientTextEditing) {
    guard ingredientTextEditing === editing else { return }
    ingredientTextEditing = nil
    ingredientTextEditorID = UUID()
  }

  /// Read-only snapshot of live editing contents. Use ingredient operations for ingredient
  /// changes and `updateRecipeDetails(from:)` to apply edits to unrelated recipe fields.
  public internal(set) var session: RecipeEditSession {
    get { contents }
    set {
      guard pendingSave == nil else { return }
      contents = newValue
      ingredientTextEditing?.synchronize()
      changed()
    }
  }

  func updateIngredientText(_ text: RecipeIngredientTextDraft, from editing: RecipeIngredientTextEditing) -> Bool {
    guard ingredientTextEditing === editing, pendingSave == nil else { return false }
    var updated = contents
    updated.updateIngredientText(text)
    guard updated != contents else { return false }
    contents = updated
    changed()
    return true
  }

  /// The frozen Save command, or nil before publication is prepared.
  /// Its presence prevents further content edits so retries describe identical intent.
  public var pendingSave: RecipeSaveCommand? {
    guard case .saving(let command) = phase else { return nil }
    return command
  }
  /// Whether this draft still requires explicit acceptance before editing and Save.
  public var isImportCandidate: Bool { phase == .importCandidate }
  /// Whether review and reconciliation choices permit Save and the form is valid or already frozen.
  public var canSaveRevision: Bool {
    !isImportCandidate && (reconciliation == nil || reconciliation?.draft != nil)
      && (pendingSave != nil || session.canSave)
  }

  var record: RecipeEditingRecord {
    RecipeEditingRecord(id: id, original: original, concerns: concerns, session: session,
                        observedSelectionIDs: observedSelectionIDs, importIdentifier: importIdentifier,
                        phase: phase, reconciliation: reconciliation,
                        organization: organization, pendingOrganization: pendingOrganization)
  }

  init(record: RecipeEditingRecord) {
    organizationContents = record.organization ?? PendingRecipeOrganization()
    pendingOrganization = record.pendingOrganization
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
    // Older clients could persist structured edits without updating the text document.
    // Repair from those maintained contents without completing pending interpretation.
    if session.ingredientText != nil { session.prepareIngredientText() }
    contents = session
  }

  init(original: StoredRecipe? = nil, draft: RecipeDraft? = nil,
       concerns: [RecipeImportConcern] = [], phase: RecipeAuthoringPhase = .editing,
       reconciliation: RecipeReconciliation? = nil) {
    organizationContents = PendingRecipeOrganization()
    pendingOrganization = nil
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
  /// Replaces reconciliation content with an explicitly selected revision, retiring native text history.
  /// Throws when the draft is frozen, comparison is absent, or the revision is not a candidate.
  public func chooseRevision(_ id: RecipeRevision.ID) throws {
    try reconcile(retainingIngredientText: false) { try $0.chooseRevision(id) }
  }

  /// Copies one compared field into local reconciliation content.
  /// Ingredient replacement retires its pending text; other fields preserve local ingredient work.
  public func choose(_ field: RecipeComparisonField, from id: RecipeRevision.ID) throws {
    try reconcile(retainingIngredientText: field != .ingredients) { try $0.choose(field, from: id) }
  }

  /// Copies one compared ingredient with a new identity into the selected local draft.
  /// Untouched ingredient text and proposals remain retained; invalid choices or frozen Saves throw.
  public func chooseIngredient(
    from id: RecipeRevision.ID, section: Int, ingredient: Int,
    targetSection: Int, replacing targetIngredient: Int? = nil
  ) throws {
    try reconcile {
      try $0.chooseIngredient(from: id, section: section, ingredient: ingredient,
                              targetSection: targetSection, replacing: targetIngredient)
    }
  }

  private func reconcile(
    retainingIngredientText: Bool = true, _ change: (inout RecipeReconciliation) throws -> Void
  ) throws {
    guard pendingSave == nil, var comparison = reconciliation else { throw RecipeReconciliationError.invalidChoice }
    if comparison.draft != nil { try comparison.retainEditingContents(from: session) }
    try change(&comparison)
    guard let selected = comparison.draft else { throw RecipeReconciliationError.missingChoice }
    var updated = RecipeEditSession(draft: selected)
    if retainingIngredientText, let text = contents.ingredientText {
      updated.updateIngredientText(text.incorporating(selected.ingredientSections))
    }
    ingredientTextEditing?.end()
    reconciliation = comparison
    contents = updated
    changed()
  }

}
