// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData
import UndoKit

extension SwiftDataRecipeOrganizationRepository {
  public func prepareHistoryTags(_ recipeIDs: Set<Recipe.ID>, tagID: Tag.ID, adding: Bool,
                                 in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryChange? {
    let context = ModelContext(container)
    try validateHistoryScope(scope, context: context)
    let tags = try SwiftDataTagRepository(modelContainer: container).library(in: scope.kitchenID, context: context)
    try requireHistoryTag(tagID, tags: tags)
    let projection = TagProjection(evidence: try OrganizationEvidence(
      tags.actions, checkpoints: tags.checkpointEvidence))
    let members = try recipeIDs.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }.compactMap { recipeID in
      try requireHistoryRecipe(recipeID, scope: scope, context: context)
      let dots = projection.assignments(recipeID: recipeID, tagID: tagID)
      guard adding ? dots.isEmpty : !dots.isEmpty else { return nil as RecipeOrganizationTagHistoryMember? }
      return RecipeOrganizationTagHistoryMember(anchorID: UUID(), recipeID: recipeID,
        logicalDots: adding ? [UUID()] : dots.sorted { $0.uuidString < $1.uuidString },
        baseline: try tagHistoryWitness(recipeID, tagID: tagID, tags: tags, context: context))
    }
    guard !members.isEmpty else { return nil }
    return RecipeOrganizationHistoryChange(tagChange: RecipeOrganizationTagHistoryChange(
      tagID: tagID, adding: adding, members: members))
  }

  func prepareTagHistoryDelivery(_ change: RecipeOrganizationHistoryChange, memberID: UUID, token: UndoKit.HistoryToken,
                                 scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryDelivery {
    guard token.scope == scope.identity, let intent = change.tagChange else {
      throw RecipeOrganizationHistoryError.invalidScope
    }
    let context = ModelContext(container)
    let tags = try SwiftDataTagRepository(modelContainer: container).library(in: scope.kitchenID, context: context)
    let receipts = try historyReceipts(in: scope.kitchenID, context: context)
    let commands = try tagHistoryCommands(intent, token: OrganizationHistoryToken(token), scope: scope,
      tags: tags, receipts: receipts)
    let command = RecipeOrganizationCommand(id: token.command, kitchenID: scope.kitchenID,
      authoredAt: commands.first?.action.authoredAt ?? Date(), folders: [], tags: commands)
    return RecipeOrganizationHistoryDelivery(scope: scope, token: OrganizationHistoryToken(token), memberID: memberID,
      change: change, command: command, beforeWitness: try tagBatchWitness(intent, tags: tags, context: context))
  }

  func commitTagHistory(_ delivery: RecipeOrganizationHistoryDelivery, recovery: Bool,
                        receipts: [RecipeOrganizationHistoryReceipt], context: ModelContext)
    throws -> RecipeOrganizationHistoryReceipt {
    try validateHistoryScope(delivery.scope, context: context)
    guard let intent = delivery.change.tagChange, delivery.token.scope == delivery.scope.identity,
          delivery.command.id == delivery.token.command, delivery.command.kitchenID == delivery.scope.kitchenID,
          delivery.command.folders.isEmpty else { throw RecipeOrganizationHistoryError.invalidScope }
    let tags = try SwiftDataTagRepository(modelContainer: container)
      .library(in: delivery.scope.kitchenID, context: context)
    guard try tagHistoryIsEligible(intent, scope: delivery.scope, token: delivery.token, receipts: receipts,
      context: context) else { throw RecipeOrganizationHistoryError.ineligible }
    let expected = try tagHistoryCommands(intent, token: delivery.token, scope: delivery.scope,
      tags: tags, receipts: receipts, date: delivery.command.authoredAt, requireCurrent: true)
    let known = Set(try OrganizationEvidence(tags.actions, checkpoints: tags.checkpointEvidence).receipts.map(\.id))
    // The frozen frontier belongs to preparation. Unrelated later heads cannot
    // replace it; payload, identity, date and relevant witnesses still must match.
    guard delivery.command.tags.count == expected.count,
          zip(delivery.command.tags, expected).allSatisfy({ frozen, expected in
            frozen.kitchenID == expected.kitchenID && frozen.id == expected.id
              && frozen.action.authoredAt == expected.action.authoredAt
              && frozen.action.payload == expected.action.payload
              && Set(frozen.action.observed).count == frozen.action.observed.count
              && Set(frozen.action.observed).isSubset(of: known)
          }),
          try tagBatchWitness(intent, tags: tags, context: context) == delivery.beforeWitness else {
      throw RecipeOrganizationHistoryError.ineligible
    }
    try accept(delivery.command, firstSave: nil, context: context)
    let after = try SwiftDataTagRepository(modelContainer: container)
      .library(in: delivery.scope.kitchenID, context: context)
    let receipt = RecipeOrganizationHistoryReceipt(delivery: delivery,
      afterWitness: try tagBatchWitness(intent, tags: after, context: context))
    let action = OrganizationAction(id: recovery ? delivery.token.recoveryReceiptID : delivery.token.receiptID,
      authoredAt: delivery.command.authoredAt, observed: [],
      payload: OrganizationHistoryReceiptPayload(version: 1, receipt: receipt))
    try historyReceiptStore(recovery: recovery).append(action, in: delivery.scope.kitchenID, context: context) {
      guard $0.checkpoints.isEmpty else { throw RecipeOrganizationHistoryError.invalidEvidence }
      _ = try OrganizationEvidence($0.actions)
    }
    return receipt
  }

  func tagHistoryIsEligible(_ intent: RecipeOrganizationTagHistoryChange, scope: RecipeOrganizationHistoryScope,
                            token: OrganizationHistoryToken, receipts: [RecipeOrganizationHistoryReceipt],
                            context: ModelContext) throws -> Bool {
    let tags = try SwiftDataTagRepository(modelContainer: container).library(in: scope.kitchenID, context: context)
    guard tags.canonicalTagID(for: intent.tagID) == intent.tagID,
          !intent.members.isEmpty,
          Set(intent.members.map(\.recipeID)).count == intent.members.count,
          intent.members.map(\.recipeID) == intent.members.map(\.recipeID).sorted(by: {
            $0.rawValue.uuidString < $1.rawValue.uuidString
          }) else { return false }
    for member in intent.members {
      guard !member.logicalDots.isEmpty, Set(member.logicalDots).count == member.logicalDots.count,
            (try? requireHistoryRecipe(member.recipeID, scope: scope, context: context)) != nil else { return false }
      var witness = member.baseline
      for receipt in tagOwnedReceipts(token, receipts: receipts) {
        guard let prior = receipt.delivery.change.tagChange, prior.tagID == intent.tagID,
              prior.members.contains(where: { $0.recipeID == member.recipeID }),
              let before = try? JSONDecoder().decode(TagHistoryBatchWitness.self, from: receipt.delivery.beforeWitness),
              let after = try? JSONDecoder().decode(TagHistoryBatchWitness.self, from: receipt.afterWitness),
              let old = before.entries.first(where: { $0.recipeID == member.recipeID }),
              let new = after.entries.first(where: { $0.recipeID == member.recipeID }) else { continue }
        if witness == old.witness { witness = new.witness }
      }
      guard try tagHistoryWitness(member.recipeID, tagID: intent.tagID, tags: tags, context: context) == witness
      else { return false }
    }
    return true
  }

  private func tagHistoryCommands(_ intent: RecipeOrganizationTagHistoryChange, token: OrganizationHistoryToken,
                                  scope: RecipeOrganizationHistoryScope, tags: TagLibrary,
                                  receipts: [RecipeOrganizationHistoryReceipt], date: Date = Date(),
                                  requireCurrent: Bool = false) throws -> [TagCommand] {
    let evidence = try OrganizationEvidence(tags.actions, checkpoints: tags.checkpointEvidence)
    let projection = TagProjection(evidence: evidence)
    let lineage = TagHistoryLineage(receipts: tagOwnedReceipts(token, receipts: receipts), tagID: intent.tagID)
    return try intent.members.flatMap { member in
      if intent.adding {
        return member.logicalDots.map { dot in
          TagCommand(kitchenID: scope.kitchenID, action: OrganizationAction(
            id: tagHistoryAssignmentID(token, dot: dot), authoredAt: date, observed: evidence.heads,
            payload: .assign(recipeID: member.recipeID, tagID: intent.tagID)))
        }
      }
      let dots = member.logicalDots.map { lineage.current($0) }
      guard !requireCurrent || (Set(dots).count == dots.count
        && Set(dots).isSubset(of: projection.assignments(recipeID: member.recipeID, tagID: intent.tagID))) else {
        throw RecipeOrganizationHistoryError.ineligible
      }
      return [
        TagCommand(kitchenID: scope.kitchenID, action: OrganizationAction(
        id: derivedID(namespace: token.command, kind: "history-tag-remove", source: member.anchorID),
        authoredAt: date, observed: evidence.heads,
        payload: .remove(recipeID: member.recipeID, assignments: dots.sorted { $0.uuidString < $1.uuidString }))),
      ]
    }
  }

  private func tagOwnedReceipts(_ token: OrganizationHistoryToken, receipts: [RecipeOrganizationHistoryReceipt])
    -> [RecipeOrganizationHistoryReceipt] {
    receipts.filter { $0.delivery.token.scope == token.scope && $0.delivery.token.generation == token.generation }
      .sorted { $0.delivery.token.sequence < $1.delivery.token.sequence }
  }

  private func tagBatchWitness(_ intent: RecipeOrganizationTagHistoryChange, tags: TagLibrary,
                               context: ModelContext) throws -> Data {
    try OrganizationCoding.encode(TagHistoryBatchWitness(entries: intent.members.map { member in
      TagHistoryWitnessEntry(recipeID: member.recipeID,
        witness: try tagHistoryWitness(member.recipeID, tagID: intent.tagID, tags: tags, context: context))
    }))
  }

  private func tagHistoryWitness(_ recipeID: Recipe.ID, tagID: Tag.ID, tags: TagLibrary,
                                 context: ModelContext) throws -> Data {
    let evidence = try OrganizationEvidence(tags.actions, checkpoints: tags.checkpointEvidence)
    let projection = TagProjection(evidence: evidence)
    let pairAssignments = Set(evidence.actions.compactMap { action -> UUID? in
      guard case let .assign(recipe, tag) = action.payload, recipe == recipeID,
            (projection.aliases[tag] ?? tag) == tagID else { return nil }
      return action.id
    })
    let relevant = Set(evidence.actions.filter { action in
      switch action.payload {
      case let .assign(recipe, tag): return recipe == recipeID && (projection.aliases[tag] ?? tag) == tagID
      case let .remove(recipe, dots): return recipe == recipeID && !pairAssignments.isDisjoint(with: dots)
      case let .merge(ids, survivor, _): return ids.contains(tagID) || survivor == tagID
      default: return action.payload.tagID == tagID
      }
    }.map(\.id))
    let recipe = recipeID.rawValue
    let deletions = try context.fetch(FetchDescriptor<RecipeDeletionRecord>(
      predicate: #Predicate { $0.recipeID == recipe }))
    let restorations = try context.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>(
      predicate: #Predicate { $0.recipeID == recipe }))
    return try OrganizationCoding.encode(TagHistoryWitness(organization: evidence.receipts.filter {
      relevant.contains($0.id) || $0.register == "name:\(tagID.rawValue.uuidString)"
    }, deletions: deletions.map(\.id).sorted { $0.uuidString < $1.uuidString },
      restorations: restorations.map(\.id).sorted { $0.uuidString < $1.uuidString }))
  }

  private func requireHistoryTag(_ tagID: Tag.ID, tags: TagLibrary) throws {
    guard tags.canonicalTagID(for: tagID) == tagID else { throw RecipeOrganizationHistoryError.ineligible }
  }
}

private struct TagHistoryWitness: Codable {
  let organization: [OrganizationReceipt]
  let deletions: [UUID]
  let restorations: [UUID]
}

private struct TagHistoryBatchWitness: Codable { let entries: [TagHistoryWitnessEntry] }
private struct TagHistoryWitnessEntry: Codable { let recipeID: Recipe.ID; let witness: Data }

private func tagHistoryAssignmentID(_ token: OrganizationHistoryToken, dot: UUID) -> UUID {
  derivedID(namespace: token.command, kind: "history-tag-assign", source: dot)
}

/// An older action follows only its own logical dot through fresh accepted replacements.
private struct TagHistoryLineage {
  var links: [UUID: Set<UUID>] = [:]
  var assignments: [UUID] = []

  init(receipts: [RecipeOrganizationHistoryReceipt], tagID: Tag.ID) {
    for receipt in receipts {
      guard let intent = receipt.delivery.change.tagChange, intent.tagID == tagID, intent.adding else { continue }
      for member in intent.members {
        for dot in member.logicalDots {
          let fresh = tagHistoryAssignmentID(receipt.delivery.token, dot: dot)
          links[dot, default: []].insert(fresh)
          links[fresh, default: []].insert(dot)
          assignments.append(fresh)
        }
      }
    }
  }

  func current(_ dot: UUID) -> UUID {
    var visited: Set<UUID> = [dot]
    var pending = [dot]
    while let next = pending.popLast() {
      for linked in links[next] ?? [] where visited.insert(linked).inserted { pending.append(linked) }
    }
    return assignments.last(where: visited.contains) ?? dot
  }
}
