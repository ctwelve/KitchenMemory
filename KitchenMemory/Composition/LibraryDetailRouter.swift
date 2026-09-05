// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct LibraryDetailRouter: View {
  @Bindable var libraryModel: RecipeLibraryModel
  @Bindable var sessionModel: CookingSessionPresentationModel
  var presentsEditor = true
  private var actions: LibraryCommandActions {
    LibraryCommandActions(library: libraryModel, sessions: sessionModel)
  }

  @ViewBuilder
  var body: some View {
    switch libraryModel.navigation.destination {
    case .editor:
      if presentsEditor, let editor = libraryModel.editor {
        RecipeEditingDestination(model: libraryModel, editor: editor)
      }
    case .drafts:
      RecipeDraftsView(model: libraryModel)
    case .finished:
      if let finishedSession = sessionModel.observedFinishedSession {
        FinishedCookingSessionView(model: sessionModel, session: finishedSession)
      }
    case .deletedItems:
      CookingSessionDeletedItemsView(model: sessionModel)
    case .recovery:
      CookingSessionRecoveryView(model: sessionModel)
    case .history, .session(_, history: .some):
      CookingSessionHistoryView(model: sessionModel)
    case .session:
      if let session = sessionModel.currentSession {
        CookingSessionView(model: sessionModel, session: session, embedsInNavigationStack: false)
      }
    case .recipe:
      recipeContent
    }
  }

  @ViewBuilder
  private var recipeContent: some View {
    if let selectedRecipe = libraryModel.selectedRecipe {
      RecipeDetailView(storedRecipe: selectedRecipe)
        .id(selectedRecipe.revision.id)
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button { actions.perform(.recipeHistory) } label: {
              Label(.sessionHistoryRecipeTitle, systemImage: "clock.arrow.circlepath")
            }
            .accessibilityIdentifier("recipe-session-history")
            .help(Text(.sessionHistoryRecipeTitle))
            .disabled(!actions.canPerform(.recipeHistory))
          }
          ToolbarItem(placement: .primaryAction) {
            Button { actions.perform(.startCooking) } label: {
              Label(.sessionActionStart, systemImage: "flame")
            }
            .accessibilityIdentifier("start-cooking")
            .help(Text(.sessionActionStart))
            .disabled(!actions.canPerform(.startCooking))
          }
          ToolbarItem(placement: .primaryAction) {
            Button { actions.perform(.editRecipe) } label: {
              Label(.recipeActionEdit, systemImage: "pencil")
            }
            .accessibilityIdentifier("edit-recipe")
            .help(Text(.recipeActionEdit))
            .disabled(!actions.canPerform(.editRecipe))
          }
        }
    } else {
      ContentUnavailableView(
        .librarySelectionEmptyTitle,
        systemImage: "book.pages",
        description: Text(.librarySelectionEmptyMessage)
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color("AppBackground"))
    }
  }
}
