// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

struct LibraryToolbar: ToolbarContent {
  let showsKitchenActions: Bool
  let actionsAreAvailable: Bool
  let showsSidebarToggle: Bool
  let sidebarToggleTitle: LocalizedStringResource
  let sidebarTogglePlacement: ToolbarItemPlacement
  let createRecipe: () -> Void
  let importRecipe: () -> Void
  let toggleSidebar: () -> Void
  let showSettings: () -> Void

  @ToolbarContentBuilder
  var body: some ToolbarContent {
    if showsKitchenActions {
      ToolbarItem(placement: .primaryAction) {
        Button(action: createRecipe) {
          ToolbarIconLabel(.libraryActionNewRecipe, systemImage: "plus")
        }
        .disabled(!actionsAreAvailable)
        .accessibilityIdentifier("new-recipe")
      }
      ToolbarItem(placement: .primaryAction) {
        Button(action: importRecipe) {
          ToolbarIconLabel(.libraryActionImportRecipe, systemImage: "square.and.arrow.down")
        }
        .disabled(!actionsAreAvailable)
        .accessibilityIdentifier("import-recipe")
      }
    }
    if showsSidebarToggle {
      ToolbarItem(placement: sidebarTogglePlacement) {
        Button(action: toggleSidebar) {
          ToolbarIconLabel(sidebarToggleTitle, systemImage: "sidebar.left")
        }
        .accessibilityIdentifier("toggle-sidebar")
        .help(Text(sidebarToggleTitle))
      }
    }
#if !os(macOS)
    if showsKitchenActions {
      ToolbarItem(placement: .primaryAction) {
        Button(action: showSettings) {
          ToolbarIconLabel(.settingsTitle, systemImage: "gearshape")
        }
        .accessibilityIdentifier("open-settings")
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
