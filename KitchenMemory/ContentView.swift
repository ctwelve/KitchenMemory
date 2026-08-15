// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryApplication
import KitchenMemoryDomain
import KitchenMemoryPersistence
import SwiftUI

struct ContentView: View {
  @Bindable var model: RecipeLibraryModel
  @State private var activeSheet: ActiveRecipeSheet?

  var body: some View {
    NavigationSplitView {
      recipeList
        .navigationTitle("Recipes")
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 240, ideal: 300)
#endif
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button {
              activeSheet = .create
            } label: {
              Label("New Recipe", systemImage: "plus")
            }
            .accessibilityIdentifier("new-recipe")
          }
          ToolbarItem(placement: .primaryAction) {
            Button {
              activeSheet = .importURL
            } label: {
              Label("Import Recipe", systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("import-recipe")
          }
        }
    } detail: {
      detail
    }
    .task {
      model.loadIfNeeded()
    }
    .sheet(item: $activeSheet) { sheet in
      sheetContent(sheet)
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
        // Keep the stable identity on the interactive NavigationLink, not on
        // RecipeRow's visual children. UI tests and assistive technologies
        // must activate the same element a person clicks to open the recipe.
        .accessibilityIdentifier("recipe-row-\(storedRecipe.recipe.id.rawValue.uuidString)")
      }
      // This identifier is also our launch-complete signal in UI tests. It is
      // applied to the List itself so it survives row reuse and empty states.
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
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button { activeSheet = .edit(selectedRecipe) } label: {
              Label("Edit", systemImage: "pencil")
            }
              .accessibilityIdentifier("edit-recipe")
          }
        }
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

  @ViewBuilder
  private func sheetContent(_ sheet: ActiveRecipeSheet) -> some View {
    switch sheet {
    case .create:
      RecipeEditorView(mode: .create) { draft in
        model.createRecipe(from: draft)
      }
    case .edit(let storedRecipe):
      RecipeEditorView(mode: .revise, draft: RecipeDraft(revision: storedRecipe.revision)) { draft in
        model.reviseRecipe(id: storedRecipe.recipe.id, from: draft)
      }
    case .importURL:
      RecipeURLImportView(
        load: { url in try await model.importRecipe(from: url) },
        select: { activeSheet = .review($0) }
      )
    case .review(let option):
      RecipeEditorView(
        mode: .importReview,
        draft: option.draft,
        reviewConcerns: option.concerns
      ) { draft in
        model.createRecipe(from: draft)
      }
    }
  }
}

private enum ActiveRecipeSheet: Identifiable {
  case create
  case edit(StoredRecipe)
  case importURL
  case review(RecipeImportOption)

  var id: String {
    switch self {
    case .create: "create"
    case .edit(let recipe): "edit-\(recipe.recipe.id.rawValue.uuidString)"
    case .importURL: "import-url"
    case .review(let option):
      "review-\(option.id.blockIndex)-\(option.id.objectIndex)"
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
      // The image repeats the recipe represented by the NavigationLink. If it
      // remained exposed, VoiceOver would announce an extra image before the
      // title without adding information or an independent action.
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
