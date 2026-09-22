// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct LibraryAuxiliaryDetail: View {
  let library: RecipeLibraryModel
  let sessions: CookingSessionPresentationModel

  @ViewBuilder var body: some View {
    switch library.navigation.auxiliarySelection {
    case .deletedRecipe(let id):
      CookingSessionDeletedItemsView(recipeCount: 1, model: sessions, recipeContent: {
        RecipeDeletedItemsSection(model: library, selectedID: id)
      }, includesSessions: false)
    case .deletedSession(let id):
      CookingSessionDeletedItemsView(recipeCount: 0, model: sessions, recipeContent: { EmptyView() }, selectedID: id)
    case .recoveryRecipe(let id):
      CookingSessionRecoveryView(recipeCount: 1, recipeContent: {
        RecipeRecoverySection(model: library, selectedID: id)
      }, model: sessions, includesSessions: false)
    case .recoverySession(let id):
      CookingSessionRecoveryView(recipeCount: 0, recipeContent: { EmptyView() }, model: sessions, selectedID: id)
    case .organization:
      if let organization = library.organization {
        ScrollView { OrganizationCollisionsView(model: organization).padding() }
      }
    case nil:
      ContentUnavailableView(.librarySelectionEmptyTitle, systemImage: "sidebar.left",
                             description: Text(.librarySelectionEmptyMessage))
    }
  }
}
