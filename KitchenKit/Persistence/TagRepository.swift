// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// Durable acceptance and reconstruction of Kitchen-owned Tag commands.
@MainActor
public protocol TagRepository: AnyObject {
  func library(in kitchenID: Kitchen.ID) throws -> TagLibrary
  func append(_ command: TagCommand) throws
  @discardableResult
  func compact(in kitchenID: Kitchen.ID, at date: Date) throws -> TagCheckpoint?
}

@MainActor
public final class SwiftDataTagRepository: TagRepository {
  private let store: OrganizationStore<TagChange>

  public init(modelContainer: ModelContainer) {
    store = OrganizationStore(modelContainer: modelContainer, namespace: "tags", recipeID: {
      if case let .assign(recipeID, _) = $0 { return recipeID }; return nil
    })
  }

  public func library(in kitchenID: Kitchen.ID) throws -> TagLibrary {
    try tagBoundary { try library(store.load(in: kitchenID), in: kitchenID) }
  }

  func library(in kitchenID: Kitchen.ID, context: ModelContext) throws -> TagLibrary {
    try library(store.load(in: kitchenID, context: context), in: kitchenID)
  }

  public func append(_ command: TagCommand) throws {
    try tagBoundary {
    try store.append(command.action, in: command.kitchenID) { snapshot in
      _ = try library(snapshot, in: command.kitchenID)
    }
    }
  }

  func append(_ commands: [TagCommand], in kitchenID: Kitchen.ID, context: ModelContext) throws {
    try store.append(commands.map(\.action), in: kitchenID, context: context) { snapshot in
      _ = try library(snapshot, in: kitchenID)
    }
  }

  @discardableResult
  public func compact(in kitchenID: Kitchen.ID, at date: Date) throws -> TagCheckpoint? {
    try compact(in: kitchenID, at: date, maximumRemovals: .max)
  }

  func compact(in kitchenID: Kitchen.ID, at date: Date, maximumRemovals: Int) throws -> TagCheckpoint? {
    try tagBoundary {
    let result = try store.compact(in: kitchenID, at: date, maximumRemovals: maximumRemovals) { snapshot in
      try library(snapshot, in: kitchenID).checkpoint(at: date).map { checkpoint in
        OrganizationStore<TagChange>.Checkpoint(
          id: checkpoint.id, kitchenID: kitchenID, createdAt: checkpoint.createdAt,
          antiResurrectionUntil: checkpoint.antiResurrectionUntil, evidence: checkpoint.evidence
        )
      }
    }
    return result.map(checkpoint)
    }
  }

  private func library(_ snapshot: OrganizationStore<TagChange>.Snapshot,
                       in kitchenID: Kitchen.ID) throws -> TagLibrary {
    try TagLibrary(kitchenID: kitchenID,
                     commands: snapshot.actions.map { TagCommand(kitchenID: kitchenID, action: $0) },
                     checkpoints: snapshot.checkpoints.map(checkpoint))
  }

  private func checkpoint(_ value: OrganizationStore<TagChange>.Checkpoint) -> TagCheckpoint {
    TagCheckpoint(id: value.id, kitchenID: value.kitchenID, createdAt: value.createdAt,
                    antiResurrectionUntil: value.antiResurrectionUntil, evidence: value.evidence)
  }
}
