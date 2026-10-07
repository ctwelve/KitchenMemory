// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData
import Algorithms

/// Owns Kitchen identity, ownership decoding, and owner-scope convergence.
@MainActor
final class KitchenRecordStore {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
  }

  func kitchen(id: Kitchen.ID) throws -> Kitchen? {
    let identifier = id.rawValue
    let descriptor = FetchDescriptor<KitchenRecord>(predicate: #Predicate { $0.id == identifier })
    return try context.fetch(descriptor).first.map {
      Kitchen(
        id: .init(rawValue: $0.id),
        ownerID: try ownerID(for: .init(rawValue: $0.id)),
        name: $0.name
      )
    }
  }

  func kitchens() throws -> [Kitchen] {
    let descriptor = FetchDescriptor<KitchenRecord>(sortBy: [SortDescriptor(\.name)])
    return try context.fetch(descriptor).uniqued(on: \.id).map {
      Kitchen(
        id: .init(rawValue: $0.id),
        ownerID: try ownerID(for: .init(rawValue: $0.id)),
        name: $0.name
      )
    }
  }

  func upsert(_ kitchen: Kitchen) throws {
    let identifier = kitchen.id.rawValue
    let descriptor = FetchDescriptor<KitchenRecord>(predicate: #Predicate { $0.id == identifier })
    if let record = try context.fetch(descriptor).first {
      record.name = kitchen.name
    } else {
      context.insert(KitchenRecord(id: identifier, name: kitchen.name))
    }
    if let ownerID = kitchen.ownerID {
      try replaceOwnership(of: kitchen.id, with: ownerID)
    }
  }

  private func ownerID(for kitchenID: Kitchen.ID) throws -> KitchenOwner.ID? {
    let identifier = kitchenID.rawValue
    let records = try context.fetch(
      FetchDescriptor<KitchenOwnershipRecord>(
        predicate: #Predicate { $0.kitchenID == identifier }
      )
    )
    let owners = Set(records.map(\.ownerID))
    guard owners.count <= 1 else {
      throw KitchenMemoryPersistenceError.kitchenOwnedByAnotherOwner(kitchenID: kitchenID)
    }
    return owners.first.map(KitchenOwner.ID.init(rawValue:))
  }

  private func replaceOwnership(
    of kitchenID: Kitchen.ID,
    with ownerID: KitchenOwner.ID
  ) throws {
    let identifier = kitchenID.rawValue
    var keptCanonicalRecord = false
    for record in try context.fetch(
      FetchDescriptor<KitchenOwnershipRecord>(
        predicate: #Predicate { $0.kitchenID == identifier }
      )
    ) {
      if !keptCanonicalRecord,
        record.id == identifier,
        record.ownerID == ownerID.rawValue {
        keptCanonicalRecord = true
      } else {
        context.delete(record)
      }
    }
    if !keptCanonicalRecord {
      context.insert(KitchenOwnershipRecord(
        id: identifier,
        kitchenID: identifier,
        ownerID: ownerID.rawValue
      ))
    }
  }

  func convergeKitchenRecords(
    into kitchen: Kitchen,
    ownedBy ownerID: KitchenOwner.ID
  ) throws {
    let kitchenRecords = try context.fetch(FetchDescriptor<KitchenRecord>())
    let ownershipRecords = try context.fetch(FetchDescriptor<KitchenOwnershipRecord>())
    for ownership in ownershipRecords where ownership.ownerID != ownerID.rawValue {
      throw KitchenMemoryPersistenceError.kitchenOwnedByAnotherOwner(
        kitchenID: Kitchen.ID(rawValue: ownership.kitchenID)
      )
    }
    try rehomeRecipeRecords(to: kitchen.id.rawValue)
    try rehomeSessionRecords(to: kitchen.id.rawValue)
    try rehomeOrganizationRecords(to: kitchen.id.rawValue)
    try replaceKitchenRecords(with: kitchen, ownedBy: ownerID, existing: kitchenRecords)
  }

  private func rehomeRecipeRecords(to destinationID: UUID) throws {
    for record in try context.fetch(FetchDescriptor<RecipeRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<RecipeDeletionRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<RecipeSaveRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<RecipeSelectionRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<RecipePruneRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
  }

  private func rehomeOrganizationRecords(to destinationID: UUID) throws {
    for record in try context.fetch(FetchDescriptor<OrganizationActionRecord>())
    where record.kitchenID != destinationID { record.kitchenID = destinationID }
    for record in try context.fetch(FetchDescriptor<OrganizationCheckpointRecord>())
    where record.kitchenID != destinationID { record.kitchenID = destinationID }
  }

  private func rehomeSessionRecords(to destinationID: UUID) throws {
    for record in try context.fetch(FetchDescriptor<CookingSessionRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<SessionFactRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<SessionClosureRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<SessionDeletionRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
    for record in try context.fetch(FetchDescriptor<SessionDeletionResolutionRecord>())
    where record.kitchenID != destinationID {
      record.kitchenID = destinationID
    }
  }

  private func replaceKitchenRecords(
    with kitchen: Kitchen,
    ownedBy ownerID: KitchenOwner.ID,
    existing kitchenRecords: [KitchenRecord]
  ) throws {
    let destinationID = kitchen.id.rawValue
    var keptDestination = false
    for record in kitchenRecords {
      if record.id == destinationID, !keptDestination {
        if record.name != kitchen.name {
          record.name = kitchen.name
        }
        keptDestination = true
      } else {
        context.delete(record)
      }
    }
    if !keptDestination {
      context.insert(KitchenRecord(id: destinationID, name: kitchen.name))
    }
    for record in try context.fetch(FetchDescriptor<KitchenOwnershipRecord>())
    where record.kitchenID != destinationID {
      context.delete(record)
    }
    try replaceOwnership(of: kitchen.id, with: ownerID)
  }
}
