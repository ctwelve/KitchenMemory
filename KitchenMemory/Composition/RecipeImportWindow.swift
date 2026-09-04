// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if os(macOS)
import SwiftUI

/// Hosts import when no library window owns the command. Candidate review
/// returns to a library window only after the import has been staged safely.
struct RecipeImportWindow: View {
  let model: RecipeLibraryModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    RecipeLibrarySheetContent(model: model) {
      openWindow(id: RecipeLibraryCommands.windowID)
      dismiss()
    }
    .focusedSceneValue(\.libraryWindowPresent, true)
    .modifier(RecipeDraftFailureAlert(model: model))
  }
}
#endif
