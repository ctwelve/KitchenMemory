// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Separate live Tag identities with the same normalized Kitchen-wide name.
///
/// They remain distinct until a person explicitly renames or merges them.
public struct TagCollision: Equatable, Sendable {
  /// The distinct colliding live identities, sorted by UUID for stable repair presentation.
  public let tagIDs: [Tag.ID]

  static func detect(in tags: [Tag]) -> [TagCollision] {
    Dictionary(grouping: tags, by: { OrganizationName.comparisonKey($0.name) }).values
      .filter { $0.count > 1 }.map {
        TagCollision(tagIDs: $0.map(\.id).sorted { $0.rawValue.uuidString < $1.rawValue.uuidString })
      }.sorted {
        $0.tagIDs.map { $0.rawValue.uuidString }.lexicographicallyPrecedes($1.tagIDs.map { $0.rawValue.uuidString })
      }
  }
}
