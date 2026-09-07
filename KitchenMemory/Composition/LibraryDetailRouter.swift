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
      CookingSessionDeletedItemsView(recipeCount: libraryModel.deletedRecipes.count, model: sessionModel) {
        RecipeDeletedItemsSection(model: libraryModel)
      }
    case .recovery:
      CookingSessionRecoveryView(recipeCount: libraryModel.recoveryRecipes.count + (libraryModel.organization?.collisionCount ?? 0),
                                 recipeContent: {
        RecipeRecoverySection(model: libraryModel)
        if let organization = libraryModel.organization { OrganizationCollisionsView(model: organization) }
      }, model: sessionModel)
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
        .safeAreaInset(edge: .top, alignment: .leading) {
          if let organization = libraryModel.organization {
            RecipeOrganizationSummary(model: organization, recipeID: selectedRecipe.id).padding(.horizontal)
          }
        }
        .modifier(RecipeDeletionPresentation(model: libraryModel, recipe: selectedRecipe))
        .toolbar {
          if let organization = libraryModel.organization {
            ToolbarItem(placement: .primaryAction) {
              Menu(.organizationTitle, systemImage: "folder") {
                RecipeOrganizationMenus(model: organization, recipeIDs: [selectedRecipe.id])
              }
            }
            ToolbarItem(placement: .secondaryAction) { OrganizationManagementButton(model: organization) }
          }
          if let comparison = libraryModel.reconciliations.first(where: { $0.recipeID == selectedRecipe.id }) {
            ToolbarItem(placement: .primaryAction) {
              Button { libraryModel.beginReconciliation(comparison) } label: {
                Label(.recipeComparisonTitle, systemImage: "arrow.triangle.branch")
              }
            }
          }
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
