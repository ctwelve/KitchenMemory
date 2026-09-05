// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import Observation

/// A native binding and dialog adapter over one KitchenKit-owned draft.
@MainActor
@Observable
final class RecipeEditingModel: Identifiable {
  let draft: RecipeEditingDraft
  var confirmsDiscard = false
  var id: UUID { draft.id }
  var original: StoredRecipe? { draft.original }
  var concerns: [RecipeImportConcern] { draft.concerns }
  var pendingSave: RecipeSaveCommand? { draft.pendingSave }
  var isImportCandidate: Bool { draft.isImportCandidate }
  var canSaveRevision: Bool { draft.canSaveRevision }
  var session: RecipeEditSession {
    get { draft.session }
    set { draft.session = newValue }
  }

  init(draft: RecipeEditingDraft) { self.draft = draft }
}

extension RecipeLibraryModel {
  var authoringItems: [RecipeEditingModel] {
    let ids = Set(drafts.drafts.map(\.id))
    editingPresentations = editingPresentations.filter { ids.contains($0.key) }
    return drafts.drafts.map(presentation)
  }

  func presentation(for draft: RecipeEditingDraft) -> RecipeEditingModel {
    if let retained = editingPresentations[draft.id], retained.draft === draft { return retained }
    let model = RecipeEditingModel(draft: draft)
    editingPresentations[draft.id] = model
    return model
  }

  func beginEditing(_ original: StoredRecipe? = nil) {
    guard let draft = drafts.begin(original) else { return }
    editor = presentation(for: draft)
  }

  func closeEditor() {
    if drafts.prepareToLeave() { editor = nil }
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
    editor = drafts.drafts.first { $0.id == id }.map(presentation)
  }

  func retryEditingStorage() { drafts.retryStorage() }

  @discardableResult
  func persistEditingDrafts() -> Bool { drafts.persist() }

  func discardEditor(confirmed: Bool) {
    guard confirmed, let editor else { return }
    if drafts.discard(editor.id) { self.editor = nil }
  }

  @discardableResult
  func saveEditor() -> Bool {
    guard let editor, let publication = drafts.save(editor.id) else { return false }
    selectedRecipeID = publication.recipeID
    reload()
    if publication.removedDraft { self.editor = nil }
    return publication.removedDraft
  }
}
