// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData
import UndoKit

extension SwiftDataRecipeOrganizationRepository: RecipeOrganizationHistoryRepository {
  public func prepareHistoryMove(
    _ recipeID: Recipe.ID, to folderID: Folder.ID?, in scope: RecipeOrganizationHistoryScope
  ) throws -> RecipeOrganizationHistoryChange? {
    let context = ModelContext(container)
    try validateHistoryScope(scope, context: context)
    let folders = try SwiftDataFolderRepository(modelContainer: container).library(
      in: scope.kitchenID, context: context)
    try requireHistoryRecipe(recipeID, scope: scope, context: context)
    try requireHistoryFolder(folderID, folders: folders)
    let before = folders.primaryFolder(for: recipeID)
    guard before != folderID else { return nil }
    let seed = RecipeOrganizationHistoryChange(anchorID: UUID(), recipeID: recipeID,
      before: before, after: folderID, baseline: Data(), folderBaseline: Data())
    return RecipeOrganizationHistoryChange(anchorID: seed.anchorID, recipeID: recipeID, before: before, after: folderID,
      baseline: try historyWitness(seed, folders: folders, context: context),
      folderBaseline: try historyFolderWitness(seed, folders: folders))
  }

  public func prepareHistoryDelivery(
    _ change: RecipeOrganizationHistoryChange, memberID: UUID, token: UndoKit.HistoryToken,
    in scope: RecipeOrganizationHistoryScope
  ) throws -> RecipeOrganizationHistoryDelivery {
    guard token.scope == scope.identity else { throw RecipeOrganizationHistoryError.invalidScope }
    let context = ModelContext(container)
    let folders = try SwiftDataFolderRepository(modelContainer: container).library(
      in: scope.kitchenID, context: context)
    // Freeze even an ineligible inverse before acceptance. Its exact intent remains retryable;
    // eligibility and all effects are still checked together by acceptHistory's fresh transaction.
    let evidence = try OrganizationEvidence(folders.actions, checkpoints: folders.checkpointEvidence)
    let command = RecipeOrganizationCommand(id: token.command, kitchenID: scope.kitchenID, authoredAt: Date(),
      folders: [
        FolderCommand(kitchenID: scope.kitchenID, action: OrganizationAction(
          id: derivedID(namespace: token.command, kind: "history-folder", source: change.recipeID.rawValue),
          authoredAt: Date(), observed: evidence.heads,
          payload: .assign(recipeID: change.recipeID, folderID: change.after))),
      ], tags: [])
    return RecipeOrganizationHistoryDelivery(scope: scope, token: OrganizationHistoryToken(token), memberID: memberID,
      change: change, command: command, beforeWitness: try historyWitness(change, folders: folders, context: context))
  }

  public func acceptHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt {
    try commitHistory(delivery, recovery: false)
  }

  public func recoverHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt {
    try commitHistory(delivery, recovery: true)
  }

  private func commitHistory(_ delivery: RecipeOrganizationHistoryDelivery, recovery: Bool)
    throws -> RecipeOrganizationHistoryReceipt {
    let context = ModelContext(container)
    var accepted: RecipeOrganizationHistoryReceipt?
    try context.transaction {
      let receipts = try historyReceipts(in: delivery.scope.kitchenID, context: context)
      // The exact durable token wins before eligibility, including after later interference.
      let prior = recovery
        ? try historyReceipts(in: delivery.scope.kitchenID, context: context, recovery: true) : receipts
      if let receipt = prior.first(where: { $0.delivery.token == delivery.token }) {
        guard receipt.delivery == delivery else { throw RecipeOrganizationHistoryError.invalidEvidence }
        accepted = receipt
        return
      }
      try validateHistoryScope(delivery.scope, context: context)
      guard delivery.token.scope == delivery.scope.identity,
            delivery.command.kitchenID == delivery.scope.kitchenID,
            delivery.command.id == delivery.token.command,
            delivery.command.tags.isEmpty, delivery.command.folders.count == 1,
            delivery.command.folders.first?.kitchenID == delivery.scope.kitchenID,
            delivery.command.folders.first?.action.payload
              == .assign(recipeID: delivery.change.recipeID, folderID: delivery.change.after) else {
        throw RecipeOrganizationHistoryError.invalidScope
      }
      let folders = try SwiftDataFolderRepository(modelContainer: container).library(
        in: delivery.scope.kitchenID, context: context)
      try requireHistoryRecipe(delivery.change.recipeID, scope: delivery.scope, context: context)
      try requireHistoryFolder(delivery.change.before, folders: folders)
      try requireHistoryFolder(delivery.change.after, folders: folders)
      guard try historyFolderWitness(delivery.change, folders: folders) == delivery.change.folderBaseline,
            folders.primaryFolder(for: delivery.change.recipeID) == delivery.change.before,
            try historyWitness(delivery.change, folders: folders, context: context) == delivery.beforeWitness,
            foldedHistoryWitness(delivery.change, token: delivery.token, receipts: receipts) == delivery.beforeWitness
      else { throw RecipeOrganizationHistoryError.ineligible }
      try accept(delivery.command, firstSave: nil, context: context)
      let after = try SwiftDataFolderRepository(modelContainer: container).library(
        in: delivery.scope.kitchenID, context: context)
      let receipt = RecipeOrganizationHistoryReceipt(delivery: delivery,
        afterWitness: try historyWitness(delivery.change, folders: after, context: context))
      let receiptID = recovery ? delivery.token.recoveryReceiptID : delivery.token.receiptID
      let action = OrganizationAction(id: receiptID, authoredAt: delivery.command.authoredAt,
        observed: [], payload: OrganizationHistoryReceiptPayload(version: 1, receipt: receipt))
      try historyReceiptStore(recovery: recovery).append(
        action, in: delivery.scope.kitchenID, context: context
      ) { snapshot in
        guard snapshot.checkpoints.isEmpty else { throw RecipeOrganizationHistoryError.invalidEvidence }
        _ = try OrganizationEvidence(snapshot.actions)
      }
      accepted = receipt
    }
    guard let accepted else { throw RecipeOrganizationHistoryError.invalidEvidence }
    return accepted
  }

  public func historyReceipt(for token: UndoKit.HistoryToken, in scope: RecipeOrganizationHistoryScope)
    throws -> RecipeOrganizationHistoryReceipt? {
    guard token.scope == scope.identity else { throw RecipeOrganizationHistoryError.invalidScope }
    return try historyReceipts(in: scope.kitchenID, context: ModelContext(container))
      .first { $0.delivery.scope == scope && $0.delivery.token == OrganizationHistoryToken(token) }
  }

  public func historyIsEligible(in scope: RecipeOrganizationHistoryScope, generation: UUID) throws -> Bool {
    let context = ModelContext(container)
    try validateHistoryScope(scope, context: context)
    let folders = try SwiftDataFolderRepository(modelContainer: container).library(
      in: scope.kitchenID, context: context)
    let receipts = try historyReceipts(in: scope.kitchenID, context: context)
    let owned = receipts.filter { $0.delivery.scope == scope && $0.delivery.token.generation == generation }
      .sorted { $0.delivery.token.sequence < $1.delivery.token.sequence }
    var seen: Set<UUID> = []
    for receipt in owned where seen.insert(receipt.delivery.change.anchorID).inserted {
      let change = receipt.delivery.change
      guard (try? requireHistoryRecipe(change.recipeID, scope: scope, context: context)) != nil,
            (try? requireHistoryFolder(change.before, folders: folders)) != nil,
            (try? requireHistoryFolder(change.after, folders: folders)) != nil,
            try historyFolderWitness(change, folders: folders) == change.folderBaseline,
            try historyWitness(change, folders: folders, context: context)
              == foldedHistoryWitness(change, token: receipt.delivery.token, receipts: receipts) else { return false }
    }
    return true
  }

  private func historyReceiptStore(recovery: Bool = false) -> OrganizationStore<OrganizationHistoryReceiptPayload> {
    OrganizationStore(modelContainer: container,
      namespace: recovery ? "organization-history-recoveries-v1" : "organization-history-receipts-v1",
      recipeID: { _ in nil })
  }

  private func historyReceipts(in kitchenID: Kitchen.ID, context: ModelContext, recovery: Bool = false)
    throws -> [RecipeOrganizationHistoryReceipt] {
    let snapshot = try historyReceiptStore(recovery: recovery).load(in: kitchenID, context: context)
    guard snapshot.checkpoints.isEmpty else { throw RecipeOrganizationHistoryError.invalidEvidence }
    let evidence = try OrganizationEvidence(snapshot.actions)
    return try evidence.actions.map { action in
      let token = action.payload.receipt.delivery.token
      guard action.payload.version == 1, action.id == (recovery ? token.recoveryReceiptID : token.receiptID),
            action.payload.receipt.delivery.scope.kitchenID == kitchenID else {
        throw RecipeOrganizationHistoryError.invalidEvidence
      }
      return action.payload.receipt
    }
  }

  private func foldedHistoryWitness(_ change: RecipeOrganizationHistoryChange, token: OrganizationHistoryToken,
                                    receipts: [RecipeOrganizationHistoryReceipt]) -> Data {
    var witness = change.baseline
    let owned = receipts.filter { $0.delivery.token.scope == token.scope
      && $0.delivery.token.generation == token.generation && $0.delivery.change.recipeID == change.recipeID }
      .sorted { $0.delivery.token.sequence < $1.delivery.token.sequence }
    for receipt in owned where receipt.delivery.beforeWitness == witness { witness = receipt.afterWitness }
    return witness
  }

  private func historyWitness(_ change: RecipeOrganizationHistoryChange, folders: FolderLibrary,
                              context: ModelContext) throws -> Data {
    let evidence = try OrganizationEvidence(folders.actions, checkpoints: folders.checkpointEvidence)
    let register = "membership:\(change.recipeID.rawValue.uuidString)"
    let assignments = evidence.receipts.filter { $0.register == register }
    let recipe = change.recipeID.rawValue
    let deletions = try context.fetch(FetchDescriptor<RecipeDeletionRecord>(predicate: #Predicate {
      $0.recipeID == recipe
    }))
    let restorations = try context.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>(predicate: #Predicate {
      $0.recipeID == recipe
    }))
    return try OrganizationCoding.encode(OrganizationHistoryWitness(
      organization: assignments,
      deletions: deletions.map(\.id).sorted { $0.uuidString < $1.uuidString },
      restorations: restorations.map(\.id).sorted { $0.uuidString < $1.uuidString }))
  }

  private func historyFolderWitness(_ change: RecipeOrganizationHistoryChange, folders: FolderLibrary) throws -> Data {
    let folderIDs = Set([change.before, change.after].compactMap { $0 })
    let actions = folders.actions.filter { action in
      switch action.payload {
      case .assign: return false
      case let .delete(ids): return !folderIDs.isDisjoint(with: ids)
      case let .merge(ids, survivorID, _): return folderIDs.contains(survivorID) || !folderIDs.isDisjoint(with: ids)
      default: return action.payload.folderID.map(folderIDs.contains) ?? false
      }
    }
    let evidence = try OrganizationEvidence(folders.actions, checkpoints: folders.checkpointEvidence)
    let identities = Set(actions.map(\.id))
    let registers = Set(folderIDs.map { "name:\($0.rawValue.uuidString)" })
    return try OrganizationCoding.encode(evidence.receipts.filter {
      identities.contains($0.id) || $0.register.map(registers.contains) == true
    })
  }

  private func requireHistoryRecipe(_ recipeID: Recipe.ID, scope: RecipeOrganizationHistoryScope,
                                    context: ModelContext) throws {
    guard let recipe = try SwiftDataRecipeRepository(context: context).recipe(id: recipeID),
          recipe.recipe.kitchenID == scope.kitchenID else { throw RecipeOrganizationHistoryError.ineligible }
  }

  private func requireHistoryFolder(_ folderID: Folder.ID?, folders: FolderLibrary) throws {
    if let folderID, folders.canonicalFolderID(for: folderID) != folderID {
      throw RecipeOrganizationHistoryError.ineligible
    }
  }

  private func validateHistoryScope(_ scope: RecipeOrganizationHistoryScope, context: ModelContext) throws {
    guard !scope.storeID.isEmpty, !scope.ownerID.rawValue.isEmpty,
          let kitchen = try KitchenRecordStore(context: context).kitchen(id: scope.kitchenID),
          kitchen.ownerID == nil || kitchen.ownerID == scope.ownerID else {
      throw RecipeOrganizationHistoryError.invalidScope
    }
  }
}

private struct OrganizationHistoryReceiptPayload: OrganizationPayload {
  let version: Int
  let receipt: RecipeOrganizationHistoryReceipt
  var compactableRegister: String? { nil }
}

private struct OrganizationHistoryWitness: Codable {
  let organization: [OrganizationReceipt]
  let deletions: [UUID]
  let restorations: [UUID]
}
