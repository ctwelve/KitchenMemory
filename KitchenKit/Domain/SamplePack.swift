// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Observed content and last accepted installation intent are deliberately separate.
public struct SamplePackStatus: Equatable, Sendable {
  /// The last accepted installation intent, independent of the observed sample counts.
  public let isEnabled: Bool
  /// The number of bundled samples considered by this status computation.
  public let total: Int
  /// Ordinary available samples, including edited samples; this count does not
  /// itself authorize removal.
  public let installed: Int
  /// Available or deleted samples whose content or additional history differs
  /// from the bundle; this count can overlap installed or deleted.
  public let edited: Int
  /// Samples currently hidden by retained deletion evidence.
  public let deleted: Int
  /// Known pruned, unavailable, or recovery sample identities. A completely absent
  /// sample is not included in this count.
  public let unavailable: Int
  /// Untouched ordinary samples eligible for removal preview; acceptance rechecks them.
  public let removableIDs: Set<Recipe.ID>
  /// The organization identity retained by the accepted installation receipt, when known.
  public let folderID: Folder.ID?
  /// The classification identity retained by the accepted installation receipt, when known.
  public let tagID: Tag.ID?
}

/// Caller-owned identities bind one explicit installation/removal request for retry.
public struct SamplePackCommand: Codable, Equatable, Sendable {
  /// The caller-owned immutable operation identity.
  ///
  /// Exact retries reuse it with identical content; conflicting reuse requires rejection
  /// or recovery rather than another accepted effect.
  public let id: UUID
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  /// The explicit requested installation state; observing this value does not execute it.
  public let enabled: Bool
  /// Bundled content and stable identities proposed for installation.
  public let samples: [StoredRecipe]
  /// The exact Recipe identities offered for removal; acceptance preserves late-edited samples.
  public let removalIDs: Set<Recipe.ID>
  /// The localized ordinary Folder name proposed for matching or creation.
  public let folderName: String
  /// The localized ordinary Tag name proposed for matching or creation.
  public let tagName: String
  /// A caller-owned fallback identity used only if a fresh Folder is required.
  public let proposedFolderID: Folder.ID
  /// A caller-owned fallback identity used only if a fresh Tag is required.
  public let proposedTagID: Tag.ID
  /// The request date bound to the immutable accepted receipt.
  public let authoredAt: Date

  /// Freezes one explicit install/remove intention, including content and proposed identities.
  ///
  /// Retain the whole value on retry. Preparing a command neither installs samples
  /// nor authorizes removal of edited or unrelated Recipes.
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
