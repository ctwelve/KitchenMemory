// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeGalleryView: View {
  let media: [RecipeMedia]
  private var gallery: [RecipeMedia] { media.filter { $0.role == .gallery } }

  var body: some View {
    if !gallery.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        Text(.recipeMediaGalleryTitle).font(.headline).accessibilityAddTraits(.isHeader)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], alignment: .leading, spacing: 16) {
          ForEach(gallery) { item in
            VStack(alignment: .leading, spacing: 8) {
              if RecipePrivateImage.image(for: item) != nil {
                RecipeImage(media: item, contentMode: .fit)
                  .frame(maxWidth: .infinity).frame(height: 220)
              } else {
                Label(.recipeMediaUnavailable, systemImage: "photo")
                if let description = item.accessibilityLabel, !description.isEmpty {
                  Text(description).foregroundStyle(.secondary)
                }
              }
            }
            .accessibilityIdentifier("recipe-gallery-image-\(item.id.rawValue.uuidString)")
          }
        }
      }
      .accessibilityIdentifier("recipe-gallery")
    }
  }
}
