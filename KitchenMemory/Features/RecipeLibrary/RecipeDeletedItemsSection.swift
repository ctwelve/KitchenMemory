// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeDeletedItemsSection: View {
  @Bindable var model: RecipeLibraryModel
  @State private var pendingRestore: RecipeRestoreCommand?

  var body: some View {
    ForEach(model.deletedRecipes) { item in
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 4) {
          if let recipe = item.recoverableRecipe {
            Text(recipe.current.title).font(.headline)
            Text(.recipeDeletedLabel).font(.caption).foregroundStyle(.secondary)
          } else {
            Text(.recipeDeletedFallback).font(.headline)
            Text(message(for: item)).foregroundStyle(.secondary)
          }
        }
        Spacer()
        if item.recoverableRecipe != nil {
          Button(.recipeActionRestore) {
            pendingRestore = try? model.library.prepareRestoration(of: item)
          }
          .disabled(model.pendingDisposition != nil)
          .accessibilityIdentifier("restore-recipe-\(item.id.rawValue.uuidString)")
        } else if let comparison = model.reconciliations.first(where: { $0.recipeID == item.id }) {
          Button(.recipeComparisonTitle) { model.beginReconciliation(comparison) }
        } else {
          Button(.actionTryAgain) { model.reload() }
        }
      }
      .padding(16)
      .background(Color("ContentSurface"), in: .rect(cornerRadius: 12))
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("deleted-recipe-\(item.id.rawValue.uuidString)")
    }
    .confirmationDialog(
      .recipeRestoreConfirmation,
      isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
      titleVisibility: .visible
    ) {
      Button(.recipeActionRestore) {
        if let pendingRestore { model.restoreRecipe(pendingRestore) }
        pendingRestore = nil
      }
      Button(.actionCancel, role: .cancel) { pendingRestore = nil }
    }
  }

  private func message(for item: DeletedRecipe) -> LocalizedStringResource {
    if case .unavailable = item.authority { return .recipeDeletedWaiting }
    return .recipeDeletedRecovery
  }
}

struct RecipeDeletionPresentation: ViewModifier {
  @Bindable var model: RecipeLibraryModel
  let recipe: StoredRecipe
  @State private var pendingDelete: RecipeDeleteCommand?

  func body(content: Content) -> some View {
    content
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(role: .destructive) {
            pendingDelete = model.library.prepareDeletion(of: recipe.id)
          } label: {
            Label(.recipeActionDelete, systemImage: "trash")
          }
          .disabled(model.pendingDisposition != nil)
          .accessibilityIdentifier("delete-recipe")
        }
      }
      .confirmationDialog(
        .recipeDeleteConfirmation,
        isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
        titleVisibility: .visible
      ) {
        Button(.recipeActionDelete, role: .destructive) {
          if let pendingDelete { model.deleteRecipe(pendingDelete) }
          pendingDelete = nil
        }
        Button(.actionCancel, role: .cancel) { pendingDelete = nil }
      } message: {
        Text(.recipeDeleteMessage)
      }
  }
}
