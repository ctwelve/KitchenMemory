// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Durable acceptance and reconstruction of Kitchen-owned Folder commands.
@MainActor
public protocol FolderRepository: AnyObject {
  /// Reconstructs the Kitchen's Folder projection from retained actions and checkpoints.
  /// Throws for unsupported, incomplete, or conflicting evidence rather than inventing a partial library.
  func library(in kitchenID: Kitchen.ID) throws -> FolderLibrary
  /// Accepts the frozen Folder command in one local transaction.
  /// Identical retries preserve causal receipts; conflicting identities, ownership, or invalid replay throw.
  func append(_ command: FolderCommand) throws
  /// Creates a reconstructive checkpoint when eligible and removes safely covered old action envelopes.
  /// Returns nil when no new checkpoint is needed; receipts, aliases, and replay dependencies remain retained.
  @discardableResult
  func compact(in kitchenID: Kitchen.ID, at date: Date) throws -> FolderCheckpoint?
}
