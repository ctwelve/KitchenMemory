// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import Observation

/// Owns one Kitchen's device-local draft collection and durable lifetime.
@MainActor
@Observable
public final class RecipeDrafts {
  public struct Publication: Equatable {
    public let recipeID: Recipe.ID
    public let removedDraft: Bool
  }

  public private(set) var drafts: [RecipeEditingDraft] = []
  public private(set) var storageIsAvailable = true
  public private(set) var storageFailed = false
  private let library: RecipeLibrary
  private let store: any RecipeEditingStoring

  public init(library: RecipeLibrary, store: any RecipeEditingStoring) {
    self.library = library
    self.store = store
    restore()
  }

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

  public func retryStorage() {
    if storageIsAvailable { _ = persist() } else { restore() }
  }

  public func prepareToLeave() -> Bool { persist() }

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

  public func accept(_ id: UUID) -> Bool {
    guard let candidate = drafts.first(where: { $0.id == id }) else { return false }
    guard candidate.isImportCandidate else { return true }
    let retainedPhase = candidate.phase
    candidate.phase = candidate.phase.acceptingImport()
    guard persist() else { candidate.phase = retainedPhase; return false }
    return true
  }

  @discardableResult
  public func discard(_ id: UUID) -> Bool {
    guard drafts.contains(where: { $0.id == id }) else { return false }
    let retained = drafts
    drafts.removeAll { $0.id == id }
    guard persist() else { drafts = retained; return false }
    return true
  }

  /// A publication may succeed while cleanup fails. Callers can reveal the
  /// saved Recipe while retaining the draft and exact retry intention.
  public func save(_ id: UUID) -> Publication? {
    guard let draft = drafts.first(where: { $0.id == id }), !draft.isImportCandidate else { return nil }
    do {
      if draft.pendingSave == nil {
        draft.phase = .saving(try library.prepareSave(
          from: draft.session.validatedDraft(), original: draft.original,
          observedSelectionIDs: draft.observedSelectionIDs
        ))
      }
      guard persist(), let command = draft.pendingSave else { return nil }
      try library.save(command)
      return Publication(recipeID: command.recipe.id, removedDraft: discard(id))
    } catch {
      storageFailed = true
      return nil
    }
  }

  private func observe(_ draft: RecipeEditingDraft) {
    draft.changed = { [weak self] in _ = self?.persist() }
  }

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
