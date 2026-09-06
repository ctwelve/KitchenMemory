// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Locally completed maintenance, never a claim of synchronization completion.
public struct RecipeRetentionResult: Equatable, Sendable {
  public var prunedRecipeIDs: [Recipe.ID] = []
  public var expiredTombstoneRecipeIDs: [Recipe.ID] = []
}

/// Retained evidence that cannot currently reconstruct an ordinary Recipe.
public struct RecipeRecovery: Equatable, Identifiable, Sendable {
  public let id: Recipe.ID
  public let authority: RecipeAuthorityProjection
  public let revisions: [RecipeRevision]
}
