// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeGalleryEditorView: View {
  @Binding var session: RecipeEditSession
  private var gallery: [RecipeMedia] { (session.media ?? []).filter { $0.role == .gallery } }

  var body: some View {
    Section(.recipeMediaGalleryTitle) {
      ForEach(Array(gallery.enumerated()), id: \.element.id) { index, media in
        VStack(alignment: .leading, spacing: 12) {
          RecipeImage(media: media, contentMode: .fit).frame(maxHeight: 240)
          EditorTextField(.recipeMediaDescription, text: Binding(
            get: { media.accessibilityLabel ?? "" },
            set: { value in
              session.setMediaDescription(value, for: media.id)
            }
          ), multiline: true)
          ViewThatFits(in: .horizontal) {
            HStack { actions(for: media, at: index) }
            VStack(alignment: .leading) { actions(for: media, at: index) }
          }
          .buttonStyle(.borderless)
        }
        .accessibilityIdentifier("recipe-gallery-editor-\(media.id.rawValue.uuidString)")
      }
      RecipeImageImportButton(title: .recipeMediaGalleryAdd, allowsMultipleSelection: true) { images in
        session.addGalleryImages(images)
      }
      .accessibilityIdentifier("recipe-gallery-add")
    }
  }

  @ViewBuilder private func actions(for media: RecipeMedia, at index: Int) -> some View {
    Button(.actionMoveUp) { session.moveGalleryImage(at: index, by: -1) }.disabled(index == 0)
    Button(.actionMoveDown) { session.moveGalleryImage(at: index, by: 1) }.disabled(index == gallery.count - 1)
    Button(.recipeMediaGalleryRemove, role: .destructive) {
      session.removeMedia(id: media.id)
    }
  }
}
