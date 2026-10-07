// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

struct TagOrder {
  let evidence: OrganizationEvidence<TagChange>
  let tags: [Tag]

  var mode: TagOrdering {
    let choices = evidence.actions.filter { if case .ordering = $0.payload { return true }; return false }
    if case let .ordering(mode) = evidence.winner(in: choices)?.payload { return mode }
    return .alphabetical
  }

  var manualIDs: [Tag.ID] {
    evidence.manualOrder(live: Set(tags.map(\.id)), creation: {
      if case let .create(id, _) = $0 { return id }
      return nil
    }, reorder: {
      if case let .reorder(id, anchor) = $0 { return (id, anchor) }
      return nil
    })
  }
}
