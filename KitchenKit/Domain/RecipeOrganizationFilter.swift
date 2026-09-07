// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public struct RecipeOrganizationFilter: Equatable, Sendable {
  public enum Location: Equatable, Sendable { case all, unfiled, folder(Folder.ID) }
  public var location: Location = .all
  public var tagIDs: Set<Tag.ID> = []
  public var untagged = false
  public var search = ""
  public init() {}

  /// Hidden local features do not constrain search; their evidence stays projected.
  public func apply(to recipes: [StoredRecipe], organization: RecipeOrganization,
                    foldersEnabled: Bool, tagsEnabled: Bool, locale: Locale) -> [StoredRecipe] {
    let scope: Set<Folder.ID>?
    if foldersEnabled, case let .folder(id) = location {
      scope = organization.folders.canonicalFolderID(for: id).map { organization.folders.subtree(of: $0) } ?? []
    } else { scope = nil }
    let selectedTags = Set(tagIDs.compactMap { organization.tags.canonicalTagID(for: $0) })
    let missingTag = tagIDs.contains { organization.tags.canonicalTagID(for: $0) == nil }
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return recipes.filter { recipe in
      let folder = organization.folders.primaryFolder(for: recipe.id)
      if let scope, !scope.contains(where: { $0 == folder }) { return false }
      if foldersEnabled, location == .unfiled, folder != nil { return false }
      if tagsEnabled {
        let assigned = organization.tags.tagIDs(for: recipe.id)
        if missingTag || !selectedTags.isSubset(of: assigned) || (untagged && !assigned.isEmpty) { return false }
      }
      let text = recipe.revision.title + "\n" + (recipe.revision.summary ?? "")
      return query.isEmpty || text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive],
                                        locale: locale) != nil
    }
  }
}

public struct FolderOutlineRow: Equatable, Identifiable, Sendable {
  public var id: Folder.ID { folder.id }
  public let folder: Folder
  public let depth: Int
  public let hasChildren: Bool
}

extension FolderLibrary {
  /// Iterative outline construction avoids call-stack limits for deep imported hierarchies.
  public func outline(expanded: Set<Folder.ID>, locale: Locale) -> [FolderOutlineRow] {
    let ordered: [Folder]
    if ordering == .manual {
      let byID = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
      ordered = manualIDs.compactMap { byID[$0] }
    } else {
      ordered = folders.sorted { left, right in
        let comparison = left.name.compare(right.name, options: .caseInsensitive, locale: locale)
        return comparison == .orderedSame ? left.id.rawValue.uuidString < right.id.rawValue.uuidString
          : comparison == .orderedAscending
      }
    }
    let groups = Dictionary(grouping: ordered, by: \.parentID)
    var pending = (groups[nil] ?? []).reversed().map { ($0, 0) }
    var rows: [FolderOutlineRow] = []
    while let (folder, depth) = pending.popLast() {
      let children = groups[folder.id] ?? []
      rows.append(FolderOutlineRow(folder: folder, depth: depth, hasChildren: !children.isEmpty))
      if expanded.contains(folder.id) { pending.append(contentsOf: children.reversed().map { ($0, depth + 1) }) }
    }
    return rows
  }
}

extension FolderLibrary {
  /// Complete hierarchical destinations, including collapsed descendants, in presentation order.
  public func destinations(locale: Locale) -> [FolderDestination] {
    let rows = outline(expanded: Set(folders.map(\.id)), locale: locale)
    var ancestry: [String] = []
    return rows.map { row in
      ancestry = Array(ancestry.prefix(row.depth))
      ancestry.append(row.folder.name)
      return FolderDestination(folder: row.folder, path: ancestry.joined(separator: " / "))
    }
  }
}

public struct FolderDestination: Equatable, Identifiable, Sendable {
  public var id: Folder.ID { folder.id }
  public let folder: Folder
  public let path: String
}
