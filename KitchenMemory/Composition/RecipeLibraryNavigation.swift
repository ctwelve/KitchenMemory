// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import Observation

/// The accepted destination for one prepared app graph. Navigation never authors
/// Session lifecycle evidence; leaving an editor asks KitchenKit to persist it.
@MainActor
@Observable
final class RecipeLibraryNavigation {
  enum Destination: Equatable {
    case recipe
    case editor(UUID)
    case drafts
    case session(CookingSession.ID, history: CookingSessionHistoryScope?)
    case history(CookingSessionHistoryScope)
    case finished(CookingSession.ID, history: CookingSessionHistoryScope)
    case deletedItems
    case recovery
  }

  private(set) var destination: Destination = .recipe
  private(set) var selectedRecipeID: Recipe.ID?
  @ObservationIgnored var prepareToLeaveEditor: () -> Bool = { true }
  @ObservationIgnored private var persistSessionSelection: (CookingSession.ID?) -> Void = { _ in }

  var currentSessionID: CookingSession.ID? {
    guard case .session(let id, _) = destination else { return nil }
    return id
  }

  var historyScope: CookingSessionHistoryScope? {
    switch destination {
    case .history(let scope), .finished(_, let scope): scope
    case .session(_, let scope): scope
    default: nil
    }
  }

  func installSessionStore(_ store: any CookingSessionPresentationStoring) {
    if let id = store.currentSessionID { destination = .session(id, history: nil) }
    persistSessionSelection = { store.currentSessionID = $0 }
  }

  func canLeave() -> Bool {
    guard case .editor = destination else { return true }
    return prepareToLeaveEditor()
  }

  @discardableResult
  func move(to next: Destination) -> Bool {
    guard next != destination else { return true }
    guard canLeave() else { return false }
    destination = next
    persistSessionSelection(currentSessionID)
    return true
  }

  @discardableResult
  func selectRecipe(_ id: Recipe.ID?) -> Bool {
    guard move(to: .recipe) else { return false }
    selectedRecipeID = id
    return true
  }

  /// Refresh selection metadata without stealing an editor or Session destination.
  func reconcileRecipeSelection(_ id: Recipe.ID?) { selectedRecipeID = id }
}
