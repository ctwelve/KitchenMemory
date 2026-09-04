// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI
import KitchenKit

struct RecipeDraftsView: View {
  @Bindable var model: RecipeLibraryModel

  var body: some View {
    List(model.authoringItems) { draft in
      Button { model.resumeEditingDraft(draft.id) } label: {
        VStack(alignment: .leading) {
          if draft.session.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(.recipeDraftsUntitled)
          } else {
            Text(draft.session.title)
          }
          Text(draft.isImportCandidate ? .recipeImportCandidateLocalNote : .recipeDraftsLocalNote)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .accessibilityIdentifier("draft-row-\(draft.id.uuidString)")
    }
    .navigationTitle(.recipeDraftsTitle)
    .accessibilityIdentifier("recipe-drafts")
  }
}
