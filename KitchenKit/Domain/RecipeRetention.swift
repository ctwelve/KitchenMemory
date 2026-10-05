// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Locally completed maintenance, never a claim of synchronization completion.
public struct RecipeRetentionResult: Equatable, Sendable {
  /// Recipe identities whose eligible payload was removed in this local pass.
  public var prunedRecipeIDs: [Recipe.ID] = []
  /// Recipe identities whose compact evidence passed expiry checks in this local pass.
  public var expiredTombstoneRecipeIDs: [Recipe.ID] = []
}

/// Retained evidence that cannot currently reconstruct an ordinary Recipe.
public struct RecipeRecovery: Equatable, Identifiable, Sendable {
  /// The retained Recipe identity requiring recovery; copying content must create a new Recipe.
  public let id: Recipe.ID
  /// The retained explanation preventing ordinary Recipe reconstruction.
  public let authority: RecipeAuthorityProjection
  /// Individually readable retained content offered for explicit recovery without resurrecting the old identity.
  public let revisions: [RecipeRevision]
}
