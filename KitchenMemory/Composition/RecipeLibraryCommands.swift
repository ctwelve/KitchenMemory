// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if os(macOS)
import SwiftUI

struct RecipeLibraryCommands: Commands {
  static let windowID = "recipe-library"
  static let importWindowID = "recipe-import"

  let app: PreparedApp?

  @Environment(\.openWindow) private var openWindow
  @FocusedValue(\.libraryCommandActions) private var actions
  @FocusedValue(\.libraryWindowPresent) private var libraryWindowPresent

  var body: some Commands {
    CommandGroup(after: .windowArrangement) {
      Button(.menuWindowNewLibrary) {
        openWindow(id: Self.windowID)
      }
      .keyboardShortcut("n", modifiers: [.command, .shift])
    }
    CommandGroup(replacing: .newItem) {
      Button(.libraryActionNewRecipe) { newRecipeActions?.perform(.newRecipe) }
        .disabled(newRecipeActions?.canPerform(.newRecipe) != true)
        .keyboardShortcut("n")
      Button(.libraryActionImportRecipe) { importActions?.perform(.importRecipe) }
        .disabled(importActions?.canPerform(.importRecipe) != true)
        .keyboardShortcut("i", modifiers: [.command, .shift])
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

  private var importActions: LibraryCommandActions? {
    Self.resolveImportActions(app: app, focused: actions, libraryWindowPresent: libraryWindowPresent == true) {
      openWindow(id: Self.importWindowID)
    }
  }

  private var newRecipeActions: LibraryCommandActions? {
    Self.resolveNewRecipeActions(app: app, focused: actions, libraryWindowPresent: libraryWindowPresent == true) {
      openWindow(id: Self.windowID)
    }
  }

  static func resolveNewRecipeActions(
    app: PreparedApp?, focused: LibraryCommandActions?, libraryWindowPresent: Bool,
    openLibrary: @escaping () -> Void
  ) -> LibraryCommandActions? {
    if libraryWindowPresent { return focused }
    return app.map {
      LibraryCommandActions(library: $0.libraryModel, sessions: $0.sessionModel,
                            focusDestination: openLibrary)
    }
  }

  static func resolveImportActions(
    app: PreparedApp?, focused: LibraryCommandActions?, libraryWindowPresent: Bool,
    openImport: @escaping () -> Void
  ) -> LibraryCommandActions? {
    // A window with blocked actions must not fall through to the app command.
    if libraryWindowPresent { return focused }
    return app.map {
      LibraryCommandActions(library: $0.libraryModel, sessions: $0.sessionModel,
                            openImport: openImport)
    }
  }

  private func action(_ title: LocalizedStringResource, _ command: LibraryCommandActions.Command) -> some View {
    Button(title) { actions?.perform(command) }
      .disabled(actions?.canPerform(command) != true)
  }
}
#endif
