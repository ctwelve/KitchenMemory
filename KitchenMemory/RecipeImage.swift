// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import SwiftUI

struct RecipeImage: View {
  let media: RecipeMedia?
  var contentMode: ContentMode = .fill

  var body: some View {
    Group {
      if let media {
        Image(SampleRecipeCatalog.imageResource(named: media.assetName))
          .resizable()
          .aspectRatio(contentMode: contentMode)
      } else {
        ZStack {
          Color("SubtleFill")
          Image(systemName: "fork.knife")
            .font(.title2)
            .foregroundStyle(Color("IconMark"))
        }
      }
    }
    // RecipeRow hides its thumbnail because the enclosing link already names
    // the recipe. The detail hero remains exposed, so its imported alt text is
    // useful; the generic fallback still gives the otherwise visual placeholder
    // a meaningful description.
    .accessibilityLabel(media?.accessibilityLabel ?? String(localized: "Recipe image"))
  }

}
