// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

enum ActiveRecipeSheet: String, Identifiable {
  case importURL
  var id: String { rawValue }
}

struct RecipeLibrarySheetContent: View {
  let model: RecipeLibraryModel
  let close: () -> Void

  var body: some View {
    RecipeURLImportView(
      load: { url in try await model.importRecipe(from: url) },
      loadDocument: model.importDocument,
      select: {
        if model.beginImportReview($0) { close() }
      }
    )
  }
}

struct RecipeEditingDestination: View {
  let model: RecipeLibraryModel
  let editor: RecipeEditingModel

  var body: some View {
    RecipeEditorView(
      mode: editor.isImportCandidate ? .importReview : (editor.original == nil ? .create : .revise),
      editor: editor,
      close: model.closeEditor,
      discard: { model.discardEditor(confirmed: true) },
      save: {
        editor.isImportCandidate ? model.acceptImportCandidate(editor.id) : model.saveEditor()
      }
    )
    .id(editor.id)
  }
}
