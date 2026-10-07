// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Local library criteria applied to projected organization and current Recipe content.
///
/// Folder scope includes descendants and Tag criteria intersect. Disabling a local
/// feature removes its filter constraints without discarding shared evidence.
public struct RecipeOrganizationFilter: Equatable, Sendable {
  /// All Recipes, computed Unfiled Recipes, or one Folder and its descendants.
  public enum Location: Equatable, Sendable {
    /// Places no Folder constraint on the supplied Recipe list.
    case all
    /// Requires no live primary Folder; Unfiled has no stored identity.
    case unfiled
    /// Scopes to the live canonical Folder and all descendants, resolving retained Merge aliases.
    case folder(Folder.ID)
  }
  /// The selected Folder scope; descendants are included when Folder filtering is enabled.
  public var location: Location = .all
  /// Selected Tags whose canonical identities must all be assigned to each matching Recipe.
  public var tagIDs: Set<Tag.ID> = []
  /// When enabled, requires no live Tag assignments; combined with nonempty Tag criteria this can match nothing.
  public var untagged = false
  /// Local title-and-summary text query, trimmed before locale-aware matching.
  public var search = ""
  /// Creates an unconstrained all-Recipes filter with empty search text.
  public init() {}

  /// Applies enabled Folder and Tag criteria plus locale-aware title/summary search.
  ///
  /// Folder scope includes descendants; every selected Tag must match. Missing
  /// selected identities match nothing. Search ignores case and diacritics and
  /// preserves input order. Disabled organization features impose no constraint.
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

/// One visible Folder row with indentation and expansion affordance metadata.
public struct FolderOutlineRow: Equatable, Identifiable, Sendable {
  /// The represented Folder’s stable identity, independent of depth or expansion state.
  public var id: Folder.ID { folder.id }
  /// The live projected Folder represented by this row.
  public let folder: Folder
  /// Zero-based indentation from the implicit Kitchen root.
  public let depth: Int
  /// Whether live direct children exist, even when the row is currently collapsed.
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

/// One live Folder with its full presentation path for destination choice.
public struct FolderDestination: Equatable, Identifiable, Sendable {
  /// The destination Folder’s stable identity; its display path is not an identifier.
  public var id: Folder.ID { folder.id }
  /// The live Folder that can be selected as a destination.
  public let folder: Folder
  /// The full ancestor/name display path joined with “ / ”; it is presentation text, not identity.
  public let path: String
}
