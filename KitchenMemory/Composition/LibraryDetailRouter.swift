// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct LibraryDetailRouter: View {
  @Bindable var libraryModel: RecipeLibraryModel
  @Bindable var sessionModel: CookingSessionPresentationModel
  let editRecipe: (StoredRecipe) -> Void

  @ViewBuilder
  var body: some View {
    if let finishedSession = sessionModel.observedFinishedSession {
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
                  sessionModel.showRecipeSessionHistory(for: selectedRecipe.recipe.id)
                }
              )
            } label: {
              Label(.sessionHistoryRecipeTitle, systemImage: "clock.arrow.circlepath")
            }
            .accessibilityIdentifier("recipe-session-history")
          }
          ToolbarItem(placement: .primaryAction) {
            Button { sessionModel.start(from: selectedRecipe) } label: {
              Label(.sessionActionStart, systemImage: "flame")
            }
            .accessibilityIdentifier("start-cooking")
          }
          ToolbarItem(placement: .primaryAction) {
            Button { editRecipe(selectedRecipe) } label: {
              Label(.recipeActionEdit, systemImage: "pencil")
            }
            .accessibilityIdentifier("edit-recipe")
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
