// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Organization chosen before a new Recipe has a durable identity.
public struct PendingRecipeOrganization: Codable, Equatable, Sendable {
  /// The intended primary Folder, or nil for Unfiled, before publication.
  public var folderID: Folder.ID?
  /// The intended live Tags to assign when the new Recipe identity is published.
  public var tagIDs: Set<Tag.ID>

  /// Retains local organization choices without creating shared assignment evidence.
  public init(folderID: Folder.ID? = nil, tagIDs: Set<Tag.ID> = []) {
    self.folderID = folderID
    self.tagIDs = tagIDs
  }
}

/// One prepared local transaction. Retain the entire value, not just its identifier, for retry.
public struct RecipeOrganizationCommand: Codable, Equatable, Sendable {
  /// The caller-owned immutable operation identity.
  ///
  /// Exact retries reuse it with identical content; conflicting reuse requires rejection
  /// or recovery rather than another accepted effect.
  public let id: UUID
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  /// The preparation date shared by the transaction’s child intentions.
  public let authoredAt: Date
  /// Prepared Folder changes to accept together in the local transaction.
  public let folders: [FolderCommand]
  /// Prepared Tag changes to accept together in the local transaction.
  public let tags: [TagCommand]
}

/// A complete observed organization state, independent of local presentation preferences.
public struct RecipeOrganization: Equatable, Sendable {
  /// The observed Folder projection participating in this Kitchen’s organization.
  public let folders: FolderLibrary
  /// The observed Tag projection participating in the same Kitchen’s organization.
  public let tags: TagLibrary

  /// Combines two observed libraries only when they belong to the same Kitchen.
  ///
  /// Throws `FolderError.wrongKitchen` for mismatched ownership.
  public init(folders: FolderLibrary, tags: TagLibrary) throws {
    guard folders.kitchenID == tags.kitchenID else { throw FolderError.wrongKitchen }
    self.folders = folders
    self.tags = tags
  }

  /// Wraps one validated Folder intention in a retryable local batch.
  ///
  /// The child action identity derives deterministically from the root UUID.
  /// Its observed frontier comes from this Folder projection; preserve the full
  /// returned batch rather than preparing again after the library changes.
  public func prepare(folder intent: FolderIntent, id: UUID = UUID(), at date: Date = Date()) throws
    -> RecipeOrganizationCommand {
    RecipeOrganizationCommand(id: id, kitchenID: folders.kitchenID, authoredAt: date,
                              folders: [try folders.prepare(intent, id: childID(id, "folder", id), at: date)], tags: [])
  }

  /// Wraps one validated Tag intention in a retryable local batch.
  ///
  /// The child identity derives from the root UUID. Observed assignment removals
  /// freeze this Tag projection’s live dots; later unseen assignments survive.
  /// Preserve the full batch for retry against the same observed context.
  public func prepare(tag intent: TagIntent, id: UUID = UUID(), at date: Date = Date()) throws
    -> RecipeOrganizationCommand {
    RecipeOrganizationCommand(id: id, kitchenID: folders.kitchenID, authoredAt: date, folders: [],
                              tags: [try tags.prepare(intent, id: childID(id, "tag", id), at: date)])
  }

  /// All selected Recipes move together locally; remote delivery may still be partial.
  public func move(_ recipeIDs: Set<Recipe.ID>, to folderID: Folder.ID?,
                   id: UUID = UUID(), at date: Date = Date()) throws -> RecipeOrganizationCommand {
    let commands = try ordered(recipeIDs).map { recipeID in
      try folders.prepare(.assign(recipeID: recipeID, folderID: folderID),
                          id: childID(id, "move", recipeID.rawValue), at: date)
    }
    return RecipeOrganizationCommand(id: id, kitchenID: folders.kitchenID, authoredAt: date,
                                     folders: commands, tags: [])
  }

  /// Prepares atomic local additions or observed removals for all selected Recipes.
  ///
  /// Each child identity derives from the root command and Recipe identity. Removal
  /// resolves only observed dots; concurrent unseen assignments remain.
  public func classify(_ recipeIDs: Set<Recipe.ID>, tagID: Tag.ID, adding: Bool,
                       id: UUID = UUID(), at date: Date = Date()) throws -> RecipeOrganizationCommand {
    let commands = try ordered(recipeIDs).map { recipeID in
      try tags.prepare(adding ? .assign(recipeID: recipeID, tagID: tagID)
                       : .remove(recipeID: recipeID, tagID: tagID),
                       id: childID(id, "classify", recipeID.rawValue), at: date)
    }
    return RecipeOrganizationCommand(id: id, kitchenID: folders.kitchenID, authoredAt: date,
                                     folders: [], tags: commands)
  }

  /// Prepares initial Folder and Tag assignments for a Recipe’s first Save.
  ///
  /// Child IDs derive deterministically from the root UUID and target identities.
  /// Nil Folder means Unfiled; selected Tags must be live in this projection.
  /// Preparation creates no Recipe authority; the repository accepts this batch
  /// together with the caller’s first Save in one local transaction.
  public func prepare(_ pending: PendingRecipeOrganization, for recipeID: Recipe.ID,
                      id: UUID, at date: Date) throws -> RecipeOrganizationCommand {
    let folder = try folders.prepare(.assign(recipeID: recipeID, folderID: pending.folderID),
                                     id: childID(id, "initial-folder", recipeID.rawValue), at: date)
    let commands = try pending.tagIDs.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }.map { tagID in
      try tags.prepare(.assign(recipeID: recipeID, tagID: tagID),
                       id: childID(id, "initial-tag", tagID.rawValue), at: date)
    }
    return RecipeOrganizationCommand(id: id, kitchenID: folders.kitchenID, authoredAt: date,
                                     folders: [folder], tags: commands)
  }

  private func ordered(_ ids: Set<Recipe.ID>) -> [Recipe.ID] {
    ids.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }
  }

  private func childID(_ root: UUID, _ kind: String, _ source: UUID) -> UUID {
    derivedID(namespace: root, kind: "recipe-organization/" + kind, source: source)
  }
}
