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

/// Fresh read contexts observe incrementally arriving personal-iCloud records.
/// Writes and compaction use isolated local transactions; no Recipe payload is changed.
@MainActor
public final class SwiftDataFolderRepository: FolderRepository {
  private let modelContainer: ModelContainer

  public init(modelContainer: ModelContainer) { self.modelContainer = modelContainer }

  public func library(in kitchenID: Kitchen.ID) throws -> FolderLibrary {
    try load(in: kitchenID, context: ModelContext(modelContainer)).library(in: kitchenID)
  }

  public func append(_ command: FolderCommand) throws {
    let context = ModelContext(modelContainer)
    try context.transaction {
      let kitchenID = command.kitchenID.rawValue
      guard try !context.fetch(FetchDescriptor<KitchenRecord>(predicate: #Predicate { $0.id == kitchenID })).isEmpty
      else { throw KitchenMemoryPersistenceError.missingKitchen }
      let identifier = command.id
      let matching = try context.fetch(FetchDescriptor<OrganizationActionRecord>(predicate: #Predicate {
        $0.id == identifier
      }))
      guard matching.allSatisfy({ $0.kitchenID == kitchenID && $0.namespace == "folders" }) else {
        throw FolderError.wrongKitchen
      }
      let snapshot = try load(in: command.kitchenID, context: context)
      _ = try FolderLibrary(kitchenID: command.kitchenID,
                            commands: snapshot.commands + [command], checkpoints: snapshot.checkpoints)
      let covered = snapshot.checkpoints.flatMap { $0.evidence.receipts }.contains { $0.id == command.id }
      try validateAssignment(command, context: context, requireRecipe: false)
      if matching.isEmpty && !covered {
        try validateAssignment(command, context: context, requireRecipe: true)
        context.insert(try OrganizationActionRecord(command: command))
      }
    }
  }

  @discardableResult
  public func compact(in kitchenID: Kitchen.ID, at date: Date) throws -> FolderCheckpoint? {
    let context = ModelContext(modelContainer)
    var result: FolderCheckpoint?
    try context.transaction {
      let snapshot = try load(in: kitchenID, context: context)
      guard let checkpoint = try snapshot.library(in: kitchenID).checkpoint(at: date) else { return }
      context.insert(try OrganizationCheckpointRecord(checkpoint: checkpoint))
      let covered = Set(checkpoint.evidence.receipts.map(\.id))
      let identifier = kitchenID.rawValue
      for record in try context.fetch(FetchDescriptor<OrganizationActionRecord>(predicate: #Predicate {
        $0.kitchenID == identifier && $0.namespace == "folders"
      })) where covered.contains(record.id) { context.delete(record) }
      result = checkpoint
    }
    return result
  }

  private func load(in kitchenID: Kitchen.ID, context: ModelContext) throws -> FolderStoreSnapshot {
    let identifier = kitchenID.rawValue
    let actions = try context.fetch(FetchDescriptor<OrganizationActionRecord>(predicate: #Predicate {
      $0.kitchenID == identifier && $0.namespace == "folders"
    }))
    let checkpoints = try context.fetch(FetchDescriptor<OrganizationCheckpointRecord>(predicate: #Predicate {
      $0.kitchenID == identifier && $0.namespace == "folders"
    }))
    let snapshot = try FolderStoreSnapshot(commands: actions.map(decode), checkpoints: checkpoints.map(decode))
    let retained = snapshot.checkpoints.flatMap { $0.evidence.retained }.map {
      FolderCommand(kitchenID: kitchenID, action: $0)
    }
    for command in snapshot.commands + retained {
      try validateAssignment(command, context: context, requireRecipe: false)
    }
    return snapshot
  }

  private func validateAssignment(
    _ command: FolderCommand, context: ModelContext, requireRecipe: Bool
  ) throws {
    guard case let .assign(recipeID, _) = command.action.payload else { return }
    let identifier = recipeID.rawValue
    let recipes = try context.fetch(FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == identifier }))
    guard !requireRecipe || !recipes.isEmpty else { throw FolderError.missingRecipe(recipeID) }
    guard recipes.allSatisfy({ $0.kitchenID == command.kitchenID.rawValue }) else { throw FolderError.wrongKitchen }
  }

  private func decode(_ record: OrganizationActionRecord) throws -> FolderCommand {
    guard record.formatVersion == 1 else { throw FolderError.invalidEvidence }
    let action = try JSONDecoder().decode(OrganizationAction<FolderChange>.self, from: record.payloadData)
    guard action.id == record.id, action.authoredAt == record.authoredAt,
          try OrganizationCoding.encode(action) == record.payloadData,
          try OrganizationCoding.digest(action) == record.payloadDigest else { throw FolderError.invalidEvidence }
    return FolderCommand(kitchenID: Kitchen.ID(rawValue: record.kitchenID), action: action)
  }

  private func decode(_ record: OrganizationCheckpointRecord) throws -> FolderCheckpoint {
    guard record.formatVersion == 1,
          record.antiResurrectionUntil >= record.createdAt.addingTimeInterval(1_827 * 86_400) else {
      throw FolderError.invalidEvidence
    }
    let evidence = try JSONDecoder().decode(OrganizationCheckpoint<FolderChange>.self, from: record.checkpointData)
    guard try OrganizationCoding.encode(evidence) == record.checkpointData,
          try OrganizationCoding.digest(evidence) == record.checkpointDigest else { throw FolderError.invalidEvidence }
    return FolderCheckpoint(id: record.id, kitchenID: Kitchen.ID(rawValue: record.kitchenID),
                            createdAt: record.createdAt, antiResurrectionUntil: record.antiResurrectionUntil,
                            evidence: evidence)
  }
}

private struct FolderStoreSnapshot {
  let commands: [FolderCommand]
  let checkpoints: [FolderCheckpoint]

  func library(in kitchenID: Kitchen.ID) throws -> FolderLibrary {
    try FolderLibrary(kitchenID: kitchenID, commands: commands, checkpoints: checkpoints)
  }
}
