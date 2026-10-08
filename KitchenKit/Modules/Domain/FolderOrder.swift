// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

struct FolderOrder {
  let evidence: OrganizationEvidence<FolderChange>
  let folders: [Folder]

  var mode: FolderOrdering {
    let choices = evidence.actions.filter { if case .ordering = $0.payload { return true }; return false }
    if case let .ordering(mode) = evidence.winner(in: choices)?.payload { return mode }
    return .alphabetical
  }

  var manualIDs: [Folder.ID] {
    evidence.manualOrder(live: Set(folders.map(\.id)), creation: {
      if case let .create(id, _, _) = $0 { return id }
      return nil
    }, reorder: {
      if case let .reorder(id, anchor) = $0 { return (id, anchor) }
      return nil
    })
  }
}
