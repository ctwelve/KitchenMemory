// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI
import UniformTypeIdentifiers

struct RecipeMediaEditorView: View {
  @Binding var session: RecipeEditSession

  var body: some View {
    Section(.recipeMediaHeroTitle) {
      if let hero = session.media?.first(where: { $0.role == .hero }) {
        RecipeImage(media: hero, contentMode: .fit)
          .frame(maxHeight: 240)
        EditorTextField(.recipeMediaDescription, text: Binding(
          get: { hero.accessibilityLabel ?? "" },
          set: { value in
            session.setMediaDescription(value, for: hero.id)
          }
        ), multiline: true)
        Button(.recipeMediaRemoveHero, role: .destructive) {
          session.removeHeroImage()
        }
        .accessibilityIdentifier("recipe-media-remove-hero")
      }
      RecipeImageImportButton(title: .recipeMediaChooseHero, allowsMultipleSelection: false) { images in
        guard let data = images.first else { return }
        session.replaceHeroImage(with: data)
      }
      .accessibilityIdentifier("recipe-media-choose-hero")
    }
    RecipeGalleryEditorView(session: $session)
  }
}
