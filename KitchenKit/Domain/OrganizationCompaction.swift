// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

extension OrganizationEvidence {
  /// Only complete, aged causal frontiers can replace raw evidence.
  func compact(rawIDs: Set<UUID>, at date: Date) -> OrganizationCheckpoint<Payload>? {
    let evidence = self
    let old = Set(evidence.receipts.filter { $0.authoredAt <= date.addingTimeInterval(-30 * 86_400) }.map(\.id))
    let eligible = Set(old.filter { candidate in
      evidence.graph.reachableNodes(from: [candidate]).allSatisfy { old.contains($0) }
    })
    guard !rawIDs.isDisjoint(with: eligible) else { return nil }
    let candidates = evidence.actions.filter { eligible.contains($0.id) }
    let groups = Dictionary(grouping: candidates.filter { $0.payload.compactableRegister != nil },
                            by: { $0.payload.compactableRegister })
    var retainedIDs = Set(candidates.filter { $0.payload.compactableRegister == nil }.map(\.id))
    for group in groups.values {
      retainedIDs.formUnion(evidence.graph.maximalNodes(among: group.map(\.id)))
    }
    return OrganizationCheckpoint(
      receipts: evidence.receipts.filter { eligible.contains($0.id) },
      retained: candidates.filter { retainedIDs.contains($0.id) }
    )
  }
}
