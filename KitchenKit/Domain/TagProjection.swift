// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

struct TagProjection {
  let evidence: OrganizationEvidence<TagChange>
  var observedBy: UUID?

  private var policyActions: [OrganizationAction<TagChange>] {
    guard let observedBy else { return evidence.actions }
    return evidence.actions.filter { evidence.graph.isAncestor($0.id, of: observedBy) }
  }

  var deleted: Set<Tag.ID> {
    Set(policyActions.compactMap { if case let .delete(id) = $0.payload { return id }; return nil })
  }

  var aliasPolicy: OrganizationAliases<Tag.ID, TagChange> {
    OrganizationAliases(evidence: evidence, deleted: deleted, creation: {
      if case let .create(id, _) = $0 { return id }
      return nil
    }, merge: {
      if case let .merge(ids, survivor, _) = $0 { return (ids, survivor) }
      return nil
    }, actions: policyActions)
  }

  var aliases: [Tag.ID: Tag.ID] { aliasPolicy.resolved }

  var tags: [Tag] {
    let disposed = deleted
    let aliases = aliases
    var names: [Tag.ID: [OrganizationAction<TagChange>]] = [:]
    for action in evidence.actions {
      switch action.payload {
      case .create, .rename, .merge:
        if let id = action.payload.tagID, !disposed.contains(id), aliases[id] == nil {
          names[id, default: []].append(action)
        }
      default: break
      }
    }
    return names.compactMap { id, choices -> Tag? in
      guard choices.contains(where: { if case .create = $0.payload { return true }; return false }) else { return nil }
      switch evidence.winner(in: choices)?.payload {
      case let .create(_, name), let .rename(_, name), let .merge(_, _, name): return Tag(id: id, name: name)
      default: return nil
      }
    }.sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
  }

  var removed: Set<UUID> {
    Set(evidence.actions.flatMap { action -> [UUID] in
      if case let .remove(_, _, dots) = action.payload { return dots }
      return []
    })
  }

  func assignments(recipeID: Recipe.ID, tagID: Tag.ID) -> Set<UUID> {
    let aliases = aliases
    let disposed = deleted
    let removed = removed
    return Set(evidence.actions.compactMap { action in
      guard case let .assign(recipe, tag) = action.payload, recipe == recipeID,
            !disposed.contains(tag), !removed.contains(action.id), (aliases[tag] ?? tag) == tagID else { return nil }
      return action.id
    })
  }

  var memberships: [Recipe.ID: Set<Tag.ID>] {
    let live = Set(tags.map(\.id))
    let aliases = aliases
    let disposed = deleted
    let removed = removed
    var result: [Recipe.ID: Set<Tag.ID>] = [:]
    for action in evidence.actions {
      guard case let .assign(recipe, tag) = action.payload,
            !disposed.contains(tag), !removed.contains(action.id) else { continue }
      let canonical = aliases[tag] ?? tag
      if live.contains(canonical) { result[recipe, default: []].insert(canonical) }
    }
    return result
  }
}

public struct TagCollision: Equatable, Sendable {
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
