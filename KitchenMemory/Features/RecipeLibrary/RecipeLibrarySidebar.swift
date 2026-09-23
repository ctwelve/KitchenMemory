// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

/// Named library destinations and organization only; recipes live in the content column.
struct RecipeLibrarySidebar: View {
  @Bindable var model: RecipeLibraryModel
  @Bindable var sessionModel: CookingSessionPresentationModel
  let showSessionHistory: () -> Void
  let showDeletedItems: () -> Void
  let showRecovery: () -> Void
  let showDrafts: () -> Void
  let browse: (@escaping () -> Void) -> Void

  @State private var presentation = OrganizationActionPresentation()

  var body: some View {
    List {
      Section {
        Button(.organizationAll, systemImage: "books.vertical") {
          browse {
            model.organization?.showAllRecipes()
          }
        }
        .accessibilityIdentifier("all-recipes-destination")
      }
      sessionSection
      if let organization = model.organization {
        OrganizationSidebar(model: organization, recipes: model.recipes, browse: browse, presentation: presentation)
      }
    }
    .accessibilityIdentifier("recipe-library-shell")
    .accessibilityLabel(Text(.organizationTitle))
    .listStyle(.sidebar)
    .navigationTitle(.organizationTitle)
    .modifier(OrganizationActionDialogs(model: model.organization, presentation: presentation))
  }

  private var sessionSection: some View {
    Section {
      if !model.authoringItems.isEmpty {
        Button(action: showDrafts) {
          Label(.recipeDraftsTitle, systemImage: "square.and.pencil")
            .badge(model.authoringItems.count)
        }
        .accessibilityIdentifier("drafts-destination")
      }
      Button(action: showSessionHistory) {
        Label(.sessionHistoryTitle, systemImage: "clock.arrow.circlepath")
      }
      .accessibilityIdentifier("sessions-destination")

      Button(action: showDeletedItems) {
        Label(.deletedItemsTitle, systemImage: "trash")
          .badge(sessionModel.deletedItemCount + model.deletedRecipes.count)
      }
      .accessibilityIdentifier("deleted-items-destination")

      if sessionModel.showsRecoveryDestination || !model.recoveryRecipes.isEmpty
          || model.organization?.requiresRecovery == true {
        Button(action: showRecovery) {
          Label(.recoveryTitle, systemImage: "wrench.and.screwdriver")
            .badge(
              sessionModel.recoveryItemCount + model.recoveryRecipes.count + (model.organization?.collisionCount ?? 0))
        }
        .accessibilityIdentifier("recovery-destination")
      }
    } header: {
      Text(.sessionDiscoveryTitle)
    }
    .buttonStyle(.borderless)
  }

}
