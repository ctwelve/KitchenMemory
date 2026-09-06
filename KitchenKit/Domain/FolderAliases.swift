// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Directed Merge promises survive payload compaction and old replica arrivals.
struct FolderAliases {
  let evidence: OrganizationEvidence<FolderChange>
  var deleted: Set<Folder.ID> = []

  var resolved: [Folder.ID: Folder.ID] {
    var candidates: [Folder.ID: [OrganizationAction<FolderChange>]] = [:]
    for action in evidence.actions {
      if case let .merge(ids, survivor, _) = action.payload {
        for id in ids where id != survivor && !deleted.contains(id) { candidates[id, default: []].append(action) }
      }
    }
    let edges = candidates.mapValues { actions -> Folder.ID in
      // Each group is nonempty in an acyclic graph and contains only Merge payloads.
      // swiftlint:disable:next force_unwrapping
      return evidence.winner(in: actions)!.payload.folderID!
    }
    var result: [Folder.ID: Folder.ID] = [:]
    for source in edges.keys {
      var path: [Folder.ID] = []
      var current = source
      while let next = edges[current] {
        if let index = path.firstIndex(of: current) {
          // Opposite concurrent merges may form a cycle. Keep an existing oldest identity.
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

  func oldest(in ids: Set<Folder.ID>) -> Folder.ID? {
    for action in evidence.actions {
      if case let .create(id, _, _) = action.payload, ids.contains(id) { return id }
    }
    return nil
  }
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
