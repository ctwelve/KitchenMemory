// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Observed content and last accepted installation intent are deliberately separate.
public struct SamplePackStatus: Equatable, Sendable {
  public let isEnabled: Bool
  public let total: Int
  public let installed: Int
  public let edited: Int
  public let deleted: Int
  public let unavailable: Int
  public let removableIDs: Set<Recipe.ID>
  public let folderID: Folder.ID?
  public let tagID: Tag.ID?
}

/// Caller-owned identities bind one explicit installation/removal request for retry.
public struct SamplePackCommand: Codable, Equatable, Sendable {
  public let id: UUID
  public let kitchenID: Kitchen.ID
  public let enabled: Bool
  public let samples: [StoredRecipe]
  public let removalIDs: Set<Recipe.ID>
  public let folderName: String
  public let tagName: String
  public let proposedFolderID: Folder.ID
  public let proposedTagID: Tag.ID
  public let authoredAt: Date

  public init(
    id: UUID = UUID(), kitchenID: Kitchen.ID, enabled: Bool,
    samples: [StoredRecipe], removalIDs: Set<Recipe.ID> = [],
    folderName: String, tagName: String, proposedFolderID: Folder.ID = Folder.ID(),
    proposedTagID: Tag.ID = Tag.ID(), authoredAt: Date = Date()
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.enabled = enabled
    self.samples = samples
    self.removalIDs = removalIDs
    self.folderName = folderName
    self.tagName = tagName
    self.proposedFolderID = proposedFolderID
    self.proposedTagID = proposedTagID
    self.authoredAt = authoredAt
  }
}

struct SamplePackReceipt: OrganizationPayload {
  let digest: Data
  let enabled: Bool
  let folderID: Folder.ID?
  let tagID: Tag.ID?
  var compactableRegister: String? { nil }
}
