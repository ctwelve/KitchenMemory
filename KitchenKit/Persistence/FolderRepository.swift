// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// Durable acceptance and reconstruction of Kitchen-owned Folder commands.
@MainActor
public protocol FolderRepository: AnyObject {
  func library(in kitchenID: Kitchen.ID) throws -> FolderLibrary
  func append(_ command: FolderCommand) throws
  @discardableResult
  func compact(in kitchenID: Kitchen.ID, at date: Date) throws -> FolderCheckpoint?
}

@MainActor
public final class SwiftDataFolderRepository: FolderRepository {
  private let store: OrganizationStore<FolderChange>

  public init(modelContainer: ModelContainer) {
    store = OrganizationStore(modelContainer: modelContainer, namespace: "folders", recipeID: {
      if case let .assign(recipeID, _) = $0 { return recipeID }; return nil
    })
  }

  public func library(in kitchenID: Kitchen.ID) throws -> FolderLibrary {
    try library(store.load(in: kitchenID), in: kitchenID)
  }

  public func append(_ command: FolderCommand) throws {
    try store.append(command.action, in: command.kitchenID) { snapshot in
      _ = try library(snapshot, in: command.kitchenID)
    }
  }

  @discardableResult
  public func compact(in kitchenID: Kitchen.ID, at date: Date) throws -> FolderCheckpoint? {
    let result = try store.compact(in: kitchenID) { snapshot in
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
