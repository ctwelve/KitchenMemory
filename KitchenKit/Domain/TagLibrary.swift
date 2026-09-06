// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Reconstructs Tag state without depending on persistence or Recipe payloads.
public struct TagLibrary: Equatable, Sendable {
  public let kitchenID: Kitchen.ID
  public let tags: [Tag]
  public let collisions: [TagCollision]
  public let ordering: TagOrdering
  let manualIDs: [Tag.ID]
  let aliases: [Tag.ID: Tag.ID]
  let memberships: [Recipe.ID: Set<Tag.ID>]
  let checkpointEvidence: [OrganizationCheckpoint<TagChange>]
  let rawActionIDs: Set<UUID>
  let actions: [OrganizationAction<TagChange>]

  public init(kitchenID: Kitchen.ID, commands: [TagCommand], checkpoints: [TagCheckpoint] = []) throws {
    guard commands.allSatisfy({ $0.kitchenID == kitchenID }),
          checkpoints.allSatisfy({ $0.kitchenID == kitchenID }) else { throw TagError.wrongKitchen }
    var retained: [UUID: TagCheckpoint] = [:]
    for checkpoint in checkpoints {
      guard checkpoint.antiResurrectionUntil >= checkpoint.createdAt.addingTimeInterval(1_827 * 86_400) else {
        throw TagError.invalidEvidence
      }
      if let prior = retained[checkpoint.id], prior != checkpoint { throw TagError.actionCollision(checkpoint.id) }
      retained[checkpoint.id] = checkpoint
    }
    checkpointEvidence = retained.values.sorted { $0.id.uuidString < $1.id.uuidString }.map(\.evidence)
    rawActionIDs = Set(commands.map(\.id)).subtracting(checkpointEvidence.flatMap(\.receipts).map(\.id))
    let checkpointsForReplay = checkpointEvidence
    let evidence = try tagBoundary {
      try OrganizationEvidence(commands.map(\.action), checkpoints: checkpointsForReplay)
    }
    try TagEvidenceValidation.validate(evidence)
    self.kitchenID = kitchenID
    actions = evidence.actions
    let projection = TagProjection(evidence: evidence)
    tags = projection.tags
    aliases = projection.aliases
    memberships = projection.memberships
    collisions = TagCollision.detect(in: tags)
    let order = TagOrder(evidence: evidence, tags: tags)
    ordering = order.mode
    manualIDs = order.manualIDs
  }

  public func canonicalTagID(for id: Tag.ID) -> Tag.ID? {
    let canonical = aliases[id] ?? id
    return tags.contains(where: { $0.id == canonical }) ? canonical : nil
  }

  public func tagIDs(for recipeID: Recipe.ID) -> Set<Tag.ID> { memberships[recipeID] ?? [] }

  public func recipeIDs(for tagID: Tag.ID) -> Set<Recipe.ID> {
    guard let canonical = canonicalTagID(for: tagID) else { return [] }
    return Set(memberships.compactMap { $0.value.contains(canonical) ? $0.key : nil })
  }

  public func prepare(_ intent: TagIntent, id: UUID = UUID(), at date: Date = Date()) throws -> TagCommand {
    try tagBoundary {
      let evidence = try OrganizationEvidence(actions, checkpoints: checkpointEvidence)
      let change = try prepareChange(intent, evidence: evidence)
      return TagCommand(kitchenID: kitchenID, action: OrganizationAction(
        id: id, authoredAt: date, observed: evidence.heads, payload: change
      ))
    }
  }

  private func prepareChange(_ intent: TagIntent, evidence: OrganizationEvidence<TagChange>) throws -> TagChange {
    switch intent {
    case let .create(tagID, name):
      return try prepareCreation(id: tagID, name: name)
    case let .rename(tagID, name):
      try requireTag(tagID)
      let displayName = try TagName(name).value
      try validateName(displayName, excluding: [tagID])
      return .rename(id: tagID, name: displayName)
    case let .assign(recipeID, tagID):
      try requireTag(tagID)
      return .assign(recipeID: recipeID, tagID: tagID)
    case let .remove(recipeID, tagID):
      try requireTag(tagID)
      let dots = TagProjection(evidence: evidence).assignments(recipeID: recipeID, tagID: tagID)
      return .remove(recipeID: recipeID, assignments: dots.sorted { $0.uuidString < $1.uuidString })
    case let .delete(tagID):
      try requireTag(tagID)
      return .delete(id: tagID)
    case let .merge(ids, survivorID, name):
      return try prepareMerge(ids: ids, survivorID: survivorID, name: name, evidence: evidence)
    case let .reorder(tagID, afterID):
      try requireTag(tagID)
      if let afterID { try requireTag(afterID) }
      guard tagID != afterID else { throw TagError.invalidOrder }
      return .reorder(id: tagID, afterID: afterID)
    case let .ordering(mode): return .ordering(mode)
    }
  }

  private func prepareCreation(id tagID: Tag.ID, name: String) throws -> TagChange {
      guard !actions.contains(where: {
        if case let .create(existing, _) = $0.payload { return existing == tagID }
        return false
      }) else { throw TagError.identityCollision(tagID) }
      let displayName = try TagName(name).value
      try validateName(displayName)
      return .create(id: tagID, name: displayName)
  }

  private func prepareMerge(ids: [Tag.ID], survivorID: Tag.ID?, name: String,
                            evidence: OrganizationEvidence<TagChange>) throws -> TagChange {
      let selected = Set(ids)
      guard selected.count >= 2, selected.count == ids.count else { throw TagError.invalidMerge }
      for tagID in selected { try requireTag(tagID) }
      guard let survivor = survivorID ?? TagProjection(evidence: evidence).aliasPolicy.oldest(in: selected),
            selected.contains(survivor) else { throw TagError.invalidMerge }
      let displayName = try TagName(name).value
      try validateName(displayName, excluding: selected)
      return .merge(ids: ids.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString },
                    survivorID: survivor, name: displayName)
  }

  private func requireTag(_ id: Tag.ID) throws {
    guard tags.contains(where: { $0.id == id }) else { throw TagError.missingTag(id) }
  }

  private func validateName(_ name: String, excluding ids: Set<Tag.ID> = []) throws {
    guard !tags.contains(where: {
      !ids.contains($0.id) && OrganizationName.comparisonKey($0.name) == OrganizationName.comparisonKey(name)
    }) else { throw TagError.duplicateName }
  }
}
