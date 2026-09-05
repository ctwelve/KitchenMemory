// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

extension RecipeLibraryModel {
  func stageImports(_ options: [RecipeImportOption]) throws {
    try drafts.stage(options)
  }

  @discardableResult
  func beginImportReview(_ option: RecipeImportOption) -> Bool {
    guard let candidate = drafts.review(option) else { return false }
    editor = presentation(for: candidate)
    return true
  }

  @discardableResult
  func acceptImportCandidate(_ id: UUID) -> Bool {
    guard let candidate = drafts.drafts.first(where: { $0.id == id }) else { return false }
    editor = presentation(for: candidate)
    return drafts.accept(id)
  }
}
