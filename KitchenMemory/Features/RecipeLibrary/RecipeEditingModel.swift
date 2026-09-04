// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import Observation

/// The retained editing intent is owned by the library, independently of its view.
@MainActor
@Observable
final class RecipeEditingModel: Identifiable {
  let id: UUID
  let original: StoredRecipe?
  let concerns: [RecipeImportConcern]
  var observedSelectionIDs: [RecipeSelectionCommand.ID] = []
  var phase: RecipeAuthoringPhase
  var confirmsDiscard = false
  var pendingSave: RecipeSaveCommand? {
    guard case .saving(let command) = phase else { return nil }
    return command
  }
  var isImportCandidate: Bool { phase == .importCandidate }
  var importIdentifier: String?
  var session: RecipeEditSession { didSet { changed() } }
  @ObservationIgnored var changed: () -> Void = {}

  var record: RecipeEditingRecord {
    RecipeEditingRecord(id: id, original: original, concerns: concerns, session: session,
                        observedSelectionIDs: observedSelectionIDs, pendingSave: nil,
                        isImportCandidate: nil, importIdentifier: importIdentifier, phase: phase)
  }

  init(record: RecipeEditingRecord) {
    id = record.id
    original = record.original
    concerns = record.concerns
    phase = record.phase ?? record.pendingSave.map(RecipeAuthoringPhase.saving)
      ?? (record.isImportCandidate == true ? .importCandidate : .editing)
    session = record.session
    if session.equipment == nil { session.equipment = original?.revision.equipment ?? [] }
    observedSelectionIDs = record.observedSelectionIDs
    importIdentifier = record.importIdentifier
  }

  init(original: StoredRecipe? = nil, draft: RecipeDraft? = nil,
       concerns: [RecipeImportConcern] = [], phase: RecipeAuthoringPhase = .editing) {
    id = UUID()
    self.original = original
    self.concerns = concerns
    self.phase = phase
    session = RecipeEditSession(draft: draft ?? original.map { RecipeDraft(revision: $0.revision) }
      ?? RecipeDraft())
    if session.equipment == nil { session.equipment = [] }
  }
}

extension RecipeLibraryModel {
  func beginEditing(_ original: StoredRecipe? = nil) {
    guard editingStorageIsAvailable else { editingStorageFailed = true; return }
    if let original, let retained = authoringItems.first(where: { $0.original?.id == original.id }) {
      editor = retained
      return
    }
    let draft = RecipeEditingModel(original: original)
    if let original {
      do { draft.observedSelectionIDs = try library.editingSelectionHeads(for: original.id) } catch {
        editingStorageFailed = true
        return
      }
    }
    authoringItems.append(draft)
    observeEditingDraft(draft)
    editor = draft
    _ = persistEditingDrafts()
  }

  func closeEditor() {
    if persistEditingDrafts() { editor = nil }
  }

  @discardableResult
  func prepareForLibraryNavigation() -> Bool {
    if editor != nil {
      closeEditor()
      guard editor == nil else { return false }
    }
    isShowingDrafts = false
    return true
  }

  @discardableResult
  func selectRecipeForReading(_ id: Recipe.ID?) -> Bool {
    guard prepareForLibraryNavigation() else { return false }
    selectedRecipeID = id
    return true
  }

  func resumeEditingDraft(_ id: UUID) {
    editor = authoringItems.first { $0.id == id }
  }

  func restoreEditingDrafts() {
    do {
      authoringItems = try editingStore.load().map(RecipeEditingModel.init(record:))
      authoringItems.forEach(observeEditingDraft)
      editingStorageIsAvailable = true
      editingStorageFailed = false
    } catch {
      editingStorageIsAvailable = false
      editingStorageFailed = true
    }
  }

  func retryEditingStorage() {
    if editingStorageIsAvailable {
      _ = persistEditingDrafts()
    } else {
      restoreEditingDrafts()
    }
  }

  func observeEditingDraft(_ draft: RecipeEditingModel) {
    draft.changed = { [weak self] in _ = self?.persistEditingDrafts() }
  }

  @discardableResult
  func persistEditingDrafts() -> Bool {
    guard editingStorageIsAvailable else { return false }
    do {
      try editingStore.save(authoringItems.map(\.record))
      editingStorageFailed = false
      return true
    } catch {
      editingStorageFailed = true
      return false
    }
  }

  func discardEditor(confirmed: Bool) {
    guard confirmed, let editor else { return }
    let retained = authoringItems
    authoringItems.removeAll { $0.id == editor.id }
    if persistEditingDrafts() { self.editor = nil } else { authoringItems = retained }
  }

  @discardableResult
  func saveEditor() -> Bool {
    guard let editor, !editor.isImportCandidate else { return false }
    do {
      if editor.pendingSave == nil {
        editor.phase = .saving(try library.prepareSave(
          from: editor.session.validatedDraft(), original: editor.original,
          observedSelectionIDs: editor.observedSelectionIDs
        ))
      }
      guard persistEditingDrafts(), let command = editor.pendingSave else { return false }
      try library.save(command)
      selectedRecipeID = command.recipe.id
      reload()
      discardEditor(confirmed: true)
      return self.editor == nil
    } catch {
      editingStorageFailed = true
      return false
    }
  }
}
