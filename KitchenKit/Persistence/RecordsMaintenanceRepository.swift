// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// One maintenance boundary for accepted Kitchen evidence and retained dependencies.
/// Each opportunity limits complete aggregate transactions, never dependency evidence.
@MainActor
public final class RecordsMaintenanceRepository {
  private let container: ModelContainer
  private let kitchenID: Kitchen.ID
  private let batchSize: Int

  public init(modelContainer: ModelContainer, kitchenID: Kitchen.ID, batchSize: Int = 16) {
    container = modelContainer
    self.kitchenID = kitchenID
    self.batchSize = max(1, batchSize)
  }

  /// Nil marks the end of a sweep. A continuation resumes after the last candidate,
  /// including ineligible candidates; losing it safely repeats already committed work.
  public func run(_ job: RecordsMaintenanceJob, at date: Date, after: String?) throws -> String? {
    try Task.checkCancellation()
    switch job {
    case .deletedRecipes, .recipeTombstones:
      return try maintainRecipes(at: date, after: after, expireTombstone: job == .recipeTombstones)
    case .folders:
      return try compactFolders(at: date)
    case .tags:
      return try compactTags(at: date)
    case .folderCheckpoints, .folderOrphans:
      return try OrganizationStore<FolderChange>(modelContainer: container, namespace: "folders", recipeID: {
        if case let .assign(id, _) = $0 { return id }; return nil
      }).maintainCoveredEvidence(in: kitchenID, at: date, removeOldRaw: job == .folderOrphans,
                                 after: after, limit: batchSize)
    case .tagCheckpoints, .tagOrphans:
      return try OrganizationStore<TagChange>(modelContainer: container, namespace: "tags", recipeID: {
        if case let .assign(id, _) = $0 { return id }; return nil
      }).maintainCoveredEvidence(in: kitchenID, at: date, removeOldRaw: job == .tagOrphans,
                                 after: after, limit: batchSize)
    }
  }

  public func run(_ job: RecordsMaintenanceJob, at date: Date) throws -> Bool {
    try run(job, at: date, after: nil) == nil
  }

  private func maintainRecipes(at date: Date, after: String?, expireTombstone: Bool) throws -> String? {
    let context = ModelContext(container)
    let identifier = kitchenID.rawValue
    let ids: [UUID]
    if expireTombstone {
      ids = try context.fetch(FetchDescriptor<RecipePruneRecord>(
        predicate: #Predicate { $0.kitchenID == identifier }
      )).map(\.recipeID)
    } else {
      ids = try context.fetch(FetchDescriptor<RecipeDeletionRecord>(
        predicate: #Predicate { $0.kitchenID == identifier }
      )).map(\.recipeID)
    }
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    return try maintainPage(ids, after: after, limit: batchSize) { id in
      try repository.maintainRecipeCandidate(.init(rawValue: id), in: kitchenID, at: date,
                                            expireTombstone: expireTombstone)
    }
  }

  private func compactFolders(at date: Date) throws -> String? {
    let before = try rawCount(namespace: "folders")
    _ = try SwiftDataFolderRepository(modelContainer: container)
      .compact(in: kitchenID, at: date, maximumRemovals: batchSize)
    let after = try rawCount(namespace: "folders")
    return after > 0 && after < before ? "remaining" : nil
  }

  private func compactTags(at date: Date) throws -> String? {
    let before = try rawCount(namespace: "tags")
    _ = try SwiftDataTagRepository(modelContainer: container)
      .compact(in: kitchenID, at: date, maximumRemovals: batchSize)
    let after = try rawCount(namespace: "tags")
    return after > 0 && after < before ? "remaining" : nil
  }

  private func rawCount(namespace: String) throws -> Int {
    let identifier = kitchenID.rawValue
    return try ModelContext(container).fetchCount(FetchDescriptor<OrganizationActionRecord>(predicate: #Predicate {
      $0.kitchenID == identifier && $0.namespace == namespace
    }))
  }
}

/// Stable logical-identity continuation; concurrent arrivals behind it enter the next sweep.
func maintenancePage(_ ids: [UUID], after: String?, limit: Int) -> (ids: Set<UUID>, continuation: String?) {
  let candidates = Set(ids).sorted { $0.uuidString < $1.uuidString }
    .filter { id in after.map { id.uuidString > $0 } ?? true }
  let page = candidates.prefix(limit)
  return (Set(page), candidates.count > page.count ? page.last?.uuidString : nil)
}

/// A failed aggregate remains retained and is retried next sweep without starving later identities.
func maintainPage(_ ids: [UUID], after: String?, limit: Int,
                  operation: (UUID) throws -> Void) throws -> String? {
  let page = maintenancePage(ids, after: after, limit: limit)
  for id in page.ids.sorted(by: { $0.uuidString < $1.uuidString }) {
    try Task.checkCancellation()
    do {
      try operation(id)
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      continue
    }
  }
  return page.continuation
}
