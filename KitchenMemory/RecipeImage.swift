// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemorySampleData
import SwiftUI

/// A SwiftUI view that displays an image for a recipe, using provided media when available
/// and a generic placeholder when not.
///
/// RecipeImage renders one of two presentations:
/// - When `media` is provided, it loads a sample image resource using the media’s `assetName`,
///   makes it resizable, and applies the specified `contentMode`.
/// - When `media` is `nil`, it renders a placeholder consisting of a subtle fill background and
///   a system “fork.knife” symbol, styled to match the app’s design.
///
/// Accessibility:
/// - The view exposes an accessibility label derived from `media.accessibilityLabel` when available.
/// - If no media is provided, it falls back to a generic, meaningful label: “Recipe image”.
///
/// Styling:
/// - Uses asset colors named “SubtleFill” for the placeholder background and “IconMark” for the
///   placeholder symbol’s foreground style.
/// - The image respects the provided `contentMode` (default `.fill`) via `aspectRatio(contentMode:)`.
///
/// Dependencies:
/// - Expects `RecipeMedia` to provide at least `assetName` and `accessibilityLabel`.
/// - Uses `SampleRecipeCatalog.imageResource(named:)` to resolve bundled sample images.
///
/// Example:
/// ```swift
/// RecipeImage(media: recipe.media, contentMode: .fit)
/// ```
///
/// - Parameters:
///   - media: Optional recipe media describing the image resource and its accessibility label.
///   - contentMode: The content mode applied to the image’s aspect ratio; defaults to `.fill`.
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
    .accessibilityLabel(media?.accessibilityLabel ?? "Recipe image")
  }

}
