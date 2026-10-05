// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// One caller-owned, retry-safe intention to hide a Recipe aggregate.
public struct RecipeDeleteCommand: Codable, Equatable, Sendable {
  /// The caller-owned immutable operation identity.
  ///
  /// Exact retries reuse it with identical content; conflicting reuse requires rejection
  /// or recovery rather than another accepted effect.
  public let id: UUID
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  /// The stable maintained Recipe identity, independent of a particular Revision.
  public let recipeID: Recipe.ID
  /// The authored deletion date retained across retries; it does not overwrite lifecycle.
  public let deletedAt: Date

  /// Creates a caller-owned deletion intention; keep the complete value on retry.
  public init(id: UUID = UUID(), kitchenID: Kitchen.ID, recipeID: Recipe.ID, deletedAt: Date = Date()) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.deletedAt = deletedAt
  }
}

/// The immutable identity of one observed deletion resolution, as stored in V5.
public struct RecipeRestoration: Codable, Equatable, Sendable {
  /// The caller-owned immutable operation identity.
  ///
  /// Exact retries reuse it with identical content; conflicting reuse requires rejection
  /// or recovery rather than another accepted effect.
  public let id: UUID
  /// The explicitly observed deletion this resolution retires.
  public let deletionID: UUID

  /// Creates one resolution identity; retry the same identity for the same deletion.
  public init(id: UUID = UUID(), deletionID: UUID) {
    self.id = id
    self.deletionID = deletionID
  }
}

/// An atomic batch of caller-identified resolutions, with no separate batch identity.
public struct RecipeRestoreCommand: Codable, Equatable, Sendable {
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  /// The stable maintained Recipe identity, independent of a particular Revision.
  public let recipeID: Recipe.ID
  /// The atomic list of identified resolutions; there is no independent batch retry identity.
  public let restorations: [RecipeRestoration]
  /// The shared authored restoration date bound to each supplied resolution.
  public let restoredAt: Date

  /// The deletion IDs named by the resolution list, preserving its order.
  public var observedDeletionIDs: [UUID] { restorations.map(\.deletionID) }

  /// Creates a restoration batch from observed deletions or previously identified resolutions.
  ///
  /// The convenience deletion-ID form mints fresh resolution IDs; retain the resulting
  /// command for retry rather than calling that initializer again.
  public init(
    kitchenID: Kitchen.ID, recipeID: Recipe.ID,
    observedDeletionIDs: [UUID], restoredAt: Date = Date()
  ) {
    self.init(
      kitchenID: kitchenID, recipeID: recipeID,
      restorations: observedDeletionIDs.map { RecipeRestoration(deletionID: $0) }, restoredAt: restoredAt
    )
  }

  /// Creates a restoration batch from observed deletions or previously identified resolutions.
  ///
  /// The convenience deletion-ID form mints fresh resolution IDs; retain the resulting
  /// command for retry rather than calling that initializer again.
  public init(
    kitchenID: Kitchen.ID, recipeID: Recipe.ID,
    restorations: [RecipeRestoration], restoredAt: Date
  ) {
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.restorations = restorations
    self.restoredAt = restoredAt
  }
}

/// A deleted aggregate may still be waiting for content or require recovery.
public struct DeletedRecipe: Equatable, Identifiable, Sendable {
  /// The stable domain identity retained across copies and synchronization.
  ///
  /// Identity equality alone does not authorize contradictory immutable content.
  public let id: Recipe.ID
  /// The retained authority classification, which can still be unavailable or require recovery.
  public let authority: RecipeAuthorityProjection
  /// The unresolved deletions available for an explicit restoration choice.
  public let observedDeletionIDs: [UUID]

  /// Complete content only when authority is the deleted case; waiting and recovery return nil.
  public var recoverableRecipe: AvailableRecipeAuthority? {
    guard case let .deleted(value) = authority else { return nil }
    return value
  }

  /// Pairs retained authority with the deletion frontier without attempting restoration.
  public init(id: Recipe.ID, authority: RecipeAuthorityProjection, observedDeletionIDs: [UUID]) {
    self.id = id
    self.authority = authority
    self.observedDeletionIDs = observedDeletionIDs
  }
}

/// A repository rejection of a Recipe deletion or restoration intention.
public enum RecipeDispositionError: Error, Equatable {
  /// The requested aggregate cannot currently support this disposition action.
  case unavailable
  /// The supplied disposition intention violates acceptance preconditions.
  case invalidCommand
  /// A retained command or resolution identity is reused with different content.
  case identityCollision
}
