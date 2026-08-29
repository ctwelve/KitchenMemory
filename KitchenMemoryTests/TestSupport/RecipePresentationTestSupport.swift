// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
@testable import KitchenMemory
import KitchenKit

/// Keeps older domain test scenarios readable while routing every presentation
/// assertion through the application-owned, explicitly English formatter.
/// These conveniences exist only in the test module: the domain itself no
/// longer owns English words or punctuation.
private let englishRecipeFormatter = RecipePresentationFormatter(
  locale: Locale(identifier: "en-US")
)

extension RationalQuantity {
  var renderedText: String {
    englishRecipeFormatter.rational(self)
  }
}

extension QuantityExpression {
  var renderedText: String? {
    englishRecipeFormatter.quantity(self)
  }
}

extension RecipeIngredient {
  var effectiveDisplayText: String {
    englishRecipeFormatter.ingredient(self)
  }

  var structuredDisplayText: String? {
    guard hasStructuredDisplayContent else { return nil }
    var copy = self
    copy.presentationMode = .structured
    return englishRecipeFormatter.ingredient(copy)
  }
}
