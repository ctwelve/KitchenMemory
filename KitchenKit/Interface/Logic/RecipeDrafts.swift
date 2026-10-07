// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import Observation

/// Owns one Kitchen's device-local draft collection and durable lifetime.
@MainActor
@Observable
public final class RecipeDrafts {
  /// The result of accepted Recipe publication and the separate local cleanup attempt.
  public struct Publication: Equatable {
    /// Stable Recipe identity accepted by the repository.
    public let recipeID: Recipe.ID
    /// Whether the published draft was also removed from local storage.
    /// False preserves the frozen command for an exact retry after cleanup failure.
    public let removedDraft: Bool
  }

  /// Retained device-local drafts, including import candidates and frozen Save intentions.
  public private(set) var drafts: [RecipeEditingDraft] = []
  /// Whether local draft evidence was successfully loaded; false blocks replacement writes.
  public private(set) var storageIsAvailable = true
  /// Whether a local read, write, or publication attempt needs presentation or retry.
  public private(set) var storageFailed = false
  private let library: RecipeLibrary
  private let store: any RecipeEditingStoring

  /// Restores local drafts immediately and connects their change notifications to persistence.
  /// Retain this main-actor owner for the Kitchen lifetime; failed restoration preserves stored evidence.
  public init(library: RecipeLibrary, store: any RecipeEditingStoring) {
    self.library = library
    self.store = store
    restore()
  }

  /// Returns an existing draft for the Recipe or creates a local working copy.
  /// Returns nil when storage is unavailable or selection heads cannot be read. A returned
  /// draft may still have failed its initial persistence attempt; inspect ``storageFailed``.
  public func begin(_ original: StoredRecipe? = nil) -> RecipeEditingDraft? {
    guard storageIsAvailable else { storageFailed = true; return nil }
    if let original, let retained = drafts.first(where: { $0.original?.id == original.id }) { return retained }
    let draft = RecipeEditingDraft(original: original)
    if let original {
      do { draft.observedSelectionIDs = try library.editingSelectionHeads(for: original.id) } catch {
        storageFailed = true
        return nil
      }
    }
    drafts.append(draft)
    observe(draft)
    _ = persist()
    return draft
  }

  /// Copies an eligible retained revision into a new Recipe draft without repairing source authority.
  /// Throws if recovery content is unavailable or the local draft cannot be persisted.
  public func beginRecovery(recipeID: Recipe.ID, revisionID: RecipeRevision.ID) throws -> RecipeEditingDraft {
    guard storageIsAvailable else { throw FileRecipeEditingStore.Failure.invalidDocument }
    let content = try library.prepareRecoveryDraft(recipeID: recipeID, revisionID: revisionID)
    let draft = RecipeEditingDraft(original: nil, draft: content)
    drafts.append(draft)
    observe(draft)
    guard persist() else { throw CocoaError(.fileWriteUnknown) }
    return draft
  }

  /// Retains a comparison draft and its observed Selection frontier.
  /// Reuses an existing reconciliation draft, rejects a normal draft for the same Recipe,
  /// and throws on unavailable storage, invalid parents, or a failed local write.
  public func beginReconciliation(_ comparison: RecipeReconciliation) throws -> RecipeEditingDraft {
    guard storageIsAvailable else { throw FileRecipeEditingStore.Failure.invalidDocument }
    if let retained = drafts.first(where: { $0.original?.id == comparison.recipeID }) {
      guard retained.reconciliation != nil else { throw RecipeReconciliationError.existingDraft }
      return retained
    }
    guard let first = comparison.revisions.first else { throw RecipeReconciliationError.invalidParents }
    let original = StoredRecipe(
      recipe: Recipe(id: first.recipeID, kitchenID: comparison.kitchenID, currentRevisionID: first.id), revision: first
    )
    let draft = RecipeEditingDraft(original: original, draft: RecipeDraft(), reconciliation: comparison)
    draft.observedSelectionIDs = comparison.observedSelectionIDs
    drafts.append(draft)
    observe(draft)
    guard persist() else { throw CocoaError(.fileWriteUnknown) }
    return draft
  }

  private func restore() {
    do {
      drafts = try store.load().map(RecipeEditingDraft.init(record:))
      drafts.forEach(observe)
      storageIsAvailable = true
      storageFailed = false
    } catch {
      storageIsAvailable = false
      storageFailed = true
    }
  }

  /// Retries persistence when storage is readable, or retries restoration after a failed load.
  public func retryStorage() {
    if storageIsAvailable { _ = persist() } else { restore() }
  }

  /// Attempts to persist all local drafts; false lets presentation veto leaving the editor.
  public func prepareToLeave() -> Bool { persist() }

  /// Clears the presentation failure flag without retrying storage or discarding evidence.
  public func dismissStorageFailure() { storageFailed = false }

  /// Only explicit reset may replace unreadable local evidence with emptiness.
  public func purge() -> Bool {
    do {
      try store.save([])
      drafts = []
      storageIsAvailable = true
      storageFailed = false
      return true
    } catch {
      storageFailed = true
      return false
    }
  }

  /// Retains each delivered import candidate once using its encoded provenance identity.
  /// A failed encode or write restores prior collection membership and throws.
  public func stage(_ options: [RecipeImportOption]) throws {
    guard storageIsAvailable else { throw FileRecipeEditingStore.Failure.invalidDocument }
    let retained = drafts
    do {
      for option in options {
        let identifier = try option.retentionIdentifier()
        guard !drafts.contains(where: { $0.importIdentifier == identifier }) else { continue }
        let candidate = RecipeEditingDraft(draft: option.draft, concerns: option.concerns, phase: .importCandidate)
        candidate.importIdentifier = identifier
        observe(candidate)
        drafts.append(candidate)
      }
      guard persist() else { throw CocoaError(.fileWriteUnknown) }
    } catch {
      drafts = retained
      storageFailed = true
      throw error
    }
  }

  /// Stages one import candidate and returns its retained draft, or nil on failure.
  public func review(_ option: RecipeImportOption) -> RecipeEditingDraft? {
    do {
      try stage([option])
      let identifier = try option.retentionIdentifier()
      return drafts.first { $0.importIdentifier == identifier }
    } catch {
      storageFailed = true
      return nil
    }
  }

  /// Transitions an import candidate to editing only after local persistence succeeds.
  /// Repeated acceptance of an existing editing or saving draft succeeds without resetting it.
  public func accept(_ id: UUID) -> Bool {
    guard let candidate = drafts.first(where: { $0.id == id }) else { return false }
    guard candidate.isImportCandidate else { return true }
    let retainedPhase = candidate.phase
    candidate.phase = candidate.phase.acceptingImport()
    guard persist() else { candidate.phase = retainedPhase; return false }
    return true
  }

  /// Removes a retained local draft only if the new collection is persisted.
  /// Returns false for a missing draft or failed write; failed writes restore membership.
  @discardableResult
  public func discard(_ id: UUID) -> Bool {
    guard drafts.contains(where: { $0.id == id }) else { return false }
    let retained = drafts
    drafts.removeAll { $0.id == id }
    guard persist() else { drafts = retained; return false }
    return true
  }

  /// Freezes and locally persists the exact Save before publishing Recipe authority.
  /// A publication may succeed while cleanup fails. Callers can reveal the
  /// saved Recipe while retaining the draft and exact retry intention.
  /// Returns nil for a missing/review-only draft or failed preparation, local
  /// persistence, or acceptance; failures set ``storageFailed`` for presentation.
  public func save(_ id: UUID) -> Publication? {
    guard let draft = drafts.first(where: { $0.id == id }), !draft.isImportCandidate else { return nil }
    do {
      if draft.pendingSave == nil {
        if let comparison = draft.reconciliation {
          draft.phase = .saving(try library.prepareReconciliationSave(comparison, session: draft.session))
        } else {
          let command = try library.prepareSave(
            from: draft.session.validatedDraft(), original: draft.original,
            observedSelectionIDs: draft.observedSelectionIDs
          )
          if draft.original == nil {
            draft.pendingOrganization = try library.prepareOrganization(draft.organization, for: command)
          }
          draft.phase = .saving(command)
        }
      }
      // Persist final identities before crossing shared authority acceptance. If acceptance
      // succeeds but local cleanup fails, relaunch must retry this command, not publish a new Revision.
      guard persist(), let command = draft.pendingSave else { return nil }
      try library.save(command, organization: draft.pendingOrganization)
      return Publication(recipeID: command.recipe.id, removedDraft: discard(id))
    } catch {
      storageFailed = true
      return nil
    }
  }

  private func observe(_ draft: RecipeEditingDraft) {
    draft.changed = { [weak self] in _ = self?.persist() }
  }

  /// Writes the complete local collection and updates the storage failure flag.
  /// Returns false without writing when restoration has not established readable storage.
  @discardableResult
  public func persist() -> Bool {
    guard storageIsAvailable else { return false }
    do {
      try store.save(drafts.map(\.record))
      storageFailed = false
      return true
    } catch {
      storageFailed = true
      return false
    }
  }
}
