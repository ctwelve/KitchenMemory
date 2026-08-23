// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain

/// Builds the generated speech around an authored instruction step.
nonisolated struct RecipeInstructionAccessibilityFormatter {
  let locale: Locale

  func label(number: Int, step: InstructionStep) -> String {
    var parts = [String(localized: "Step \(number).", locale: locale)]
    if let name = step.name {
      parts.append(sentence(name))
    }
    parts.append(sentence(step.text))
    if let duration = step.duration {
      let formatted = RecipePresentationFormatter(locale: locale).duration(duration)
      parts.append(String(localized: "Duration \(formatted).", locale: locale))
    }
    return parts.joined(separator: " ")
  }

  private func sentence(_ text: String) -> String {
    // Separators alone do not reliably create a pause in synthesized speech.
    // Preserve authored punctuation and add a period only when one is absent.
    guard let lastCharacter = text.last, ".!?".contains(lastCharacter) else {
      return "\(text)."
    }
    return text
  }
}
