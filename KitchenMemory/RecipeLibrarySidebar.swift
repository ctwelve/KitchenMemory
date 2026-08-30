// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeLibrarySidebar: View {
  @Bindable var model: RecipeLibraryModel
  @Bindable var sessionModel: CookingSessionPresentationModel
  let locale: Locale

  var body: some View {
    if sessionModel.sessions.isEmpty, let issue = model.issue {
      unavailableLibrary(issue)
    } else if sessionModel.sessions.isEmpty, model.hasLoaded, model.recipes.isEmpty {
      emptyLibrary
    } else {
      List(selection: $model.selectedRecipeID) {
        sessionSection
        recipeSection
      }
      // This identifier is also our launch-complete signal in UI tests. It is
      // applied to the List itself so it survives row reuse and empty states.
      .accessibilityIdentifier("recipe-library")
      .accessibilityLabel(Text(.libraryAccessibilityLabel))
      .listStyle(.sidebar)
      .overlay {
        if !model.hasLoaded { ProgressView(.libraryLoading) }
      }
    }
  }

  @ViewBuilder
  private var sessionSection: some View {
    if !sessionModel.sessions.isEmpty {
      Section {
        ForEach(sessionModel.sessions, id: \.id) { session in
          Button {
            sessionModel.selectSession(session.id)
          } label: {
            CookingSessionRow(session: session)
          }
          .buttonStyle(.borderless)
          .accessibilityIdentifier("session-row-\(session.id.rawValue.uuidString)")
        }
      } header: {
        Text(.sessionDiscoveryTitle)
      }
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
        }
      }
    } header: {
      Text(.sessionDiscoveryRecipes)
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

private struct CookingSessionRow: View {
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
