// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

extension TagLibrary {
  /// Returns Tags in shared manual order or locale-aware case-insensitive name order.
  ///
  /// Equal names use stable UUID ties; no name collision is automatically merged.
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
  /// The causally selected Untagged visibility preference, defaulting to true.
  ///
  /// Reconstructing retained organization evidence can throw shared evidence errors.
  public var systemViewVisible: Bool {
    get throws {
      let evidence = try OrganizationEvidence(actions, checkpoints: checkpointEvidence)
      let choices = evidence.actions.filter { if case .systemViewVisible = $0.payload { return true }; return false }
      if case let .systemViewVisible(visible) = evidence.winner(in: choices)?.payload { return visible }
      return true
    }
  }
}
