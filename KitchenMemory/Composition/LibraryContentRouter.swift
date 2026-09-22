// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct LibraryContentRouter: View {
  @Bindable var libraryModel: RecipeLibraryModel
  @Bindable var sessionModel: CookingSessionPresentationModel
  let focusDetail: () -> Void
  @Environment(\.locale) private var locale

  var body: some View {
    Group {
      switch libraryModel.navigation.contentDestination {
      case .recipes:
        RecipeLibraryList(model: libraryModel, sessionModel: sessionModel, locale: locale,
                          focusDetail: focusDetail, selectSession: { id in
          if sessionModel.selectSession(id) { focusDetail() }
        })
      case .drafts:
        RecipeDraftsView(model: libraryModel, focusDetail: focusDetail)
      case .history:
        CookingSessionHistoryView(model: sessionModel, focusDetail: focusDetail)
      case .deletedItems, .recovery:
        LibraryAuxiliaryList(library: libraryModel, sessions: sessionModel, focusDetail: focusDetail)
      }
    }
  }
}
