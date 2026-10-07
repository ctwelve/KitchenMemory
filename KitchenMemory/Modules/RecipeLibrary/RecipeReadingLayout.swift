// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// Composition depends on the actual recipe viewport, including scaled text requirements.
nonisolated struct RecipeReadingLayout {
  enum Section: Hashable { case ingredients, instructions }
  let sideBySide: Bool
  let readingOrder: [Section] = [.ingredients, .instructions]

  init(width: Double, minimumColumnWidth: Double, accessibilityText: Bool) {
    // Two readable columns, a 24-point gap, and the view's 24-point outer insets.
    sideBySide = !accessibilityText && min(width, 1120) >= 2 * minimumColumnWidth + 72
  }
}
