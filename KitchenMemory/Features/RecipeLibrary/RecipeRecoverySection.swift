// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeRecoverySection: View {
  @Bindable var model: RecipeLibraryModel
  @State private var candidate: RecipeRevision?
  @State private var failed = false

  var body: some View {
    ForEach(model.recoveryRecipes) { item in
      VStack(alignment: .leading, spacing: 12) {
        Text(.recipeRecoveryTitle).font(.headline)
        Text(.recipeRecoveryExplanation).foregroundStyle(.secondary)
        ForEach(item.revisions) { revision in
          Button { candidate = revision } label: {
            VStack(alignment: .leading) {
              Text(revision.title)
              Text(.recipeRecoveryNewDraft).font(.caption)
            }
          }
        }
        Button(.actionTryAgain) { model.reload() }
      }
      .padding(16)
      .background(Color("ContentSurface"), in: .rect(cornerRadius: 12))
      .accessibilityElement(children: .contain)
    }
    .confirmationDialog(.recipeRecoveryConfirmation, isPresented: Binding(
      get: { candidate != nil }, set: { if !$0 { candidate = nil } }
    ), titleVisibility: .visible) {
      Button(.recipeRecoveryNewDraft) {
        if let candidate { recover(candidate) }
        candidate = nil
      }
      Button(.actionCancel, role: .cancel) { candidate = nil }
    } message: { Text(.recipeRecoveryLossWarning) }
    .alert(.recipeRecoveryUnavailable, isPresented: $failed) {
      Button(.actionCancel, role: .cancel) {}
    } message: { Text(.recipeRecoveryRetry) }
  }

  private func recover(_ revision: RecipeRevision) {
    guard model.navigation.canLeave() else { return }
    do {
      let draft = try model.drafts.beginRecovery(recipeID: revision.recipeID, revisionID: revision.id)
      model.navigation.move(to: .editor(draft.id))
    } catch { failed = true }
  }
}
