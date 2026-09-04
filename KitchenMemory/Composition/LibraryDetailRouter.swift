// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct LibraryDetailRouter: View {
  @Bindable var libraryModel: RecipeLibraryModel
  @Bindable var sessionModel: CookingSessionPresentationModel
  private var actions: LibraryCommandActions {
    LibraryCommandActions(library: libraryModel, sessions: sessionModel)
  }

  @ViewBuilder
  var body: some View {
    if libraryModel.isShowingDrafts {
      RecipeDraftsView(model: libraryModel)
    } else if let finishedSession = sessionModel.observedFinishedSession {
      FinishedCookingSessionView(model: sessionModel, session: finishedSession)
    } else if sessionModel.isShowingDeletedItems {
      CookingSessionDeletedItemsView(model: sessionModel)
    } else if sessionModel.isShowingRecovery {
      CookingSessionRecoveryView(model: sessionModel)
    } else if sessionModel.isShowingSessionHistory {
      CookingSessionHistoryView(model: sessionModel)
    } else if let selectedRecipe = libraryModel.selectedRecipe {
      RecipeDetailView(storedRecipe: selectedRecipe)
        .id(selectedRecipe.revision.id)
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            NavigationLink {
              CookingSessionHistoryDestinationView(
                model: sessionModel,
                prepare: {
                  actions.perform(.recipeHistory)
                }
              )
            } label: {
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
