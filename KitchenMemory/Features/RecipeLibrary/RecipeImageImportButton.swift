// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI
import UniformTypeIdentifiers

struct RecipeImageImportButton: View {
  let title: LocalizedStringResource
  let allowsMultipleSelection: Bool
  let accept: ([Data]) -> Void
  @State private var selectsImage = false
  @State private var importFailed = false

  var body: some View {
    Button(title, systemImage: "photo") { selectsImage = true }
      .fileImporter(isPresented: $selectsImage, allowedContentTypes: [.image],
                    allowsMultipleSelection: allowsMultipleSelection) { result in
        do {
          let images = try result.get().map(RecipePrivateImage.importedData)
          accept(images)
          importFailed = false
        } catch {
          importFailed = true
        }
      }
    if importFailed {
      Label(.recipeMediaImportFailure, systemImage: "exclamationmark.triangle")
        .foregroundStyle(.secondary)
    }
  }
}
