// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Separate live Folder identities sharing one sibling name. Repair requires a person.
public struct FolderCollision: Equatable, Sendable {
  public let folderIDs: [Folder.ID]

  static func detect(in folders: [Folder]) -> [FolderCollision] {
    let siblings = Dictionary(grouping: folders, by: \.parentID)
    var collisions: [FolderCollision] = []
    for children in siblings.values {
      let names = Dictionary(grouping: children, by: { OrganizationName.comparisonKey($0.name) })
      for matches in names.values where matches.count > 1 {
        collisions.append(FolderCollision(folderIDs: matches.map(\.id).sorted {
          $0.rawValue.uuidString < $1.rawValue.uuidString
        }))
      }
    }
    return collisions.sorted {
      $0.folderIDs.map { $0.rawValue.uuidString }.lexicographicallyPrecedes(
        $1.folderIDs.map { $0.rawValue.uuidString }
      )
    }
  }
}
