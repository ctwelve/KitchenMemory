// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

extension RecipeLibraryModel {
  /// Staging preserves all candidates before the fetch surface can disappear.
  func stageImports(_ options: [RecipeImportOption]) throws {
    guard editingStorageIsAvailable else { throw FileRecipeEditingStore.Failure.invalidDocument }
    let retained = authoringItems
    for option in options {
      let identifier = try option.retentionIdentifier()
      guard !authoringItems.contains(where: { $0.importIdentifier == identifier }) else { continue }
      let candidate = RecipeEditingModel(
        draft: option.draft, concerns: option.concerns, phase: .importCandidate
      )
      candidate.importIdentifier = identifier
      observeEditingDraft(candidate)
      authoringItems.append(candidate)
    }
    guard persistEditingDrafts() else {
      authoringItems = retained
      throw CocoaError(.fileWriteUnknown)
    }
  }

  @discardableResult
  func beginImportReview(_ option: RecipeImportOption) -> Bool {
    do {
      try stageImports([option])
      let identifier = try option.retentionIdentifier()
      editor = authoringItems.first { $0.importIdentifier == identifier }
      return editor != nil
    } catch {
      editingStorageFailed = true
      return false
    }
  }

  /// The same local identity crosses the acceptance boundary atomically.
  @discardableResult
  func acceptImportCandidate(_ id: UUID) -> Bool {
    guard let candidate = authoringItems.first(where: { $0.id == id }) else { return false }
    editor = candidate
    guard candidate.isImportCandidate else { return true }
    let retainedPhase = candidate.phase
    candidate.phase = candidate.phase.acceptingImport()
    guard persistEditingDrafts() else {
      candidate.phase = retainedPhase
      return false
    }
    return true
  }

}
