// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeOrganizationMenus: View {
  @Bindable var model: RecipeOrganizationModel
  let recipeIDs: Set<Recipe.ID>
  @Environment(\.locale) private var locale

  var body: some View {
    if let snapshot = model.snapshot {
      if model.foldersEnabled {
        Menu(.organizationMove) {
          Button(.organizationUnfiled) { model.move(recipeIDs, to: nil) }
          ForEach(snapshot.folders.folders.sorted { $0.name < $1.name }) { folder in
            Button(folder.name) { model.move(recipeIDs, to: folder.id) }
          }
        }
      }
      if model.tagsEnabled {
        Menu(.organizationAddTag) {
          ForEach(snapshot.tags.orderedTags(locale: locale)) { tag in
            Button(tag.displayName) { model.classify(recipeIDs, tagID: tag.id, adding: true) }
          }
        }
        Menu(.organizationRemoveTag) {
          ForEach(snapshot.tags.orderedTags(locale: locale)) { tag in
            Button(tag.displayName) { model.classify(recipeIDs, tagID: tag.id, adding: false) }
          }
        }
      }
    }
  }
}

struct RecipeOrganizationEditor: View {
  @Bindable var model: RecipeOrganizationModel
  @Bindable var draft: RecipeEditingDraft
  @Environment(\.locale) private var locale

  var body: some View {
    Section {
      if let original = draft.original {
        RecipeOrganizationMenus(model: model, recipeIDs: [original.id])
        Text(.organizationImmediate).font(.caption).foregroundStyle(.secondary)
      } else if let snapshot = model.snapshot {
        if model.foldersEnabled {
          Picker(.organizationFolders, selection: $draft.organization.folderID) {
            Text(.organizationUnfiled).tag(Folder.ID?.none)
            ForEach(snapshot.folders.folders.sorted { $0.name < $1.name }) { folder in
              Text(folder.name).tag(Optional(folder.id))
            }
          }
        }
        if model.tagsEnabled {
          ForEach(snapshot.tags.orderedTags(locale: locale)) { tag in
            Toggle(tag.displayName, isOn: Binding(get: { draft.organization.tagIDs.contains(tag.id) }, set: { selected in
              if selected { draft.organization.tagIDs.insert(tag.id) } else { draft.organization.tagIDs.remove(tag.id) }
            }))
          }
        }
        Text(.organizationPending).font(.caption).foregroundStyle(.secondary)
      }
    } header: { Text(.organizationTitle) }
  }
}
