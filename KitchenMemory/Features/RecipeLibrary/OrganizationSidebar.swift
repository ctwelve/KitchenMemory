// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct OrganizationSidebar: View {
  @Bindable var model: RecipeOrganizationModel
  let recipes: [StoredRecipe]
  @Environment(\.locale) private var locale

  var body: some View {
    Section {
      TextField(.organizationSearch, text: $model.filter.search)
        .accessibilityIdentifier("organization-search")
      Button(.organizationAll) {
        model.filter.location = .all; model.filter.tagIDs = []; model.filter.untagged = false
      }
      OrganizationManagementButton(model: model)
      Toggle(.organizationSelect, isOn: $model.selecting)
      if model.selecting {
        RecipeOrganizationMenus(model: model, recipeIDs: model.selectedRecipes)
          .disabled(model.selectedRecipes.isEmpty)
      }
    } header: { Text(.organizationTitle) }
    if let snapshot = model.snapshot {
      if model.foldersEnabled {
        Section {
          if model.showsUnfiled {
            Button(.organizationUnfiled) { model.filter.location = .unfiled }
              .dropDestination(for: String.self) { values, _ in model.dropRecipes(values, recipes: recipes, to: nil) }
          }
          ForEach(snapshot.folders.outline(expanded: model.expanded, locale: locale)) { row in
            HStack {
              if row.hasChildren {
                Button {
                  if !model.expanded.insert(row.folder.id).inserted { model.expanded.remove(row.folder.id) }
                } label: { Image(systemName: model.expanded.contains(row.folder.id) ? "chevron.down" : "chevron.right") }
                  .accessibilityLabel(model.expanded.contains(row.folder.id) ? Text(.organizationCollapse) : Text(.organizationExpand))
              }
              Button(row.folder.name, systemImage: "folder") { model.filter.location = .folder(row.folder.id) }
                .accessibilityIdentifier("folder-\(row.folder.id.rawValue.uuidString)")
            }
            .padding(.leading, CGFloat(min(row.depth, 8)) * 12)
            .draggable("km-folder:" + row.folder.id.rawValue.uuidString)
            .dropDestination(for: String.self) { values, _ in
              if values.count == 1, let id = model.identifier(values[0], prefix: "km-folder:") {
                model.perform { try $0.prepare(folder: .move(id: Folder.ID(rawValue: id), parentID: row.folder.id)) }
                return !model.failed
              }
              return model.dropRecipes(values, recipes: recipes, to: row.folder.id)
            }
          }
        } header: { Text(.organizationFolders) }
      }
      if model.tagsEnabled {
        Section {
          if model.showsUntagged, !snapshot.tags.tags.isEmpty {
            Button(.organizationUntagged) { model.filter.untagged = true; model.filter.tagIDs = [] }
          }
          ForEach(snapshot.tags.orderedTags(locale: locale)) { tag in
            Toggle(tag.displayName, isOn: Binding(get: { model.filter.tagIDs.contains(tag.id) }, set: { _ in model.toggleTag(tag.id) }))
              .accessibilityIdentifier("tag-\(tag.id.rawValue.uuidString)")
              .draggable("km-tag:" + tag.id.rawValue.uuidString)
              .dropDestination(for: String.self) { values, _ in
                if values.count == 1, snapshot.tags.ordering == .manual, let id = model.identifier(values[0], prefix: "km-tag:") {
                  model.perform { try $0.prepare(tag: .reorder(id: Tag.ID(rawValue: id), afterID: tag.id)) }
                  return !model.failed
                }
                guard let ids = model.recipeIDs(values, recipes: recipes) else { return false }
                model.classify(ids, tagID: tag.id, adding: true)
                return !model.failed
              }
          }
        } header: { Text(.organizationTags) }
      }
    }
  }

}
