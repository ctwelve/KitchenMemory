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
  var failed = false
  var filter = RecipeOrganizationFilter()
  var selectedRecipes: Set<Recipe.ID> = []
  var selecting = false
  var foldersEnabled: Bool { didSet { defaults.set(foldersEnabled, forKey: "organization.folders.enabled") } }
  var tagsEnabled: Bool { didSet { defaults.set(tagsEnabled, forKey: "organization.tags.enabled") } }
  var expanded: Set<Folder.ID> { didSet { persistExpanded() } }
  private(set) var showsUnfiled = true
  private(set) var showsUntagged = true

  init(repository: any RecipeOrganizationRepository, kitchenID: Kitchen.ID, defaults: UserDefaults = .standard) {
    self.repository = repository
    self.kitchenID = kitchenID
    self.defaults = defaults
    prefix = "organization." + kitchenID.rawValue.uuidString
    foldersEnabled = defaults.object(forKey: "organization.folders.enabled") as? Bool ?? true
    tagsEnabled = defaults.object(forKey: "organization.tags.enabled") as? Bool ?? true
    expanded = Set((defaults.stringArray(forKey: prefix + ".expanded") ?? []).compactMap(UUID.init(uuidString:))
      .map(Folder.ID.init(rawValue:)))
    if let data = defaults.data(forKey: prefix + ".pending") {
      do { pending = try JSONDecoder().decode(RecipeOrganizationCommand.self, from: data) }
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
      refresh()
    } catch { failed = true }
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
