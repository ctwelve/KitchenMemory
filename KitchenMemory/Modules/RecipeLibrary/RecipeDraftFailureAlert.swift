// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

struct RecipeDraftFailureAlert: ViewModifier {
  let model: RecipeLibraryModel?

  func body(content: Content) -> some View {
    content.alert(.recipeEditorDraftFailureTitle, isPresented: isPresented) {
      Button(.actionTryAgain) { model?.retryEditingStorage() }
      Button(.actionCancel, role: .cancel) {}
    } message: {
      Text(.recipeEditorDraftFailureMessage)
    }
  }

  private var isPresented: Binding<Bool> {
    Binding(
      get: { model?.editingStorageFailed ?? false },
      set: { model?.editingStorageFailed = $0 }
    )
  }
}
