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
  enum Focus: Equatable { case content, detail }

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

  enum ContentDestination: Equatable {
    case recipes, drafts, history(CookingSessionHistoryScope), deletedItems, recovery
  }

  enum AuxiliarySelection: Equatable {
    case deletedRecipe(Recipe.ID), deletedSession(CookingSession.ID)
    case recoveryRecipe(Recipe.ID), recoverySession(CookingSession.ID), organization

    var destination: Destination {
      switch self {
      case .deletedRecipe, .deletedSession: .deletedItems
      case .recoveryRecipe, .recoverySession, .organization: .recovery
      }
    }
  }

  private(set) var auxiliarySelection: AuxiliarySelection?
  var recipeListAnchor: Recipe.ID?
  var historyListAnchor: CookingSession.ID?

  @discardableResult
  func selectAuxiliary(_ item: AuxiliarySelection) -> Bool {
    accept(item.destination, focus: .detail, auxiliary: item)
  }

  private(set) var contentDestination: ContentDestination = .recipes
  private(set) var destination: Destination = .recipe
  private(set) var focus: Focus = .content
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
    if let id = store.currentSessionID { move(to: .session(id, history: nil)) }
    persistSessionSelection = { store.currentSessionID = $0 }
  }

  func canLeave() -> Bool {
    guard case .editor = destination else { return true }
    return prepareToLeaveEditor()
  }

  @discardableResult
  func move(to next: Destination) -> Bool {
    accept(next)
  }

  private func accept(_ next: Destination, focus requestedFocus: Focus? = nil,
                      auxiliary: AuxiliarySelection? = nil) -> Bool {
    guard next == destination || canLeave() else { return false }
    let changedDestination = next != destination
    let context = context(for: next)
    destination = next
    contentDestination = context.content
    focus = requestedFocus ?? context.focus
    auxiliarySelection = auxiliary
    if changedDestination { persistSessionSelection(currentSessionID) }
    return true
  }

  private func context(for next: Destination) -> (content: ContentDestination, focus: Focus) {
    switch next {
    case .recipe: return (.recipes, selectedRecipeID == nil ? .content : .detail)
    case .drafts: return (.drafts, .content)
    case .history(let scope): return (.history(scope), .content)
    case .finished(_, let scope), .session(_, history: .some(let scope)):
      return (.history(scope), .detail)
    case .deletedItems: return (.deletedItems, .content)
    case .recovery: return (.recovery, .content)
    case .editor:
      return (contentDestination == .recipes ? .recipes : .drafts, .detail)
    case .session(_, history: nil): return (contentDestination, .detail)
    }
  }

  @discardableResult
  func selectRecipe(_ id: Recipe.ID?) -> Bool {
    guard accept(.recipe, focus: id == nil ? .content : .detail) else { return false }
    selectedRecipeID = id
    return true
  }

  /// A filter change is navigation: do not hide the current editor or mutate its
  /// browsing context until its recoverable draft has been accepted.
  @discardableResult
  func browseRecipes(changingFilter: () -> Void) -> Bool {
    guard accept(.recipe, focus: .content) else { return false }
    changingFilter()
    return true
  }

  /// Refresh selection metadata without stealing an editor or Session destination.
  func reconcileRecipeSelection(_ id: Recipe.ID?) { selectedRecipeID = id }

  /// Reopening a retained item affects only the invoking window's column adapter.
  @discardableResult
  func reopenDetail() -> Bool {
    accept(destination, focus: .detail, auxiliary: auxiliarySelection)
  }
}
