// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// A flat Kitchen-owned classification of stable Recipes.
public struct Tag: Equatable, Identifiable, Sendable {
  /// A domain-typed stable UUID identity, independent of persistence record identity.
  public typealias ID = StableIdentifier<Tag>
  /// The classification identity preserved through Rename, independent of display spelling.
  public let id: ID
  /// The retained display spelling with leading presentation hashes removed.
  public let name: String
  /// The ordinary name prefixed with one presentation hash; the hash is not stored identity.
  public var displayName: String { "#" + name }
}

/// The shared Tag presentation mode; manual neighbor order survives mode changes.
public enum TagOrdering: String, Codable, Equatable, Sendable {
  /// Locale-aware display-name order with stable identity ties.
  case alphabetical
  /// Retained neighbor order, including creations and explicit repositioning.
  case manual
}

/// An organization intention to prepare against the Tag library the person observed.
public enum TagIntent: Equatable, Sendable {
  /// Creates a fresh identity with a validated Kitchen-wide name.
  case create(id: Tag.ID, name: String)
  /// Changes a live Tag’s spelling without colliding with another observed live name.
  case rename(id: Tag.ID, name: String)
  /// Adds a fresh assignment dot to one Recipe and live Tag.
  case assign(recipeID: Recipe.ID, tagID: Tag.ID)
  /// Removes only currently observed live assignment dots, including observed aliases.
  ///
  /// Concurrent unseen assignments survive this observed removal.
  case remove(recipeID: Recipe.ID, tagID: Tag.ID)
  /// Suppresses this Tag identity and its assignments, without deleting Recipe content.
  case delete(id: Tag.ID)
  /// Unions surviving assignment dots under an existing survivor and retains aliases.
  ///
  /// Removed dots stay removed; a nil survivor chooses the oldest existing creation.
  case merge(ids: [Tag.ID], survivorID: Tag.ID?, name: String)
  /// Places a live Tag after another live Tag, or first with a nil anchor.
  case reorder(id: Tag.ID, afterID: Tag.ID?)
  /// Changes the shared presentation mode without erasing manual neighbor history.
  case ordering(TagOrdering)
  /// Changes shared visibility of the computed Untagged system view.
  case systemViewVisible(Bool)
}

/// Preserve the prepared command for exact retries, including observed assignment dots.
public struct TagCommand: Codable, Equatable, Sendable {
  /// The immutable assignment or organization action identity, retained unchanged on retry.
  public var id: UUID { action.id }
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  let action: OrganizationAction<TagChange>
}

/// A Tag preparation or evidence-integrity failure, independent of Recipe payload access.
public enum TagError: Error, Equatable {
  /// Retained organization payload or checkpoint evidence violates a positive integrity invariant.
  case invalidEvidence
  /// The requested neighbor is invalid for the selected item’s ordering scope.
  case invalidOrder
  /// The selected identities cannot form one explicit Merge under this policy.
  case invalidMerge
  /// The entered name is empty, too long, or contains controls or line breaks.
  case invalidName
  /// Another observed live identity already uses the normalized name in this naming scope.
  case duplicateName
  /// An existing creation identity is reused by a different organization intention.
  case identityCollision(Tag.ID)
  /// A required live Tag identity is absent from the observed library.
  case missingTag(Tag.ID)
  /// The repository cannot accept a fresh assignment to the referenced Recipe.
  case missingRecipe(Recipe.ID)
  /// Observed organization predecessor edges form a causal cycle.
  case causalCycle
  /// Commands, checkpoints, or participating libraries disagree on Kitchen ownership.
  case wrongKitchen
  /// One immutable action or receipt identity binds contradictory content.
  case actionCollision(UUID)
}

/// Keeps the shared substrate's historical Folder errors behind the Tag interface.
func tagBoundary<Value>(_ operation: () throws -> Value) throws -> Value {
  do { return try operation() } catch let error as FolderError {
    switch error {
    case .invalidName: throw TagError.invalidName
    case .causalCycle: throw TagError.causalCycle
    case .wrongKitchen: throw TagError.wrongKitchen
    case let .missingRecipe(id): throw TagError.missingRecipe(id)
    case let .actionCollision(id): throw TagError.actionCollision(id)
    default: throw TagError.invalidEvidence
    }
  }
}
