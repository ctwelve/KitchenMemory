// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import Observation

@MainActor
@Observable
final class RecipeOrganizationModel {
  private let repository: any RecipeOrganizationRepository
  private let kitchenID: Kitchen.ID
  private let defaults: UserDefaults
  private let prefix: String
  private(set) var snapshot: RecipeOrganization?
  private(set) var pending: RecipeOrganizationCommand?
  private(set) var storageInvalid = false
  private(set) var changeRejected = false
  var failed = false
  var filter = RecipeOrganizationFilter()
  var selectedRecipes: Set<Recipe.ID> = []
  var selecting = false
  var foldersEnabled: Bool { didSet { defaults.set(foldersEnabled, forKey: "organization.folders.enabled") } }
  var tagsEnabled: Bool { didSet { defaults.set(tagsEnabled, forKey: "organization.tags.enabled") } }
  var expanded: Set<Folder.ID> { didSet { persistExpanded() } }
  private(set) var showsUnfiled = true
  private(set) var showsUntagged = true

  init(repository: any RecipeOrganizationRepository, kitchenID: Kitchen.ID, scope: String, defaults: UserDefaults = .standard) {
    self.repository = repository
    self.kitchenID = kitchenID
    self.defaults = defaults
    prefix = "organization." + scope + "." + kitchenID.rawValue.uuidString
    foldersEnabled = defaults.object(forKey: "organization.folders.enabled") as? Bool ?? true
    tagsEnabled = defaults.object(forKey: "organization.tags.enabled") as? Bool ?? true
    expanded = Set((defaults.stringArray(forKey: prefix + ".expanded") ?? []).compactMap(UUID.init(uuidString:))
      .map(Folder.ID.init(rawValue:)))
    if let data = defaults.data(forKey: prefix + ".pending") {
      do {
        let command = try JSONDecoder().decode(RecipeOrganizationCommand.self, from: data)
        guard command.kitchenID == kitchenID else { throw FolderError.wrongKitchen }
        pending = command
      }
      catch { storageInvalid = true; failed = true }
    }
    refresh()
  }

  var collisionCount: Int { (snapshot?.folders.collisions.count ?? 0) + (snapshot?.tags.collisions.count ?? 0) }
  var requiresRecovery: Bool { snapshot == nil || storageInvalid || pending != nil || collisionCount > 0 }

  func refresh() {
    do {
      let value = try repository.load(in: kitchenID)
      showsUnfiled = try value.folders.systemViewVisible
      showsUntagged = try value.tags.systemViewVisible
      snapshot = value
      filter.tagIDs = Set(filter.tagIDs.compactMap { value.tags.canonicalTagID(for: $0) })
      if case let .folder(id) = filter.location {
        filter.location = value.folders.canonicalFolderID(for: id).map(RecipeOrganizationFilter.Location.folder) ?? .all
      }
      if !showsUnfiled, filter.location == .unfiled { filter.location = .all }
      if !showsUntagged || value.tags.tags.isEmpty { filter.untagged = false }
    } catch { snapshot = nil; failed = true }
  }

  func recipes(_ recipes: [StoredRecipe], locale: Locale) -> [StoredRecipe] {
    guard let snapshot else { return recipes }
    return filter.apply(to: recipes, organization: snapshot,
                        foldersEnabled: foldersEnabled, tagsEnabled: tagsEnabled, locale: locale)
  }

  func perform(_ prepare: (RecipeOrganization) throws -> RecipeOrganizationCommand) {
    guard !storageInvalid, pending == nil, let snapshot else { failed = true; return }
    do {
      let command = try prepare(snapshot)
      let data = try JSONEncoder().encode(command)
      defaults.set(data, forKey: prefix + ".pending")
      pending = command
      retry()
    } catch { failed = true }
  }

  func retry() {
    guard !storageInvalid else { failed = true; return }
    guard let pending else { refresh(); return }
    do {
      try repository.accept(pending, firstSave: nil)
      defaults.removeObject(forKey: prefix + ".pending")
      self.pending = nil
      failed = false
      changeRejected = false
      refresh()
    } catch {
      changeRejected = error is FolderError || error is TagError
      failed = true
    }
  }

  func reorderFolder(from offsets: IndexSet, to destination: Int, locale: Locale) {
    guard let snapshot, snapshot.folders.ordering == .manual,
          offsets.count == 1, let source = offsets.first else { return }
    let rows = snapshot.folders.outline(expanded: expanded, locale: locale)
    guard rows.indices.contains(source), (0...rows.count).contains(destination) else { return }
    let folder = rows[source].folder
    var reordered = rows.map(\.folder)
    reordered.remove(at: source)
    let insertion = destination > source ? destination - 1 : destination
    reordered.insert(folder, at: insertion)
    let anchor = reordered.prefix(insertion).last { $0.parentID == folder.parentID }
    perform { try $0.prepare(folder: .reorder(id: folder.id, afterID: anchor?.id)) }
  }

  func discardRejectedChange() {
    guard changeRejected else { return }
    defaults.removeObject(forKey: prefix + ".pending")
    pending = nil
    changeRejected = false
    failed = false
    refresh()
  }

  func dropFolder(_ values: [String], recipes: [StoredRecipe], onto folderID: Folder.ID) -> Bool {
    if values.count == 1, let id = identifier(values[0], prefix: "km-folder:") {
      perform { try $0.prepare(folder: .move(id: Folder.ID(rawValue: id), parentID: folderID)) }
      return !failed
    }
    return dropRecipes(values, recipes: recipes, to: folderID)
  }

  func dropTag(_ values: [String], recipes: [StoredRecipe], onto tagID: Tag.ID) -> Bool {
    if values.count == 1, snapshot?.tags.ordering == .manual, let id = identifier(values[0], prefix: "km-tag:") {
      perform { try $0.prepare(tag: .reorder(id: Tag.ID(rawValue: id), afterID: tagID)) }
      return !failed
    }
    guard let ids = recipeIDs(values, recipes: recipes) else { return false }
    classify(ids, tagID: tagID, adding: true)
    return !failed
  }

  func clearForReset() {
    defaults.removeObject(forKey: prefix + ".pending")
    pending = nil
    storageInvalid = false
    changeRejected = false
    failed = false
    expanded = []
    filter = RecipeOrganizationFilter()
    selectedRecipes = []
  }

  func move(_ ids: Set<Recipe.ID>, to folderID: Folder.ID?) {
    perform { try $0.move(ids, to: folderID) }
  }

  func classify(_ ids: Set<Recipe.ID>, tagID: Tag.ID, adding: Bool) {
    perform { try $0.classify(ids, tagID: tagID, adding: adding) }
  }

  func toggleTag(_ id: Tag.ID) {
    filter.untagged = false
    if !filter.tagIDs.insert(id).inserted { filter.tagIDs.remove(id) }
  }

  private func persistExpanded() {
    defaults.set(expanded.map { $0.rawValue.uuidString }.sorted(), forKey: prefix + ".expanded")
  }
  func identifier(_ value: String, prefix: String) -> UUID? {
    guard value.hasPrefix(prefix) else { return nil }
    return UUID(uuidString: String(value.dropFirst(prefix.count)))
  }

  func recipeIDs(_ values: [String], recipes: [StoredRecipe]) -> Set<Recipe.ID>? {
    let ids = Set(values.compactMap { identifier($0, prefix: "km-recipe:").map(Recipe.ID.init(rawValue:)) })
    guard !ids.isEmpty, ids.count == values.count, ids.isSubset(of: Set(recipes.map(\.id))) else { return nil }
    return ids
  }

  func dropRecipes(_ values: [String], recipes: [StoredRecipe], to folder: Folder.ID?) -> Bool {
    guard let ids = recipeIDs(values, recipes: recipes) else { return false }
    move(ids, to: folder)
    return !failed
  }
}
