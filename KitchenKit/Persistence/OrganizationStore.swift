// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// One physical evidence adapter for both organization policies. No payload models are rewritten.
@MainActor
struct OrganizationStore<Payload: OrganizationPayload> {
  let modelContainer: ModelContainer
  let namespace: String
  let recipeID: (Payload) -> Recipe.ID?

  struct Checkpoint {
    let id: UUID
    let kitchenID: Kitchen.ID
    let createdAt: Date
    let antiResurrectionUntil: Date
    let evidence: OrganizationCheckpoint<Payload>
  }

  struct Snapshot {
    var actions: [OrganizationAction<Payload>]
    let checkpoints: [Checkpoint]
  }

  func load(in kitchenID: Kitchen.ID) throws -> Snapshot {
    try load(in: kitchenID, context: ModelContext(modelContainer))
  }

  func append(_ action: OrganizationAction<Payload>, in kitchenID: Kitchen.ID,
              validate: (Snapshot) throws -> Void) throws {
    let context = ModelContext(modelContainer)
    try context.transaction {
      try append(action, in: kitchenID, context: context, validate: validate)
    }
  }

  func append(_ action: OrganizationAction<Payload>, in kitchenID: Kitchen.ID, context: ModelContext,
              validate: (Snapshot) throws -> Void) throws {
    try append([action], in: kitchenID, context: context, validate: validate)
  }

  func append(_ actions: [OrganizationAction<Payload>], in kitchenID: Kitchen.ID, context: ModelContext,
              validate: (Snapshot) throws -> Void) throws {
    let owner = kitchenID.rawValue
    guard try !context.fetch(FetchDescriptor<KitchenRecord>(predicate: #Predicate { $0.id == owner })).isEmpty
    else { throw KitchenMemoryPersistenceError.missingKitchen }
    let identifiers = actions.map(\.id)
    let matching = try context.fetch(FetchDescriptor<OrganizationActionRecord>(predicate: #Predicate {
      identifiers.contains($0.id)
    }))
    guard matching.allSatisfy({ $0.kitchenID == owner && $0.namespace == namespace }) else {
      throw FolderError.wrongKitchen
    }
    var snapshot = try load(in: kitchenID, context: context)
    snapshot.actions.append(contentsOf: actions)
    try validate(snapshot)
    var retained = Set(matching.map(\.id))
    retained.formUnion(snapshot.checkpoints.flatMap { $0.evidence.receipts }.map(\.id))
    for action in actions {
      try validateAssignment(action.payload, in: kitchenID, context: context, requireRecipe: false)
      if retained.insert(action.id).inserted {
        try validateAssignment(action.payload, in: kitchenID, context: context, requireRecipe: true)
        context.insert(try OrganizationActionRecord(action: action, kitchenID: kitchenID, namespace: namespace))
      }
    }
  }

  func compact(in kitchenID: Kitchen.ID, at date: Date, maximumRemovals: Int,
               prepare: (Snapshot) throws -> Checkpoint?) throws -> Checkpoint? {
    let context = ModelContext(modelContainer)
    var result: Checkpoint?
    try context.transaction {
      let snapshot = try load(in: kitchenID, context: context)
      _ = try OrganizationEvidence(snapshot.actions, checkpoints: snapshot.checkpoints.map(\.evidence))
      let oldReceipts = snapshot.checkpoints.flatMap { $0.evidence.receipts }
      let coveredBefore = Set(oldReceipts.map(\.id))
      let fresh = Snapshot(actions: snapshot.actions.filter { !coveredBefore.contains($0.id) },
                           checkpoints: snapshot.checkpoints)
      let checkpoint = try prepare(fresh)
      if let checkpoint {
        context.insert(try OrganizationCheckpointRecord(
          id: checkpoint.id, kitchenID: kitchenID, namespace: namespace, createdAt: checkpoint.createdAt,
          antiResurrectionUntil: checkpoint.antiResurrectionUntil, evidence: checkpoint.evidence
        ))
      }
      let receipts = oldReceipts + (checkpoint?.evidence.receipts ?? [])
      let identifier = kitchenID.rawValue
      let policy = namespace
      var remaining = maximumRemovals
      for record in try context.fetch(FetchDescriptor<OrganizationActionRecord>(predicate: #Predicate {
        $0.kitchenID == identifier && $0.namespace == policy
      })) {
        guard remaining > 0 else { break }
        guard date.timeIntervalSince(record.authoredAt) >= 30 * 86_400,
              try receipts.contains(decode(record).receipt()) else { continue }
        context.delete(record)
        remaining -= 1
      }
      result = checkpoint
    }
    return result
  }

  /// Removes only redundant envelopes; identity receipts and live reconstruction stay retained.
  func maintainCoveredEvidence(in kitchenID: Kitchen.ID, at date: Date, removeOldRaw: Bool,
                               after: String?, limit: Int) throws -> String? {
    let context = ModelContext(modelContainer)
    var continuation: String?
    try context.transaction {
      let snapshot = try load(in: kitchenID, context: context)
      // Validate collisions and complete checkpoint ancestry before using coverage as deletion authority.
      _ = try OrganizationEvidence(snapshot.actions, checkpoints: snapshot.checkpoints.map(\.evidence))
      let identifier = kitchenID.rawValue
      let policy = namespace
      if removeOldRaw {
        let receipts = snapshot.checkpoints.flatMap { $0.evidence.receipts }
        let rows = try context.fetch(FetchDescriptor<OrganizationActionRecord>(predicate: #Predicate {
          $0.kitchenID == identifier && $0.namespace == policy
        }))
        let page = maintenancePage(rows.map(\.id), after: after, limit: limit)
        continuation = page.continuation
        for row in rows where page.ids.contains(row.id)
          && date.timeIntervalSince(row.authoredAt) >= 366 * 86_400 {
          let receipt = try decode(row).receipt()
          if receipts.contains(receipt) { context.delete(row) }
        }
      } else {
        let rows = try context.fetch(FetchDescriptor<OrganizationCheckpointRecord>(predicate: #Predicate {
          $0.kitchenID == identifier && $0.namespace == policy
        }))
        let page = maintenancePage(rows.map(\.id), after: after, limit: limit)
        continuation = page.continuation
        for row in rows where page.ids.contains(row.id) {
          let old = try decode(row)
          guard date >= old.antiResurrectionUntil else { continue }
          // Five years is a minimum, never permission to erase aliases still needed by replay.
          let replacement = snapshot.checkpoints.contains { newer in
            newer.createdAt > old.createdAt
              && newer.antiResurrectionUntil >= old.antiResurrectionUntil
              && old.evidence.receipts.allSatisfy(newer.evidence.receipts.contains)
          }
          if replacement { context.delete(row) }
        }
      }
    }
    return continuation
  }

  func load(in kitchenID: Kitchen.ID, context: ModelContext) throws -> Snapshot {
    let identifier = kitchenID.rawValue
    let policy = namespace
    let actions = try context.fetch(FetchDescriptor<OrganizationActionRecord>(predicate: #Predicate {
      $0.kitchenID == identifier && $0.namespace == policy
    })).map(decode)
    let checkpoints = try context.fetch(FetchDescriptor<OrganizationCheckpointRecord>(predicate: #Predicate {
      $0.kitchenID == identifier && $0.namespace == policy
    })).map(decode)
    for action in actions + checkpoints.flatMap({ $0.evidence.retained }) {
      try validateAssignment(action.payload, in: kitchenID, context: context, requireRecipe: false)
    }
    return Snapshot(actions: actions, checkpoints: checkpoints)
  }

  private func validateAssignment(_ payload: Payload, in kitchenID: Kitchen.ID,
                                  context: ModelContext, requireRecipe: Bool) throws {
    guard let recipeID = recipeID(payload) else { return }
    let identifier = recipeID.rawValue
    let recipes = try context.fetch(FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == identifier }))
    guard !requireRecipe || !recipes.isEmpty else { throw FolderError.missingRecipe(recipeID) }
    guard recipes.allSatisfy({ $0.kitchenID == kitchenID.rawValue }) else { throw FolderError.wrongKitchen }
  }

  private func decode(_ record: OrganizationActionRecord) throws -> OrganizationAction<Payload> {
    guard record.formatVersion == 1 else { throw FolderError.invalidEvidence }
    let action = try JSONDecoder().decode(OrganizationAction<Payload>.self, from: record.payloadData)
    guard action.id == record.id, action.authoredAt == record.authoredAt,
          try OrganizationCoding.encode(action) == record.payloadData,
          try OrganizationCoding.digest(action) == record.payloadDigest else { throw FolderError.invalidEvidence }
    return action
  }

  private func decode(_ record: OrganizationCheckpointRecord) throws -> Checkpoint {
    guard record.formatVersion == 1,
          record.antiResurrectionUntil >= record.createdAt.addingTimeInterval(1_827 * 86_400) else {
      throw FolderError.invalidEvidence
    }
    let evidence = try JSONDecoder().decode(OrganizationCheckpoint<Payload>.self, from: record.checkpointData)
    guard try OrganizationCoding.encode(evidence) == record.checkpointData,
          try OrganizationCoding.digest(evidence) == record.checkpointDigest else { throw FolderError.invalidEvidence }
    return Checkpoint(id: record.id, kitchenID: Kitchen.ID(rawValue: record.kitchenID),
                      createdAt: record.createdAt, antiResurrectionUntil: record.antiResurrectionUntil,
                      evidence: evidence)
  }
}
