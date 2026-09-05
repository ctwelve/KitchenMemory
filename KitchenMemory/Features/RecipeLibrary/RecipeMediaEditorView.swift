// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI
import UniformTypeIdentifiers

struct RecipeMediaEditorView: View {
  @Binding var session: RecipeEditSession
  @State private var selectsImage = false
  @State private var importFailed = false

  var body: some View {
    Section(.recipeMediaHeroTitle) {
      if let hero = session.media?.first(where: { $0.role == .hero }) {
        RecipeImage(media: hero, contentMode: .fit)
          .frame(maxHeight: 240)
        EditorTextField(.recipeMediaDescription, text: Binding(
          get: { hero.accessibilityLabel ?? "" },
          set: { value in
            guard let index = session.media?.firstIndex(where: { $0.id == hero.id }) else { return }
            session.media?[index].accessibilityLabel = value.isEmpty ? nil : value
          }
        ), multiline: true)
        Button(.recipeMediaRemoveHero, role: .destructive) {
          session.media = (session.media ?? []).filter { $0.role != .hero }
        }
        .accessibilityIdentifier("recipe-media-remove-hero")
      }
      Button(.recipeMediaChooseHero, systemImage: "photo") { selectsImage = true }
        .accessibilityIdentifier("recipe-media-choose-hero")
      if importFailed {
        Label(.recipeMediaImportFailure, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.secondary)
      }
    }
    .fileImporter(isPresented: $selectsImage, allowedContentTypes: [.image]) { result in
      do {
        let data = try RecipePrivateImage.importedData(from: result.get())
        session.media = (session.media ?? []).filter { $0.role != .hero }
          + [RecipeMedia(role: .hero, imageData: data)]
        importFailed = false
      } catch {
        importFailed = true
      }
    }
  }
}
