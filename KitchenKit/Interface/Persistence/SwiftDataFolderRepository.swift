// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// Main-actor SwiftData adapter for Folder actions and reconstructive checkpoints.
/// Managed rows remain within each actor-bound context; callers receive domain projections.
@MainActor
public final class SwiftDataFolderRepository: FolderRepository {
  private let store: OrganizationStore<FolderChange>

  /// Binds the folder evidence namespace to the supplied shared container.
  public init(modelContainer: ModelContainer) {
    store = OrganizationStore(modelContainer: modelContainer, namespace: "folders", recipeID: {
      if case let .assign(recipeID, _) = $0 { return recipeID }; return nil
    })
  }

  /// Reconstructs the Kitchen's Folder library from validated local evidence.
  public func library(in kitchenID: Kitchen.ID) throws -> FolderLibrary {
    try library(store.load(in: kitchenID), in: kitchenID)
  }

  /// Reconstructs the Kitchen's Folder projection from retained actions and checkpoints.
  /// Throws for unsupported, incomplete, or conflicting evidence rather than inventing a partial library.
  func library(in kitchenID: Kitchen.ID, context: ModelContext) throws -> FolderLibrary {
    try library(store.load(in: kitchenID, context: context), in: kitchenID)
  }

  /// Validates replay and locally accepts the frozen Folder command.
  /// Receipt checks make identical retry idempotent and reject changed identity reuse.
  public func append(_ command: FolderCommand) throws {
    try store.append(command.action, in: command.kitchenID) { snapshot in
      _ = try library(snapshot, in: command.kitchenID)
    }
  }

  /// Accepts the frozen Folder command in one local transaction.
  /// Identical retries preserve causal receipts; conflicting identities, ownership, or invalid replay throw.
  func append(_ commands: [FolderCommand], in kitchenID: Kitchen.ID, context: ModelContext) throws {
    try store.append(commands.map(\.action), in: kitchenID, context: context) { snapshot in
      _ = try library(snapshot, in: kitchenID)
    }
  }

  /// Atomically checkpoints eligible Folder history and removes covered old raw actions.
  /// Returns nil when no new checkpoint is needed; complete causal receipts remain retained.
  @discardableResult
  public func compact(in kitchenID: Kitchen.ID, at date: Date) throws -> FolderCheckpoint? {
    try compact(in: kitchenID, at: date, maximumRemovals: .max)
  }

  /// Creates a reconstructive checkpoint when eligible and removes safely covered old action envelopes.
  /// Returns nil when no new checkpoint is needed; receipts, aliases, and replay dependencies remain retained.
  func compact(in kitchenID: Kitchen.ID, at date: Date, maximumRemovals: Int) throws -> FolderCheckpoint? {
    let result = try store.compact(in: kitchenID, at: date, maximumRemovals: maximumRemovals) { snapshot in
      try library(snapshot, in: kitchenID).checkpoint(at: date).map { checkpoint in
        OrganizationStore<FolderChange>.Checkpoint(
          id: checkpoint.id, kitchenID: kitchenID, createdAt: checkpoint.createdAt,
          antiResurrectionUntil: checkpoint.antiResurrectionUntil, evidence: checkpoint.evidence
        )
      }
    }
    return result.map(checkpoint)
  }

  private func library(_ snapshot: OrganizationStore<FolderChange>.Snapshot,
                       in kitchenID: Kitchen.ID) throws -> FolderLibrary {
    try FolderLibrary(kitchenID: kitchenID,
                     commands: snapshot.actions.map { FolderCommand(kitchenID: kitchenID, action: $0) },
                     checkpoints: snapshot.checkpoints.map(checkpoint))
  }

  private func checkpoint(_ value: OrganizationStore<FolderChange>.Checkpoint) -> FolderCheckpoint {
    FolderCheckpoint(id: value.id, kitchenID: value.kitchenID, createdAt: value.createdAt,
                    antiResurrectionUntil: value.antiResurrectionUntil, evidence: value.evidence)
  }
}
