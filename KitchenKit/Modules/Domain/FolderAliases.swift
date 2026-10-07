// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Directed Merge promises survive payload compaction and old replica arrivals.
struct FolderAliases {
  let evidence: OrganizationEvidence<FolderChange>
  var deleted: Set<Folder.ID> = []

  private var shared: OrganizationAliases<Folder.ID, FolderChange> {
    OrganizationAliases(evidence: evidence, deleted: deleted, creation: {
      if case let .create(id, _, _) = $0 { return id }
      return nil
    }, merge: {
      if case let .merge(ids, survivor, _) = $0 { return (ids, survivor) }
      return nil
    })
  }

  var resolved: [Folder.ID: Folder.ID] { shared.resolved }
  func oldest(in ids: Set<Folder.ID>) -> Folder.ID? { shared.oldest(in: ids) }

}

extension FolderLibrary {
  func prepareMerge(ids: [Folder.ID], survivorID: Folder.ID?, name: String) throws -> FolderChange {
    let selected = Set(ids)
    guard selected.count >= 2, selected.count == ids.count else { throw FolderError.invalidMerge }
    for id in selected { try validateParent(id) }
    let parents = Set(folders.filter { selected.contains($0.id) }.map(\.parentID))
    guard parents.count == 1 else { throw FolderError.invalidMerge }
    let evidence = try OrganizationEvidence(actions, checkpoints: checkpointEvidence)
    guard let survivor = survivorID ?? FolderAliases(evidence: evidence).oldest(in: selected),
          selected.contains(survivor) else { throw FolderError.invalidMerge }
    let displayName = try OrganizationName(name)
    guard !folders.contains(where: {
      !selected.contains($0.id) && parents.contains($0.parentID)
        && OrganizationName.comparisonKey($0.name) == displayName.key
    }) else { throw FolderError.duplicateName }
    return .merge(ids: ids.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString },
                  survivorID: survivor, name: displayName.value)
  }
}
