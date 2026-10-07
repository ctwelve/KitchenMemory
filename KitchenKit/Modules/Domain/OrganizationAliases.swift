// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Directed merge promises, including deterministic opposite-merge cycle repair.
struct OrganizationAliases<ID: Hashable, Payload: OrganizationPayload> {
  let evidence: OrganizationEvidence<Payload>
  let deleted: Set<ID>
  let creation: (Payload) -> ID?
  let merge: (Payload) -> (ids: [ID], survivor: ID)?

  func oldest(in ids: Set<ID>) -> ID? {
    evidence.actions.compactMap { creation($0.payload) }.first { ids.contains($0) }
  }

  var resolved: [ID: ID] {
    var candidates: [ID: [OrganizationAction<Payload>]] = [:]
    for action in evidence.actions {
      if let value = merge(action.payload) {
        for id in value.ids where id != value.survivor && !deleted.contains(id) {
          candidates[id, default: []].append(action)
        }
      }
    }
    let edges = candidates.compactMapValues { actions in
      evidence.winner(in: actions).flatMap { merge($0.payload)?.survivor }
    }
    var result: [ID: ID] = [:]
    for source in edges.keys {
      var path: [ID] = []
      var current = source
      while let next = edges[current] {
        if let index = path.firstIndex(of: current) {
          current = oldest(in: Set(path[index...])) ?? current
          break
        }
        path.append(current)
        current = next
      }
      if source != current { result[source] = current }
    }
    return result
  }
}
