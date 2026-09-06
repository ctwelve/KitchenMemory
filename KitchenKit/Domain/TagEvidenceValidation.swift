// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

enum TagEvidenceValidation {
  static func validate(_ evidence: OrganizationEvidence<TagChange>) throws {
    var creations: Set<Tag.ID> = []
    for action in evidence.actions {
      try validatePayload(action.payload)
      if case let .create(id, _) = action.payload, !creations.insert(id).inserted {
        throw TagError.identityCollision(id)
      }
      if case let .remove(recipe, dots) = action.payload {
        try validateRemoval(recipe: recipe, dots: dots, action: action, evidence: evidence)
      }
    }
  }

  private static func validatePayload(_ payload: TagChange) throws {
    switch payload {
    case let .create(_, name), let .rename(_, name): try validateName(name)
    case let .merge(ids, survivor, name):
      guard ids.count >= 2, Set(ids).count == ids.count, ids.contains(survivor) else {
        throw TagError.invalidEvidence
      }
      try validateName(name)
    case let .reorder(id, anchor):
      guard id != anchor else { throw TagError.invalidEvidence }
    case .remove, .assign, .delete, .ordering: break
    }
  }

  private static func validateRemoval(recipe: Recipe.ID, dots: [UUID],
                                      action: OrganizationAction<TagChange>,
                                      evidence: OrganizationEvidence<TagChange>) throws {
    guard Set(dots).count == dots.count else { throw TagError.invalidEvidence }
    let known = Set(evidence.receipts.map(\.id))
    let complete = evidence.graph.reachableNodes(from: [action.id]).allSatisfy { known.contains($0) }
    let byID = Dictionary(uniqueKeysWithValues: evidence.actions.map { ($0.id, $0) })
    for dot in dots {
      guard !complete || evidence.graph.isAncestor(dot, of: action.id) else { throw TagError.invalidEvidence }
      if let observed = byID[dot] {
        guard case let .assign(assignedRecipe, _) = observed.payload, assignedRecipe == recipe else {
          throw TagError.invalidEvidence
        }
      }
    }
  }

  private static func validateName(_ name: String) throws {
    guard try TagName(name).value == name else { throw TagError.invalidEvidence }
  }
}
