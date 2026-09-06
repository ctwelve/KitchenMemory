// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

struct FolderProjection {
  let evidence: OrganizationEvidence<FolderChange>

  var aliases: [Folder.ID: Folder.ID] { FolderAliases(evidence: evidence).resolved }

  var folders: [Folder] {
    let aliases = aliases
    var grouped: [Folder.ID: [OrganizationAction<FolderChange>]] = [:]
    for action in evidence.actions {
      if let id = action.payload.folderID, !deleted.contains(id), aliases[id] == nil {
        grouped[id, default: []].append(action)
      }
    }
    let names = grouped.compactMapValues { actions -> String? in
      guard actions.contains(where: {
        if case .create = $0.payload { return true }
        return false
      }) else { return nil }
      let nameActions = actions.filter {
        switch $0.payload {
        case .create, .rename, .merge: return true
        default: return false
        }
      }
      switch evidence.winner(in: nameActions)?.payload {
      case let .create(_, name, _), let .rename(_, name), let .merge(_, _, name): return name
      default: return nil
      }
    }
    let parentActions = grouped.mapValues { actions in
      actions.filter {
        switch $0.payload {
        case .create, .move: return true
        default: return false
        }
      }
    }
    var parents: [Folder.ID: Folder.ID] = [:]
    let choices = parentActions.values.compactMap { evidence.winner(in: $0) }
      .sorted(by: OrganizationEvidence<FolderChange>.precedes)
    for choice in choices {
      guard let child = choice.payload.folderID, names[child] != nil else { continue }
      var remaining = parentActions[child] ?? []
      while let candidate = evidence.winner(in: remaining) {
        guard let requested = candidate.payload.parentID else { break }
        let parent = aliases[requested] ?? requested
        guard names[parent] != nil else { break }
        if !closesCycle(child: child, parent: parent, parents: parents) {
          parents[child] = parent
          break
        }
        // Reject this move only. Its previously observed parent remains eligible.
        remaining.removeAll { $0.id == candidate.id }
      }
    }
    return names.map { Folder(id: $0.key, name: $0.value, parentID: parents[$0.key]) }
      .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
  }
  var deleted: Set<Folder.ID> {
    var result: Set<Folder.ID> = []
    for action in evidence.actions {
      if case let .delete(ids) = action.payload { result.formUnion(ids) }
    }
    return result
  }

  var memberships: [Recipe.ID: Folder.ID] {
    let liveIDs = Set(folders.map(\.id))
    var byRecipe: [Recipe.ID: [OrganizationAction<FolderChange>]] = [:]
    for action in evidence.actions {
      if case let .assign(recipeID, _) = action.payload { byRecipe[recipeID, default: []].append(action) }
    }
    var result: [Recipe.ID: Folder.ID] = [:]
    for (recipeID, candidates) in byRecipe {
      if let winner = evidence.winner(in: candidates),
         case let .assign(_, folderID?) = winner.payload, !deleted.contains(folderID) {
        let canonical = aliases[folderID] ?? folderID
        if liveIDs.contains(canonical) { result[recipeID] = canonical }
      }
    }
    return result
  }

  private func closesCycle(child: Folder.ID, parent: Folder.ID, parents: [Folder.ID: Folder.ID]) -> Bool {
    var cursor: Folder.ID? = parent
    while let next = cursor {
      if next == child { return true }
      cursor = parents[next]
    }
    return false
  }

}
