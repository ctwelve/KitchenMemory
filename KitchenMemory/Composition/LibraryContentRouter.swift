// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct LibraryContentRouter: View {
  @Bindable var libraryModel: RecipeLibraryModel
  @Bindable var sessionModel: CookingSessionPresentationModel
  let applyNavigationFocus: () -> Void
  @Environment(\.locale) private var locale

  var body: some View {
    Group {
      switch libraryModel.navigation.contentDestination {
      case .recipes:
        RecipeLibraryList(model: libraryModel, sessionModel: sessionModel, locale: locale,
                          applyNavigationFocus: applyNavigationFocus, selectSession: { id in
          if sessionModel.selectSession(id) { applyNavigationFocus() }
        })
      case .drafts:
        RecipeDraftsView(model: libraryModel, applyNavigationFocus: applyNavigationFocus)
      case .history:
        CookingSessionHistoryView(model: sessionModel, applyNavigationFocus: applyNavigationFocus)
      case .deletedItems, .recovery:
        LibraryAuxiliaryList(library: libraryModel, sessions: sessionModel, applyNavigationFocus: applyNavigationFocus)
      }
    }
  }
}
