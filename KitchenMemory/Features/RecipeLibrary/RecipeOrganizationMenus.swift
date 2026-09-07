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
          ForEach(snapshot.folders.destinations(locale: locale)) { destination in
            Button(destination.path) { model.move(recipeIDs, to: destination.id) }
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
        RecipeOrganizationSummary(model: model, recipeID: original.id)
        RecipeOrganizationMenus(model: model, recipeIDs: [original.id])
        Text(.organizationImmediate).font(.caption).foregroundStyle(.secondary)
      } else if let snapshot = model.snapshot {
        if model.foldersEnabled {
          Picker(.organizationFolders, selection: $draft.organization.folderID) {
            Text(.organizationUnfiled).tag(Folder.ID?.none)
            ForEach(snapshot.folders.destinations(locale: locale)) { destination in
              Text(destination.path).tag(Optional(destination.id))
            }
          }
        }
        if model.tagsEnabled {
          ForEach(snapshot.tags.orderedTags(locale: locale)) { tag in
            Toggle(
              tag.displayName,
              isOn: Binding(
                get: { draft.organization.tagIDs.contains(tag.id) },
                set: { selected in
              if selected { draft.organization.tagIDs.insert(tag.id) } else { draft.organization.tagIDs.remove(tag.id) }
            }))
          }
        }
        Text(.organizationPending).font(.caption).foregroundStyle(.secondary)
      }
    } header: { Text(.organizationTitle) }
  }
}

struct RecipeOrganizationSummary: View {
  let model: RecipeOrganizationModel
  let recipeID: Recipe.ID
  @Environment(\.locale) private var locale
  var body: some View {
    if let snapshot = model.snapshot {
      VStack(alignment: .leading, spacing: 4) {
        if model.foldersEnabled {
          if let folderID = snapshot.folders.primaryFolder(for: recipeID),
             let destination = snapshot.folders.destinations(locale: locale).first(where: { $0.id == folderID }) {
            Label(destination.path, systemImage: "folder")
          } else { Label(.organizationUnfiled, systemImage: "folder") }
        }
        if model.tagsEnabled {
          let ids = snapshot.tags.tagIDs(for: recipeID)
          ForEach(snapshot.tags.orderedTags(locale: locale).filter { ids.contains($0.id) }) { tag in
            Label(tag.displayName, systemImage: "tag")
          }
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }
}
