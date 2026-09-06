// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Shared immutable identity and causal context for organization policies.
struct OrganizationAction<Payload: OrganizationPayload>: Codable, Equatable, Sendable {
  let id: UUID
  let authoredAt: Date
  let observed: [UUID]
  let payload: Payload
}

/// Coalescing and causal registers are shared; Folder and Tag policies own their values.
struct OrganizationEvidence<Payload: OrganizationPayload> {
  typealias Action = OrganizationAction<Payload>
  let actions: [Action]
  let receipts: [OrganizationReceipt]
  let graph: CausalGraph<UUID>

  init(_ input: [Action], checkpoints: [OrganizationCheckpoint<Payload>] = []) throws {
    for checkpoint in checkpoints { try checkpoint.validate() }
    var summaries: [UUID: OrganizationReceipt] = [:]
    for receipt in checkpoints.flatMap(\.receipts) {
      if let prior = summaries[receipt.id], prior != receipt { throw FolderError.actionCollision(receipt.id) }
      summaries[receipt.id] = receipt
    }
    let covered = Set(summaries.keys)
    let retainedIDs = Set(checkpoints.flatMap(\.retained).map(\.id))
    var retained: [UUID: Action] = [:]
    for action in checkpoints.flatMap(\.retained) + input {
      let receipt = try action.receipt()
      if let prior = summaries[action.id], prior != receipt { throw FolderError.actionCollision(action.id) }
      summaries[action.id] = receipt
      if !covered.contains(action.id) || retainedIDs.contains(action.id) { retained[action.id] = action }
    }
    actions = retained.values.sorted(by: Self.precedes)
    receipts = summaries.values.sorted { $0.id.uuidString < $1.id.uuidString }
    graph = CausalGraph(parentsByNode: summaries.mapValues(\.observed), orderedBy: { $0.uuidString < $1.uuidString })
    guard !graph.containsCycle else { throw FolderError.causalCycle }
  }

  var heads: [UUID] { graph.maximalNodes }

  var replayOrder: [Action] {
    var pending = receipts.sorted {
      $0.authoredAt == $1.authoredAt ? $0.id.uuidString < $1.id.uuidString : $0.authoredAt < $1.authoredAt
    }
    var emitted: Set<UUID> = []
    let known = Set(receipts.map(\.id))
    let byID = Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
    var result: [Action] = []
    while let index = pending.firstIndex(where: {
      $0.observed.allSatisfy { emitted.contains($0) || !known.contains($0) }
    }) {
      let next = pending.remove(at: index)
      emitted.insert(next.id)
      if let action = byID[next.id] { result.append(action) }
    }
    return result
  }

  func winner(in candidates: [Action]) -> Action? {
    let maximal = Set(graph.maximalNodes(among: candidates.map(\.id)))
    return candidates.filter { maximal.contains($0.id) }.max(by: Self.precedes)
  }

  static func precedes(_ lhs: Action, _ rhs: Action) -> Bool {
    if lhs.authoredAt != rhs.authoredAt { return lhs.authoredAt < rhs.authoredAt }
    return lhs.id.uuidString < rhs.id.uuidString
  }
}
