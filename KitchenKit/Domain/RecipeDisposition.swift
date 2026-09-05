// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// One caller-owned, retry-safe intention to hide a Recipe aggregate.
public struct RecipeDeleteCommand: Codable, Equatable, Sendable {
  public let id: UUID
  public let kitchenID: Kitchen.ID
  public let recipeID: Recipe.ID
  public let deletedAt: Date

  public init(id: UUID = UUID(), kitchenID: Kitchen.ID, recipeID: Recipe.ID, deletedAt: Date = Date()) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.deletedAt = deletedAt
  }
}

/// Explicitly resolves only the deletion identities the person observed.
public struct RecipeRestoreCommand: Codable, Equatable, Sendable {
  public let id: UUID
  public let kitchenID: Kitchen.ID
  public let recipeID: Recipe.ID
  public let observedDeletionIDs: [UUID]
  public let restoredAt: Date

  public init(
    id: UUID = UUID(), kitchenID: Kitchen.ID, recipeID: Recipe.ID,
    observedDeletionIDs: [UUID], restoredAt: Date = Date()
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.observedDeletionIDs = observedDeletionIDs
    self.restoredAt = restoredAt
  }
}

/// A deleted aggregate may still be waiting for content or require recovery.
public struct DeletedRecipe: Equatable, Identifiable, Sendable {
  public let id: Recipe.ID
  public let authority: RecipeAuthorityProjection
  public let observedDeletionIDs: [UUID]

  public var recoverableRecipe: AvailableRecipeAuthority? {
    guard case let .deleted(value) = authority else { return nil }
    return value
  }

  public init(id: Recipe.ID, authority: RecipeAuthorityProjection, observedDeletionIDs: [UUID]) {
    self.id = id
    self.authority = authority
    self.observedDeletionIDs = observedDeletionIDs
  }
}

public enum RecipeDispositionError: Error, Equatable {
  case unavailable
  case invalidCommand
  case identityCollision
}
