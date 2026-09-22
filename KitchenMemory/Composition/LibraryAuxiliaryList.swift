// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

/// Lists only identities and status. Existing detail surfaces own confirmation
/// and recovery operations, so a selection cannot itself restore or repair data.
struct LibraryAuxiliaryList: View {
  let library: RecipeLibraryModel
  let sessions: CookingSessionPresentationModel
  let focusDetail: () -> Void
  private var isDeleted: Bool { library.navigation.contentDestination == .deletedItems }

  var body: some View {
    List {
      Section {
        if isDeleted { deletedRows } else { recoveryRows }
      } header: {
        Text(isDeleted ? .deletedItemsTitle : .recoveryTitle)
          .accessibilityIdentifier(isDeleted ? "deleted-items" : "session-recovery")
      }
    }
    .listStyle(.plain)
    .navigationTitle(isDeleted ? .deletedItemsTitle : .recoveryTitle)
  }

  @ViewBuilder private var deletedRows: some View {
    ForEach(library.deletedRecipes) { recipe in
      row(.deletedRecipe(recipe.id), title: recipe.recoverableRecipe?.current.title
          ?? String(localized: .recipeDeletedFallback), symbol: "book.closed")
    }
    ForEach(sessions.deletedSessions, id: \.id) { session in
      row(.deletedSession(session.id), title: session.snapshot.title, symbol: "flame")
    }
    ForEach(sessions.waitingDeletedSessions, id: \.evidence.sessionID) { item in
      row(.deletedSession(item.evidence.sessionID), title: String(localized: .deletedItemsWaiting),
          symbol: "icloud.and.arrow.down")
    }
    if library.deletedRecipes.isEmpty, sessions.deletedItemCount == 0 {
      ContentUnavailableView(.deletedItemsEmptyTitle, systemImage: "trash",
                             description: Text(.deletedItemsEmptyMessage))
    }
  }

  @ViewBuilder private var recoveryRows: some View {
    ForEach(library.recoveryRecipes) { recipe in
      row(.recoveryRecipe(recipe.id), title: recipe.revisions.first?.title
          ?? String(localized: .recipeRecoveryTitle), symbol: "book.closed")
    }
    ForEach(sessions.waitingSessions, id: \.evidence.sessionID) { item in
      row(.recoverySession(item.evidence.sessionID), title: String(localized: .recoveryWaitingTitle),
          symbol: "icloud.and.arrow.down")
    }
    ForEach(sessions.recoverySessions, id: \.evidence.sessionID) { item in
      row(.recoverySession(item.evidence.sessionID), title: String(localized: .recoveryEvidenceTitle),
          symbol: "exclamationmark.triangle")
    }
    if library.organization?.requiresRecovery == true {
      row(.organization, title: String(localized: .organizationTitle), symbol: "folder.badge.questionmark")
    }
    if library.recoveryRecipes.isEmpty, sessions.recoveryItemCount == 0,
       library.organization?.requiresRecovery != true {
      ContentUnavailableView(.recoveryEmptyTitle, systemImage: "wrench.and.screwdriver",
                             description: Text(.recoveryEmptyMessage))
    }
  }

  private func row(_ item: RecipeLibraryNavigation.AuxiliarySelection, title: String, symbol: String) -> some View {
    Button {
      if library.navigation.selectAuxiliary(item) { focusDetail() }
    } label: {
      Label(title, systemImage: symbol).frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityAddTraits(library.navigation.auxiliarySelection == item ? .isSelected : [])
  }
}
