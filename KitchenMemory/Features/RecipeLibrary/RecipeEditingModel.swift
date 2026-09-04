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
  var session: RecipeEditSession

  init(original: StoredRecipe? = nil, draft: RecipeDraft? = nil,
       concerns: [RecipeImportConcern] = []) {
    id = UUID()
    self.original = original
    self.concerns = concerns
    session = RecipeEditSession(draft: draft ?? original.map { RecipeDraft(revision: $0.revision) }
      ?? RecipeDraft())
  }
}

extension RecipeLibraryModel {
  func beginEditing(_ original: StoredRecipe? = nil) {
    if let original, let retained = editingDrafts.first(where: { $0.original?.id == original.id }) {
      editor = retained
      return
    }
    let draft = RecipeEditingModel(original: original)
    editingDrafts.append(draft)
    editor = draft
  }

  func beginImportReview(_ option: RecipeImportOption) {
    let draft = RecipeEditingModel(draft: option.draft, concerns: option.concerns)
    editingDrafts.append(draft)
    editor = draft
  }

  func closeEditor() { editor = nil }

  func discardEditor(confirmed: Bool) {
    guard confirmed, let editor else { return }
    editingDrafts.removeAll { $0.id == editor.id }
    self.editor = nil
  }

  @discardableResult
  func saveEditor() -> Bool {
    guard let editor, let draft = try? editor.session.validatedDraft() else { return false }
    let saved: Bool
    if let original = editor.original {
      saved = reviseRecipe(id: original.id, from: draft)
    } else {
      saved = createRecipe(from: draft)
    }
    if saved { discardEditor(confirmed: true) }
    return saved
  }
}
