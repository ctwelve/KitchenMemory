// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public extension RecipeEditingDraft {
  /// Applies editable recipe details from a snapshot, retaining the live ingredient state.
  ///
  /// Use a copy of `session` for form bindings. Ingredients, captured source metadata,
  /// language, and classification remain unchanged by this operation.
  /// Frozen Save intentions reject changes. A successful change persists once and does
  /// not retire native ingredient history; unchanged details return `false`.
  @discardableResult
  func updateRecipeDetails(from edited: RecipeEditSession) -> Bool {
    guard pendingSave == nil else { return false }
    var updated = session
    updated.title = edited.title
    updated.summary = edited.summary
    updated.authorName = edited.authorName
    updated.recipeYield = edited.recipeYield
    updated.prepMinutes = edited.prepMinutes
    updated.cookMinutes = edited.cookMinutes
    updated.totalMinutes = edited.totalMinutes
    updated.sourceKind = edited.sourceKind
    updated.sourceTitle = edited.sourceTitle
    updated.sourceAuthor = edited.sourceAuthor
    updated.sourcePublisher = edited.sourcePublisher
    updated.sourceURL = edited.sourceURL
    updated.media = edited.media
    updated.equipment = edited.equipment
    updated.instructionSections = edited.instructionSections
    guard updated != session else { return false }
    session = updated
    return true
  }
}
