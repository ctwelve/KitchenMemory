// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryPersistence
import SwiftUI

struct ContentView: View {
  @Bindable var model: RecipeLibraryModel

  var body: some View {
    NavigationSplitView {
      recipeList
        .navigationTitle("Recipes")
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 240, ideal: 300)
#endif
    } detail: {
      detail
    }
    .task {
      model.loadIfNeeded()
    }
    .tint(Color("AccentColor"))
  }

  @ViewBuilder
  private var recipeList: some View {
    if let errorMessage = model.errorMessage {
      ContentUnavailableView {
        Label("Recipes Unavailable", systemImage: "exclamationmark.triangle")
      } description: {
        Text(errorMessage)
      } actions: {
        Button("Try Again") { model.reload() }
      }
    } else if model.hasLoaded && model.recipes.isEmpty {
      ContentUnavailableView(
        "No Recipes",
        systemImage: "book.closed",
        description: Text("Recipes saved to this Kitchen will appear here.")
      )
    } else {
      List(model.recipes, id: \.recipe.id, selection: $model.selectedRecipeID) { storedRecipe in
        NavigationLink(value: storedRecipe.recipe.id) {
          RecipeRow(storedRecipe: storedRecipe)
        }
        .accessibilityIdentifier("recipe-row-\(storedRecipe.recipe.id.rawValue.uuidString)")
      }
      .accessibilityIdentifier("recipe-library")
      .accessibilityLabel("Recipe library")
      .listStyle(.sidebar)
      .overlay {
        if !model.hasLoaded {
          ProgressView("Loading Recipes")
        }
      }
    }
  }

  @ViewBuilder
  private var detail: some View {
    if let selectedRecipe = model.selectedRecipe {
      RecipeDetailView(storedRecipe: selectedRecipe)
        .id(selectedRecipe.recipe.id)
    } else {
      ContentUnavailableView(
        "Select a Recipe",
        systemImage: "book.pages",
        description: Text("Choose a recipe to read its ingredients and instructions.")
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color("AppBackground"))
    }
  }
}

private struct RecipeRow: View {
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

#Preview {
  ContentView(model: AppDependencies.preview.libraryModel)
}
