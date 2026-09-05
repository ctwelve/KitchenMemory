// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

/// A missing image occupies no space above the Recipe's textual header.
struct RecipeHeroImage: View {
  let media: RecipeMedia?

  var body: some View {
    if let media, let image = RecipePrivateImage.image(for: media) {
      RecipeImage(media: media, contentMode: .fill, resolvedImage: image)
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical) { length, _ in
          min(max(length * 0.34, 240), 420)
        }
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
          RoundedRectangle(cornerRadius: 20)
            .stroke(Color("SubtleBorder"), lineWidth: 1)
        }
    }
  }
}
