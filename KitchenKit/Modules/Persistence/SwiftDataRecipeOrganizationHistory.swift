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
    return try prepareHistoryMember(recipeID, to: folderID, folders: folders, context: context)
      .map { member in RecipeOrganizationHistoryChange(anchorID: member.anchorID, recipeID: recipeID,
        before: member.before, after: member.after, baseline: member.baseline, folderBaseline: member.folderBaseline) }
  }

  private func prepareHistoryMember(
    _ recipeID: Recipe.ID, to folderID: Folder.ID?, folders: FolderLibrary, context: ModelContext
  ) throws -> RecipeOrganizationHistoryMember? {
    let before = folders.primaryFolder(for: recipeID)
    guard before != folderID else { return nil }
    let seed = RecipeOrganizationHistoryMember(anchorID: UUID(), recipeID: recipeID, before: before,
      after: folderID, baseline: Data(), folderBaseline: Data())
    return RecipeOrganizationHistoryMember(anchorID: seed.anchorID, recipeID: recipeID, before: before, after: folderID,
      baseline: try historyWitness(recipeID, folders: folders, context: context),
      folderBaseline: try historyFolderWitness(before: before, after: folderID, folders: folders))
  }

  public func prepareHistoryMove(
    _ recipeIDs: Set<Recipe.ID>, to folderID: Folder.ID?, in scope: RecipeOrganizationHistoryScope
  ) throws -> RecipeOrganizationHistoryChange? {
    let context = ModelContext(container)
    try validateHistoryScope(scope, context: context)
    let folders = try SwiftDataFolderRepository(modelContainer: container).library(
      in: scope.kitchenID, context: context)
    try requireHistoryFolder(folderID, folders: folders)
    let members = try recipeIDs.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }.compactMap { recipeID in
      try requireHistoryRecipe(recipeID, scope: scope, context: context)
      return try prepareHistoryMember(recipeID, to: folderID, folders: folders, context: context)
    }
    guard let first = members.first else { return nil }
    return RecipeOrganizationHistoryChange(anchorID: first.anchorID, recipeID: first.recipeID,
      before: first.before, after: first.after, baseline: first.baseline, folderBaseline: first.folderBaseline,
      members: members.count == 1 ? nil : members)
  }

  public func prepareHistoryDelivery(
    _ change: RecipeOrganizationHistoryChange, memberID: UUID, token: UndoKit.HistoryToken,
    in scope: RecipeOrganizationHistoryScope
  ) throws -> RecipeOrganizationHistoryDelivery {
    if change.tagChange != nil {
      return try prepareTagHistoryDelivery(change, memberID: memberID, token: token, scope: scope)
    }
    guard token.scope == scope.identity else { throw RecipeOrganizationHistoryError.invalidScope }
    let context = ModelContext(container)
    let folders = try SwiftDataFolderRepository(modelContainer: container).library(
      in: scope.kitchenID, context: context)
    // Freeze even an ineligible inverse before acceptance. Its exact intent remains retryable;
    // eligibility and all effects are still checked together by acceptHistory's fresh transaction.
    let evidence = try OrganizationEvidence(folders.actions, checkpoints: folders.checkpointEvidence)
    let commands = change.changedMembers.map { member in
      FolderCommand(kitchenID: scope.kitchenID, action: OrganizationAction(
        id: derivedID(namespace: token.command, kind: "history-folder", source: member.recipeID.rawValue),
        authoredAt: Date(), observed: evidence.heads,
        payload: .assign(recipeID: member.recipeID, folderID: member.after)))
    }
    let command = RecipeOrganizationCommand(id: token.command, kitchenID: scope.kitchenID, authoredAt: Date(),
      folders: commands, tags: [])
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
      if delivery.change.tagChange != nil {
        accepted = try commitTagHistory(delivery, recovery: recovery, receipts: receipts, context: context)
        return
      }
      try validateHistoryScope(delivery.scope, context: context)
      try validateHistoryDeliveryShape(delivery)
      let folders = try SwiftDataFolderRepository(modelContainer: container).library(
        in: delivery.scope.kitchenID, context: context)
      for member in delivery.change.changedMembers {
        try requireHistoryRecipe(member.recipeID, scope: delivery.scope, context: context)
        try requireHistoryFolder(member.before, folders: folders)
        try requireHistoryFolder(member.after, folders: folders)
        guard try historyFolderWitness(before: member.before, after: member.after, folders: folders)
                == member.folderBaseline,
              folders.primaryFolder(for: member.recipeID) == member.before,
              try historyWitness(member.recipeID, folders: folders, context: context)
                == foldedHistoryWitness(member, token: delivery.token, receipts: receipts) else {
          throw RecipeOrganizationHistoryError.ineligible
        }
      }
      guard try historyWitness(delivery.change, folders: folders, context: context) == delivery.beforeWitness,
            try foldedHistoryWitness(delivery.change, token: delivery.token, receipts: receipts)
              == delivery.beforeWitness
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

  private func validateHistoryDeliveryShape(_ delivery: RecipeOrganizationHistoryDelivery) throws {
    guard delivery.token.scope == delivery.scope.identity,
          delivery.command.kitchenID == delivery.scope.kitchenID,
          delivery.command.id == delivery.token.command,
          delivery.command.tags.isEmpty, delivery.command.folders.count == delivery.change.changedMembers.count,
          delivery.command.folders.allSatisfy({ $0.kitchenID == delivery.scope.kitchenID }),
          Set(delivery.command.folders.compactMap { command -> Recipe.ID? in
            guard case let .assign(recipeID, _) = command.action.payload else { return nil }
            return recipeID
          }) == Set(delivery.change.changedMembers.map(\.recipeID)),
          delivery.command.folders.allSatisfy({ command in
            delivery.change.changedMembers.contains { member in
              command.action.payload == .assign(recipeID: member.recipeID, folderID: member.after)
            }
          }) else {
      throw RecipeOrganizationHistoryError.invalidScope
    }
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
    for receipt in owned {
      let change = receipt.delivery.change
      if let tagChange = change.tagChange {
        guard try tagHistoryIsEligible(tagChange, scope: scope, token: receipt.delivery.token,
          receipts: receipts, context: context) else { return false }
        continue
      }
      for member in change.changedMembers where seen.insert(member.anchorID).inserted {
        guard (try? requireHistoryRecipe(member.recipeID, scope: scope, context: context)) != nil,
              (try? requireHistoryFolder(member.before, folders: folders)) != nil,
              (try? requireHistoryFolder(member.after, folders: folders)) != nil,
              try historyFolderWitness(before: member.before, after: member.after, folders: folders)
                == member.folderBaseline,
              try historyWitness(member.recipeID, folders: folders, context: context)
                == foldedHistoryWitness(member, token: receipt.delivery.token, receipts: receipts) else { return false }
      }
    }
    return true
  }

  func historyReceiptStore(recovery: Bool = false) -> OrganizationStore<OrganizationHistoryReceiptPayload> {
    OrganizationStore(modelContainer: container,
      namespace: recovery ? "organization-history-recoveries-v1" : "organization-history-receipts-v1",
      recipeID: { _ in nil })
  }

  func historyReceipts(in kitchenID: Kitchen.ID, context: ModelContext, recovery: Bool = false)
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
                                    receipts: [RecipeOrganizationHistoryReceipt]) throws -> Data {
    guard change.members != nil else {
      return foldedHistoryWitness(change.changedMembers[0], token: token, receipts: receipts)
    }
    let entries = change.changedMembers.map { member in
      OrganizationBatchWitnessEntry(recipeID: member.recipeID,
        witness: foldedHistoryWitness(member, token: token, receipts: receipts))
    }
    return try OrganizationCoding.encode(OrganizationBatchWitness(entries: entries))
  }

  private func foldedHistoryWitness(_ member: RecipeOrganizationHistoryMember, token: OrganizationHistoryToken,
                                    receipts: [RecipeOrganizationHistoryReceipt]) -> Data {
    var witness = member.baseline
    let owned = receipts.filter {
      $0.delivery.token.scope == token.scope && $0.delivery.token.generation == token.generation
    }
      .sorted { $0.delivery.token.sequence < $1.delivery.token.sequence }
    for receipt in owned {
      guard receipt.delivery.change.tagChange == nil,
        receipt.delivery.change.changedMembers.contains(where: { $0.recipeID == member.recipeID }),
        let before = batchMemberWitness(receipt.delivery.beforeWitness, recipeID: member.recipeID,
          single: receipt.delivery.change.members == nil),
        let after = batchMemberWitness(receipt.afterWitness, recipeID: member.recipeID,
          single: receipt.delivery.change.members == nil) else { continue }
      if before == witness { witness = after }
    }
    return witness
  }

  private func historyWitness(_ change: RecipeOrganizationHistoryChange, folders: FolderLibrary,
                              context: ModelContext) throws -> Data {
    if change.members == nil {
      return try historyWitness(change.recipeID, folders: folders, context: context)
    }
    let entries = try change.changedMembers.map { member in
      OrganizationBatchWitnessEntry(recipeID: member.recipeID,
        witness: try historyWitness(member.recipeID, folders: folders, context: context))
    }
    return try OrganizationCoding.encode(OrganizationBatchWitness(entries: entries))
  }

  private func batchMemberWitness(_ data: Data, recipeID: Recipe.ID, single: Bool) -> Data? {
    if single { return data }
    return (try? JSONDecoder().decode(OrganizationBatchWitness.self, from: data))?.entries
      .first(where: { $0.recipeID == recipeID })?.witness
  }

  private func historyWitness(_ recipeID: Recipe.ID, folders: FolderLibrary, context: ModelContext) throws -> Data {
    let evidence = try OrganizationEvidence(folders.actions, checkpoints: folders.checkpointEvidence)
    let register = "membership:\(recipeID.rawValue.uuidString)"
    let assignments = evidence.receipts.filter { $0.register == register }
    let recipe = recipeID.rawValue
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

  private func historyFolderWitness(before: Folder.ID?, after: Folder.ID?, folders: FolderLibrary) throws -> Data {
    let folderIDs = Set([before, after].compactMap { $0 })
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

  func requireHistoryRecipe(_ recipeID: Recipe.ID, scope: RecipeOrganizationHistoryScope,
                                    context: ModelContext) throws {
    guard let recipe = try SwiftDataRecipeRepository(context: context).recipe(id: recipeID),
          recipe.recipe.kitchenID == scope.kitchenID else { throw RecipeOrganizationHistoryError.ineligible }
  }

  private func requireHistoryFolder(_ folderID: Folder.ID?, folders: FolderLibrary) throws {
    if let folderID, folders.canonicalFolderID(for: folderID) != folderID {
      throw RecipeOrganizationHistoryError.ineligible
    }
  }

  func validateHistoryScope(_ scope: RecipeOrganizationHistoryScope, context: ModelContext) throws {
    guard !scope.storeID.isEmpty, !scope.ownerID.rawValue.isEmpty,
          let kitchen = try KitchenRecordStore(context: context).kitchen(id: scope.kitchenID),
          kitchen.ownerID == nil || kitchen.ownerID == scope.ownerID else {
      throw RecipeOrganizationHistoryError.invalidScope
    }
  }
}

struct OrganizationHistoryReceiptPayload: OrganizationPayload {
  let version: Int
  let receipt: RecipeOrganizationHistoryReceipt
  var compactableRegister: String? { nil }
}

private struct OrganizationHistoryWitness: Codable {
  let organization: [OrganizationReceipt]
  let deletions: [UUID]
  let restorations: [UUID]
}

private struct OrganizationBatchWitness: Codable {
  let entries: [OrganizationBatchWitnessEntry]
}

private struct OrganizationBatchWitnessEntry: Codable {
  let recipeID: Recipe.ID
  let witness: Data
}
