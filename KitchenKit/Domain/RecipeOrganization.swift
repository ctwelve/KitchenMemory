// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Organization chosen before a new Recipe has a durable identity.
public struct PendingRecipeOrganization: Codable, Equatable, Sendable {
  public var folderID: Folder.ID?
  public var tagIDs: Set<Tag.ID>

  public init(folderID: Folder.ID? = nil, tagIDs: Set<Tag.ID> = []) {
    self.folderID = folderID
    self.tagIDs = tagIDs
  }
}

/// One prepared local transaction. Retain the entire value, not just its identifier, for retry.
public struct RecipeOrganizationCommand: Codable, Equatable, Sendable {
  public let id: UUID
  public let kitchenID: Kitchen.ID
  public let authoredAt: Date
  public let folders: [FolderCommand]
  public let tags: [TagCommand]
}

/// A complete observed organization state, independent of local presentation preferences.
public struct RecipeOrganization: Equatable, Sendable {
  public let folders: FolderLibrary
  public let tags: TagLibrary

  public init(folders: FolderLibrary, tags: TagLibrary) throws {
    guard folders.kitchenID == tags.kitchenID else { throw FolderError.wrongKitchen }
    self.folders = folders
    self.tags = tags
  }

  public func prepare(folder intent: FolderIntent, id: UUID = UUID(), at date: Date = Date()) throws
    -> RecipeOrganizationCommand {
    RecipeOrganizationCommand(id: id, kitchenID: folders.kitchenID, authoredAt: date,
                              folders: [try folders.prepare(intent, id: childID(id, "folder", id), at: date)], tags: [])
  }

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
