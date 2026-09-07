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

extension TagLibrary {
  public func orderedTags(locale: Locale = .current) -> [Tag] {
    let children = tags
    if ordering == .manual {
      let byID = Dictionary(uniqueKeysWithValues: children.map { ($0.id, $0) })
      return manualIDs.compactMap { byID[$0] }
    }
    return children.sorted {
      let comparison = $0.name.compare($1.name, options: .caseInsensitive, locale: locale)
      return comparison == .orderedSame ? $0.id.rawValue.uuidString < $1.id.rawValue.uuidString
        : comparison == .orderedAscending
    }
  }

}

extension TagLibrary {
  public var systemViewVisible: Bool {
    get throws {
      let evidence = try OrganizationEvidence(actions, checkpoints: checkpointEvidence)
      let choices = evidence.actions.filter { if case .systemViewVisible = $0.payload { return true }; return false }
      if case let .systemViewVisible(visible) = evidence.winner(in: choices)?.payload { return visible }
      return true
    }
  }
}
