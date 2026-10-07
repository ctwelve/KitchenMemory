// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

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
          .lineLimit(2)
        if let summary = storedRecipe.revision.summary {
          Text(summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
    }
    .padding(.vertical, 4)
  }
}
