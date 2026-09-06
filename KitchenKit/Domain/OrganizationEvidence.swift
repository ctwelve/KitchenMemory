// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Shared immutable identity and causal context for organization policies.
struct OrganizationAction<Payload: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
  let id: UUID
  let authoredAt: Date
  let observed: [UUID]
  let payload: Payload
}

/// Coalescing and causal registers are shared; Folder and Tag policies own their values.
struct OrganizationEvidence<Payload: Codable & Equatable & Sendable> {
  typealias Action = OrganizationAction<Payload>
  let actions: [Action]
  let graph: CausalGraph<UUID>

  init(_ input: [Action]) throws {
    var retained: [UUID: Action] = [:]
    for action in input {
      if let prior = retained[action.id], prior != action { throw FolderError.actionCollision(action.id) }
      retained[action.id] = action
    }
    actions = retained.values.sorted(by: Self.precedes)
    graph = CausalGraph(parentsByNode: retained.mapValues(\.observed), orderedBy: { $0.uuidString < $1.uuidString })
    guard !graph.containsCycle else { throw FolderError.causalCycle }
  }

  var heads: [UUID] { graph.maximalNodes }

  var replayOrder: [Action] {
    var pending = actions
    var emitted: Set<UUID> = []
    let known = Set(actions.map(\.id))
    var result: [Action] = []
    while let index = pending.firstIndex(where: {
      $0.observed.allSatisfy { emitted.contains($0) || !known.contains($0) }
    }) {
      let next = pending.remove(at: index)
      emitted.insert(next.id)
      result.append(next)
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
