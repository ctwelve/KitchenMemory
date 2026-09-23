// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

/// Visibility switches stay on this device; ordering and system views use the
/// Kitchen's existing synchronized organization commands.
struct OrganizationSettingsSections: View {
  @Bindable var model: RecipeOrganizationModel

  var body: some View {
    Section(.organizationTitle) {
      Toggle(.organizationShowFolders, isOn: $model.foldersEnabled)
      Toggle(.organizationShowTags, isOn: $model.tagsEnabled)
    }
    if let snapshot = model.snapshot {
      Section(.organizationFolders) {
        Picker(.organizationOrdering, selection: Binding(get: { snapshot.folders.ordering }, set: { mode in
          model.perform { try $0.prepare(folder: .ordering(mode)) }
        })) {
          Text(.organizationAlphabetical).tag(FolderOrdering.alphabetical)
          Text(.organizationManual).tag(FolderOrdering.manual)
        }
        Toggle(.organizationShowUnfiled, isOn: Binding(get: { model.showsUnfiled }, set: { visible in
          model.perform { try $0.prepare(folder: .systemViewVisible(visible)) }
        }))
      }
      Section(.organizationTags) {
        Picker(.organizationOrdering, selection: Binding(get: { snapshot.tags.ordering }, set: { mode in
          model.perform { try $0.prepare(tag: .ordering(mode)) }
        })) {
          Text(.organizationAlphabetical).tag(TagOrdering.alphabetical)
          Text(.organizationManual).tag(TagOrdering.manual)
        }
        Toggle(.organizationShowUntagged, isOn: Binding(get: { model.showsUntagged }, set: { visible in
          model.perform { try $0.prepare(tag: .systemViewVisible(visible)) }
        }))
      }
    }
  }
}
