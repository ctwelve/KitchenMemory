// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

struct LibraryToolbar: ToolbarContent {
  let showsKitchenActions: Bool
  let actions: LibraryCommandActions?
  let showsSidebarToggle: Bool
  let sidebarToggleTitle: LocalizedStringResource
  let toggleSidebar: () -> Void
  let showSettings: () -> Void

  @ToolbarContentBuilder
  var body: some ToolbarContent {
    if showsKitchenActions {
      ToolbarItem(placement: .primaryAction) {
        Button { actions?.perform(.newRecipe) } label: {
          ToolbarIconLabel(.libraryActionNewRecipe, systemImage: "plus")
        }
        .disabled(actions?.canPerform(.newRecipe) != true)
        .accessibilityIdentifier("new-recipe")
        .help(Text(.libraryActionNewRecipe))
      }
      ToolbarItem(placement: .primaryAction) {
        Button { actions?.perform(.importRecipe) } label: {
          ToolbarIconLabel(.libraryActionImportRecipe, systemImage: "square.and.arrow.down")
        }
        .disabled(actions?.canPerform(.importRecipe) != true)
        .accessibilityIdentifier("import-recipe")
        .help(Text(.libraryActionImportRecipe))
      }
    }
#if os(iOS)
    if showsSidebarToggle {
      ToolbarItem(placement: .navigation) {
        Button(action: toggleSidebar) {
          ToolbarIconLabel(sidebarToggleTitle, systemImage: "sidebar.left")
        }
        .accessibilityIdentifier("toggle-sidebar")
        .help(Text(sidebarToggleTitle))
      }
    }
#endif
#if !os(macOS)
    if showsKitchenActions {
      ToolbarItem(placement: .primaryAction) {
        Button(action: showSettings) {
          ToolbarIconLabel(.settingsTitle, systemImage: "gearshape")
        }
        .accessibilityIdentifier("open-settings")
        .help(Text(.settingsTitle))
      }
    }
#endif
  }
}

private struct ToolbarIconLabel: View {
  let title: LocalizedStringResource
  let systemImage: String

  init(_ title: LocalizedStringResource, systemImage: String) {
    self.title = title
    self.systemImage = systemImage
  }

  var body: some View {
    Label(title, systemImage: systemImage)
      .labelStyle(.iconOnly)
      .frame(width: 20, height: 20, alignment: .bottom)
      .accessibilityLabel(Text(title))
  }
}
