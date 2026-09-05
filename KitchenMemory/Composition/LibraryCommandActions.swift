// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

/// Window-specific effects around the shared app graph's navigation intentions.
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
    library.navigation.canPerform(command, library: library, sessions: sessions)
  }

  @discardableResult
  func perform(_ command: Command) -> Bool {
    guard library.navigation.perform(command, library: library, sessions: sessions, openImport: openImport)
    else { return false }
    if command != .saveRevision { focusDestination() }
    return true
  }
}
