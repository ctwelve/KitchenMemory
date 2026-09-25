// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

enum LibraryNavigationPolicy {
  static func initialColumn(startup: RecipeLibraryModel.StartupState,
                            focus: RecipeLibraryNavigation.Focus) -> NavigationSplitViewColumn {
    startup == .ready ? column(for: focus) : .detail
  }

  static func column(for focus: RecipeLibraryNavigation.Focus) -> NavigationSplitViewColumn {
    focus == .content ? .content : .detail
  }

  static var initialVisibility: NavigationSplitViewVisibility {
#if os(macOS)
    .all
#else
    .automatic
#endif
  }

}
