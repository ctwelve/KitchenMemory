// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation
import KitchenKit

extension RecipeLibraryModel {
  /// Staging preserves all candidates before the fetch surface can disappear.
  func stageImports(_ options: [RecipeImportOption]) throws {
    guard editingStorageIsAvailable else { throw FileRecipeEditingStore.Failure.invalidDocument }
    let retained = authoringItems
    for option in options {
      let identifier = try importIdentifier(for: option)
      guard !authoringItems.contains(where: { $0.importIdentifier == identifier }) else { continue }
      let candidate = RecipeEditingModel(draft: option.draft, concerns: option.concerns)
      candidate.isImportCandidate = true
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
      let identifier = try importIdentifier(for: option)
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
    candidate.isImportCandidate = false
    guard persistEditingDrafts() else {
      candidate.isImportCandidate = true
      return false
    }
    return true
  }

  private func importIdentifier(for option: RecipeImportOption) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return SHA256.hash(data: try encoder.encode(option)).map { String(format: "%02x", $0) }.joined()
  }
}
