// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeLibrarySidebar: View {
  @Bindable var model: RecipeLibraryModel
  @Bindable var sessionModel: CookingSessionPresentationModel
  let locale: Locale
  let showSessionHistory: () -> Void
  let showDeletedItems: () -> Void
  let showRecovery: () -> Void
  let showDrafts: () -> Void
  let selectSession: (CookingSession.ID) -> Void

  var body: some View {
    List(selection: recipeSelection) {
      sessionSection
      recipeSection
    }
    // This identifies the durable shell itself; a ready-only section marker
    // separately prevents launch helpers from mistaking startup for readiness.
    .accessibilityIdentifier("recipe-library-shell")
    .accessibilityLabel(Text(.libraryAccessibilityLabel))
    .listStyle(.sidebar)
    .onChange(of: model.recipes.map(\.recipe.id), initial: true) { _, recipeIDs in
      sessionModel.refreshSidebarAssociations(for: recipeIDs)
    }
    .onChange(of: sessionModel.sessions.map(\.id)) { _, _ in
      sessionModel.refreshSidebarAssociations(for: model.recipes.map(\.recipe.id))
    }
    .overlay {
      if !model.hasLoaded { ProgressView(.libraryLoading) }
    }
  }

  private var recipeSelection: Binding<Recipe.ID?> {
    Binding(get: { model.navigation.destination == .recipe ? model.selectedRecipeID : nil },
            set: { model.selectRecipeForReading($0) })
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
          .badge(sessionModel.deletedItemCount)
      }
      .accessibilityIdentifier("deleted-items-destination")

      if sessionModel.showsRecoveryDestination {
        Button(action: showRecovery) {
          Label(.recoveryTitle, systemImage: "wrench.and.screwdriver")
            .badge(sessionModel.recoveryItemCount)
        }
        .accessibilityIdentifier("recovery-destination")
      }
    } header: {
      Text(.sessionDiscoveryTitle)
    }
  }

  @ViewBuilder
  private var recipeSection: some View {
    Section {
      if let issue = model.issue {
        unavailableLibrary(issue)
      } else if model.hasLoaded, model.recipes.isEmpty {
        emptyLibrary
      } else {
        ForEach(model.recipes, id: \.recipe.id) { storedRecipe in
          NavigationLink(value: storedRecipe.recipe.id) {
            RecipeRow(storedRecipe: storedRecipe)
          }
          .accessibilityIdentifier("recipe-row-\(storedRecipe.recipe.id.rawValue.uuidString)")
          ForEach(sessionModel.sidebarSessions(for: storedRecipe.recipe.id), id: \.id) { session in
            Button {
              selectSession(session.id)
            } label: {
              CookingSessionRow(session: session)
                .padding(.leading, 24)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("session-row-\(session.id.rawValue.uuidString)")
          }
        }
      }
    } header: {
      Text(.sessionDiscoveryRecipes)
        .accessibilityIdentifier("recipe-library-ready")
    }
  }

  private func unavailableLibrary(_ issue: RecipeLibraryIssue) -> some View {
    ContentUnavailableView {
      Label(.libraryUnavailableTitle, systemImage: "exclamationmark.triangle")
    } description: {
      Text(issue.message(locale: locale))
    } actions: {
      Button(.actionTryAgain) { model.retryCurrentIssue() }
    }
  }

  private var emptyLibrary: some View {
    ContentUnavailableView(
      .libraryEmptyTitle,
      systemImage: "book.closed",
      description: Text(.libraryEmptyMessage)
    )
  }
}

struct CookingSessionRow: View {
  let session: CookingSessionProjection

  var body: some View {
    let lifecycle = CookingSessionLifecyclePresentation(session.lifecycle)
    HStack {
      VStack(alignment: .leading, spacing: 3) {
        Text(session.snapshot.title)
          .font(.headline)
        Text(lifecycle.title)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: lifecycle.symbol)
        .accessibilityHidden(true)
    }
  }
}

struct RecipeRow: View {
  let storedRecipe: StoredRecipe

  var body: some View {
    HStack(spacing: 12) {
      RecipeImage(
        media: storedRecipe.revision.media.first { $0.role == .thumbnail }
          ?? storedRecipe.revision.media.first,
        contentMode: .fill
      )
      .frame(width: 56, height: 56)
      .clipShape(.rect(cornerRadius: 10))
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 3) {
        Text(storedRecipe.revision.title)
          .font(.headline)
        if let summary = storedRecipe.revision.summary {
          Text(summary)
            .font(.caption)
            .foregroundStyle(.primary)
        }
      }
    }
    .padding(.vertical, 4)
  }
}
