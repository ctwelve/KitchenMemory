// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

/// Shared presentation intentions for toolbar, sidebar, and focused-window menus.
@MainActor
struct LibraryCommandActions {
  enum Command: CaseIterable {
    case newRecipe, importRecipe, saveRevision, editRecipe, startCooking, recipeHistory
    case drafts, sessions, deletedItems, recovery
  }

  let library: RecipeLibraryModel
  let sessions: CookingSessionPresentationModel
  var openImport: () -> Void = {}
  var focusDestination: () -> Void = {}

  func canPerform(_ command: Command) -> Bool {
    guard library.startupState == .ready, library.editor?.confirmsDiscard != true else { return false }
    switch command {
    case .newRecipe, .importRecipe:
      return library.editingStorageIsAvailable
    case .saveRevision:
      return library.editor?.canSaveRevision == true
    case .editRecipe, .startCooking, .recipeHistory:
      guard library.selectedRecipe != nil, library.editor == nil,
            !library.isShowingDrafts, sessions.currentSession == nil,
            !sessions.isShowingSessionHistory, sessions.libraryDestination == nil,
            sessions.observedFinishedSession == nil else { return false }
      return command != .editRecipe || library.editingStorageIsAvailable
    case .drafts: return !library.authoringItems.isEmpty
    case .recovery: return sessions.showsRecoveryDestination
    case .sessions, .deletedItems: return true
    }
  }

  @discardableResult
  func perform(_ command: Command) -> Bool {
    guard canPerform(command) else { return false }
    switch command {
    case .newRecipe, .importRecipe, .saveRevision, .editRecipe:
      return author(command)
    case .startCooking:
      guard let recipe = library.selectedRecipe else { return false }
      return sessions.start(from: recipe)
    case .recipeHistory, .drafts, .sessions, .deletedItems, .recovery:
      return show(command)
    }
  }

  private func author(_ command: Command) -> Bool {
    switch command {
    case .newRecipe:
      guard library.prepareForLibraryNavigation() else { return false }
      library.beginEditing()
    case .importRecipe:
      guard library.prepareForLibraryNavigation() else { return false }
      openImport()
    case .saveRevision:
      return library.saveEditor()
    case .editRecipe:
      library.beginEditing(library.selectedRecipe)
    default: return false
    }
    focusDestination()
    return true
  }

  private func show(_ command: Command) -> Bool {
    guard library.prepareForLibraryNavigation() else { return false }
    let recipeID = library.selectedRecipeID
    if command != .recipeHistory { library.selectedRecipeID = nil }
    switch command {
    case .recipeHistory:
      guard let recipeID else { return false }
      sessions.showRecipeSessionHistory(for: recipeID)
    case .drafts:
      sessions.leaveCurrentSession()
      sessions.showRecipes()
      library.isShowingDrafts = true
    case .sessions: sessions.showSessionHistory()
    case .deletedItems: sessions.showDeletedItems()
    case .recovery: sessions.showRecovery()
    default: return false
    }
    focusDestination()
    return true
  }
}
