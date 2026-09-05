// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

extension RecipeLibraryNavigation {
  func canPerform(_ command: LibraryCommandActions.Command, library: RecipeLibraryModel,
                  sessions: CookingSessionPresentationModel) -> Bool {
    guard library.navigation === self, sessions.navigation === self,
          library.startupState == .ready, library.editor?.confirmsDiscard != true else { return false }
    switch command {
    case .newRecipe, .importRecipe: return library.editingStorageIsAvailable
    case .saveRevision: return library.editor?.canSaveRevision == true
    case .editRecipe, .startCooking, .recipeHistory:
      guard destination == .recipe, library.selectedRecipe != nil else { return false }
      return command != .editRecipe || library.editingStorageIsAvailable
    case .drafts: return !library.authoringItems.isEmpty
    case .recovery: return sessions.showsRecoveryDestination
    case .sessions, .deletedItems: return true
    }
  }

  func perform(_ command: LibraryCommandActions.Command, library: RecipeLibraryModel,
               sessions: CookingSessionPresentationModel, openImport: () -> Void) -> Bool {
    guard canPerform(command, library: library, sessions: sessions) else { return false }
    switch command {
    case .newRecipe, .importRecipe, .saveRevision, .editRecipe, .startCooking:
      return author(command, library: library, sessions: sessions, openImport: openImport)
    case .recipeHistory:
      guard let recipeID = library.selectedRecipeID else { return false }
      return sessions.showRecipeSessionHistory(for: recipeID)
    case .drafts: return move(to: .drafts)
    case .sessions: return move(to: .history(.all))
    case .deletedItems: return move(to: .deletedItems)
    case .recovery: return move(to: .recovery)
    }
  }

  private func author(_ command: LibraryCommandActions.Command, library: RecipeLibraryModel,
                      sessions: CookingSessionPresentationModel, openImport: () -> Void) -> Bool {
    switch command {
    case .newRecipe:
      let previous = library.editor?.id
      library.beginEditing()
      return library.editor != nil && library.editor?.id != previous
    case .importRecipe:
      guard move(to: .recipe) else { return false }
      openImport()
      return true
    case .saveRevision: return library.saveEditor()
    case .editRecipe:
      library.beginEditing(library.selectedRecipe)
      return library.editor != nil
    case .startCooking:
      guard let recipe = library.selectedRecipe else { return false }
      return sessions.start(from: recipe)
    default: return false
    }
  }
}
