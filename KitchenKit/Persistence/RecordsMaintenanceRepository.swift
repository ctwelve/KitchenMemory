// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// One maintenance boundary for accepted Kitchen evidence and its retained dependencies.
///
/// A conservative admission budget bounds the existing aggregate reconstruction algorithms.
/// Oversized evidence remains durable and due for a later opportunity; it is never truncated
/// to make a destructive decision. No Session expiry policy is introduced here.
@MainActor
public final class RecordsMaintenanceRepository {
  private let container: ModelContainer
  private let kitchenID: Kitchen.ID
  private let rowBudget: Int

  public init(modelContainer: ModelContainer, kitchenID: Kitchen.ID, rowBudget: Int = 4_096) {
    container = modelContainer
    self.kitchenID = kitchenID
    self.rowBudget = max(1, rowBudget)
  }

  /// Returns false when safe reconstruction exceeds this opportunity's admission budget.
  public func run(_ job: RecordsMaintenanceJob, at date: Date) throws -> Bool {
    try Task.checkCancellation()
    guard try admitsReconstruction() else { return false }
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    switch job {
    case .deletedRecipes:
      _ = try recipes.maintainRecipeEvidence(in: kitchenID, at: date, expireCompactEvidence: false)
    case .folders:
      _ = try SwiftDataFolderRepository(modelContainer: container).compact(in: kitchenID, at: date)
    case .tags:
      _ = try SwiftDataTagRepository(modelContainer: container).compact(in: kitchenID, at: date)
    case .compactEvidence:
      try recipes.maintainRecipeTombstones(in: kitchenID, at: date)
      try maintainOrganization(at: date, removeOldRaw: false)
    case .orphans:
      // Late raw copies already represented by reconstructive checkpoints can be removed.
      // Missing roots, Session evidence, and Recipe payload behind prune frontiers cannot:
      // those may be incomplete delivery or user-visible Recovery, not disposable orphans.
      try maintainOrganization(at: date, removeOldRaw: true)
    }
    return true
  }

  private func maintainOrganization(at date: Date, removeOldRaw: Bool) throws {
    try OrganizationStore<FolderChange>(modelContainer: container, namespace: "folders", recipeID: {
      if case let .assign(id, _) = $0 { return id }; return nil
    }).maintainCoveredEvidence(in: kitchenID, at: date, removeOldRaw: removeOldRaw)
    try Task.checkCancellation()
    try OrganizationStore<TagChange>(modelContainer: container, namespace: "tags", recipeID: {
      if case let .assign(id, _) = $0 { return id }; return nil
    }).maintainCoveredEvidence(in: kitchenID, at: date, removeOldRaw: removeOldRaw)
  }

  private func admitsReconstruction() throws -> Bool {
    let context = ModelContext(container)
    var remaining = rowBudget
    func admit<T: PersistentModel>(_ type: T.Type) throws -> Bool {
      var request = FetchDescriptor<T>()
      request.fetchLimit = remaining + 1
      let count = try context.fetch(request).count
      remaining -= count
      return remaining >= 0
    }
    let checks: [() throws -> Bool] = [
      { try admit(KitchenRecord.self) },
      { try admit(KitchenOwnershipRecord.self) },
      { try admit(RecipeRecord.self) },
      { try admit(RecipeDeletionRecord.self) },
      { try admit(RecipeDeletionResolutionRecord.self) },
      { try admit(RecipeRevisionRecord.self) },
      { try admit(RecipeMediaRecord.self) },
      { try admit(EquipmentRecord.self) },
      { try admit(IngredientSectionRecord.self) },
      { try admit(RecipeIngredientRecord.self) },
      { try admit(InstructionSectionRecord.self) },
      { try admit(InstructionStepRecord.self) },
      { try admit(RecipeSaveRecord.self) },
      { try admit(RecipeSelectionRecord.self) },
      { try admit(RecipePruneRecord.self) },
      { try admit(CookingSessionRecord.self) },
      { try admit(SessionFactRecord.self) },
      { try admit(SessionClosureRecord.self) },
      { try admit(SessionDeletionRecord.self) },
      { try admit(SessionDeletionResolutionRecord.self) },
      { try admit(OrganizationActionRecord.self) },
      { try admit(OrganizationCheckpointRecord.self) },
    ]
    guard try checks.allSatisfy({ try $0() }) else { return false }
    // Bound encoded causal history too: one checkpoint can represent many physical rows.
    let checkpoints = try context.fetch(FetchDescriptor<OrganizationCheckpointRecord>())
    let actions = try context.fetch(FetchDescriptor<OrganizationActionRecord>())
    guard checkpoints.reduce(0, { $0 + $1.checkpointData.count })
      + actions.reduce(0, { $0 + $1.payloadData.count }) <= 512_000 else { return false }
    return true
  }
}
