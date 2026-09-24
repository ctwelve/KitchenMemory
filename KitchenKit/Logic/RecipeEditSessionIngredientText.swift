// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Low-level value operations retained until the public ingredient interface is sealed in #212.
/// Application editors use `RecipeEditingDraft` and `RecipeIngredientTextEditing` so text and
/// structured contents agree before the live draft notifies persistence.
public extension RecipeEditSession {
  /// Opens the simple editor without reinterpreting any maintained content.
  mutating func prepareIngredientText(displayWording: [RecipeIngredient.ID: String] = [:]) {
    if let ingredientText {
      if ingredientText.sections != ingredientSections {
        self.ingredientText = ingredientText.incorporating(ingredientSections, displayWording: displayWording)
      }
    } else {
      ingredientText = RecipeIngredientTextDraft(sections: ingredientSections, displayWording: displayWording)
    }
  }

  /// Commits native text input to the same local draft used by the advanced editor.
  mutating func updateIngredientText(_ text: RecipeIngredientTextDraft) {
    ingredientText = text
    ingredientSections = text.sections
  }

  /// Completes pending lines before a mode switch, Close, or Save.
  mutating func finishIngredientText(locale: Locale = .current) {
    guard ingredientText != nil else { return }
    prepareIngredientText()
    guard var text = ingredientText else { return }
    text.finishEditing(locale: locale)
    updateIngredientText(text)
  }
}
