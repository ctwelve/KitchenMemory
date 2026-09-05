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
    guard navigation.canLeave(), let draft = drafts.begin(original) else { return }
    navigation.move(to: .editor(draft.id))
  }

  func closeEditor() {
    navigation.move(to: .recipe)
  }

  @discardableResult
  func selectRecipeForReading(_ id: Recipe.ID?) -> Bool {
    navigation.selectRecipe(id)
  }

  func resumeEditingDraft(_ id: UUID) {
    guard drafts.drafts.contains(where: { $0.id == id }) else { return }
    navigation.move(to: .editor(id))
  }

  func retryEditingStorage() { drafts.retryStorage() }

  @discardableResult
  func persistEditingDrafts() -> Bool { drafts.persist() }

  func discardEditor(confirmed: Bool) {
    guard confirmed, let editor else { return }
    if drafts.discard(editor.id) { navigation.move(to: .recipe) }
  }

  @discardableResult
  func saveEditor() -> Bool {
    guard let editor, let publication = drafts.save(editor.id) else { return false }
    navigation.reconcileRecipeSelection(publication.recipeID)
    reload()
    if publication.removedDraft { navigation.move(to: .recipe) }
    return publication.removedDraft
  }
}
