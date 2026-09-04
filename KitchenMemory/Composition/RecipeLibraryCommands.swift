// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if os(macOS)
import SwiftUI

struct RecipeLibraryCommands: Commands {
  @FocusedValue(\.libraryCommandActions) private var actions

  var body: some Commands {
    CommandGroup(replacing: .newItem) {
      action(.libraryActionNewRecipe, .newRecipe).keyboardShortcut("n")
      action(.libraryActionImportRecipe, .importRecipe).keyboardShortcut("i", modifiers: [.command, .shift])
    }
    CommandGroup(replacing: .saveItem) {
      action(.recipeEditorReviseActionSave, .saveRevision).keyboardShortcut("s")
    }
    CommandGroup(after: .sidebar) {
      Divider()
      action(.recipeDraftsTitle, .drafts)
      action(.sessionHistoryTitle, .sessions)
      action(.deletedItemsTitle, .deletedItems)
      action(.recoveryTitle, .recovery)
    }
    CommandMenu(.menuRecipeTitle) {
      action(.recipeActionEdit, .editRecipe).keyboardShortcut("e", modifiers: [.command, .shift])
      action(.sessionActionStart, .startCooking).keyboardShortcut("k", modifiers: [.command, .shift])
      action(.sessionHistoryRecipeTitle, .recipeHistory)
    }
  }

  private func action(_ title: LocalizedStringResource, _ command: LibraryCommandActions.Command) -> some View {
    Button(title) { actions?.perform(command) }
      .disabled(actions?.canPerform(command) != true)
  }
}
#endif
