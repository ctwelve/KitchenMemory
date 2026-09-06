// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

extension OrganizationEvidence {
  /// Replay independent neighbor choices while retaining creation order across mode changes.
  func manualOrder<ID: Hashable>(live: Set<ID>, creation: (Payload) -> ID?,
                                 reorder: (Payload) -> (id: ID, anchor: ID?)?) -> [ID] {
    var candidates: [ID: [Action]] = [:]
    for action in actions {
      if let choice = reorder(action.payload) { candidates[choice.id, default: []].append(action) }
    }
    let winners = Set(candidates.values.compactMap { winner(in: $0)?.id })
    var result: [ID] = []
    for action in replayOrder {
      if let id = creation(action.payload), live.contains(id), !result.contains(id) { result.append(id) }
      if let choice = reorder(action.payload), live.contains(choice.id), winners.contains(action.id) {
        result.removeAll { $0 == choice.id }
        if let anchor = choice.anchor {
          let index = result.firstIndex(of: anchor).map { $0 + 1 } ?? result.endIndex
          result.insert(choice.id, at: index)
        } else { result.insert(choice.id, at: 0) }
      }
    }
    return result
  }
}
