// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public enum FolderOrdering: String, Codable, Equatable, Sendable {
  case alphabetical
  case manual
}

struct FolderOrder {
  let evidence: OrganizationEvidence<FolderChange>
  let folders: [Folder]

  var mode: FolderOrdering {
    let choices = evidence.actions.filter { if case .ordering = $0.payload { return true }; return false }
    if case let .ordering(mode) = evidence.winner(in: choices)?.payload { return mode }
    return .alphabetical
  }

  var manualIDs: [Folder.ID] {
    let live = Set(folders.map(\.id))
    var candidates: [Folder.ID: [OrganizationAction<FolderChange>]] = [:]
    for action in evidence.actions {
      if case let .reorder(id, _) = action.payload { candidates[id, default: []].append(action) }
    }
    let winners = Set(candidates.values.compactMap { evidence.winner(in: $0)?.id })
    var result: [Folder.ID] = []
    for action in evidence.replayOrder {
      switch action.payload {
      case let .create(id, _, _) where live.contains(id):
        if !result.contains(id) { result.append(id) }
      case let .reorder(id, anchor) where live.contains(id) && winners.contains(action.id):
        result.removeAll { $0 == id }
        if let anchor {
          let index = result.firstIndex(of: anchor).map { $0 + 1 } ?? result.endIndex
          result.insert(id, at: index)
        } else { result.insert(id, at: 0) }
      default: break
      }
    }
    return result
  }
}

extension FolderLibrary {
  public func children(of parentID: Folder.ID?, locale: Locale = .current) -> [Folder] {
    let children = folders.filter { $0.parentID == parentID }
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

  func prepareOrder(id: Folder.ID, afterID: Folder.ID?) throws -> FolderChange {
    try validateParent(id)
    try validateParent(afterID)
    guard id != afterID else { throw FolderError.invalidOrder }
    if let afterID {
      let parents = Set(folders.filter { $0.id == id || $0.id == afterID }.map(\.parentID))
      guard parents.count == 1 else { throw FolderError.invalidOrder }
    }
    return .reorder(id: id, afterID: afterID)
  }

  func prepareCreation(id: Folder.ID, name: String, parentID: Folder.ID?) throws -> String {
    let displayName = try OrganizationName(name)
    guard !actions.contains(where: {
      if case let .create(existingID, _, _) = $0.payload { return existingID == id }
      return false
    }) else { throw FolderError.identityCollision(id) }
    try validateParent(parentID)
    try validateName(displayName.value, parentID: parentID)
    return displayName.value
  }
}
