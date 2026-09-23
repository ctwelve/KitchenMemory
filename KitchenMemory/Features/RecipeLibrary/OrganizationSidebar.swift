// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct OrganizationSidebar: View {
  @Bindable var model: RecipeOrganizationModel
  let recipes: [StoredRecipe]
  let browse: (@escaping () -> Void) -> Void
  @Environment(\.locale) private var locale
  let presentation: OrganizationActionPresentation

  var body: some View {
    Group {
      if let snapshot = model.snapshot {
        if model.foldersEnabled {
          Section {
            if model.showsUnfiled {
              Button(.organizationUnfiled, systemImage: "tray") {
                browse { model.filter.location = .unfiled }
              }
              .accessibilityAddTraits(model.filter.location == .unfiled ? .isSelected : [])
              .dropDestination(for: String.self) { values, _ -> Bool in
                model.dropRecipes(values, recipes: recipes, to: nil)
              }
            }
            ForEach(snapshot.folders.children(of: nil, locale: locale)) { folder in
              OrganizationFolderBranch(model: model, folder: folder, recipes: recipes,
                                       presentation: presentation, browse: browse)
            }
          } header: {
            HStack {
              Text(.organizationFolders)
              Spacer()
              Button(.organizationNewFolder, systemImage: "plus") { presentation.edits = .init(folder: nil) }
                .labelStyle(.iconOnly)
              OrganizationManagementButton(model: model).labelStyle(.iconOnly)
            }
          }
        }
        if model.tagsEnabled {
          Section {
            DisclosureGroup(isExpanded: $model.tagsExpanded) {
              if model.showsUntagged, !snapshot.tags.tags.isEmpty {
                Button(.organizationUntagged, systemImage: "tag.slash") {
                  browse { model.filter.untagged = true; model.filter.tagIDs = [] }
                }
                .accessibilityAddTraits(model.filter.untagged ? .isSelected : [])
              }
              ForEach(snapshot.tags.orderedTags(locale: locale)) { tag in
                Toggle(isOn: Binding(get: { model.filter.tagIDs.contains(tag.id) }, set: { _ in
                  browse { model.toggleTag(tag.id) }
                })) {
                  Label(tag.displayName, systemImage: "tag")
                }
                .accessibilityIdentifier("tag-\(tag.id.rawValue.uuidString)")
                .contextMenu { OrganizationTagActions(model: model, tag: tag, presentation: presentation) }
                .draggable("km-tag:" + tag.id.rawValue.uuidString)
                .dropDestination(for: String.self) { values, _ -> Bool in
                  model.dropTag(values, recipes: recipes, onto: tag.id)
                }
              }
            } label: { Label(.organizationTags, systemImage: "tag") }
          } header: {
            HStack {
              Text(.organizationTags)
              Spacer()
              Button(.organizationNewTag, systemImage: "plus") { presentation.edits = .init(tag: nil) }
                .labelStyle(.iconOnly)
              OrganizationManagementButton(model: model).labelStyle(.iconOnly)
            }
          }
        }
      }
    }
  }
}

private struct OrganizationFolderBranch: View {
  @Bindable var model: RecipeOrganizationModel
  let folder: Folder
  let recipes: [StoredRecipe]
  let presentation: OrganizationActionPresentation
  let browse: (@escaping () -> Void) -> Void
  @Environment(\.locale) private var locale

  var body: some View {
    Group {
      if let children = model.snapshot?.folders.children(of: folder.id, locale: locale), !children.isEmpty {
        DisclosureGroup(isExpanded: Binding(get: { model.expanded.contains(folder.id) }, set: { expanded in
          if expanded { model.expanded.insert(folder.id) } else { model.expanded.remove(folder.id) }
        })) {
          ForEach(children) { child in
            OrganizationFolderBranch(model: model, folder: child, recipes: recipes,
                                     presentation: presentation, browse: browse)
          }
        } label: { folderButton }
      } else {
        folderButton
      }
    }
    .contextMenu { OrganizationFolderActions(model: model, folder: folder, presentation: presentation) }
    .draggable("km-folder:" + folder.id.rawValue.uuidString)
    .dropDestination(for: String.self) { values, _ -> Bool in
      model.dropFolder(values, recipes: recipes, onto: folder.id)
    }
  }

  private var folderButton: some View {
    Button(folder.name, systemImage: "folder") {
      browse { model.filter.location = .folder(folder.id) }
    }
    .accessibilityIdentifier("folder-\(folder.id.rawValue.uuidString)")
    .accessibilityAddTraits(model.filter.location == .folder(folder.id) ? .isSelected : [])
  }
}
