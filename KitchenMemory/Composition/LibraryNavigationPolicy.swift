// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

enum LibraryNavigationPolicy {
  static func initialColumn(startup: RecipeLibraryModel.StartupState,
                            destination: RecipeLibraryNavigation.Destination) -> NavigationSplitViewColumn {
    startup == .ready && destination == .recipe ? .content : .detail
  }

  static var initialVisibility: NavigationSplitViewVisibility {
#if os(macOS)
    .all
#else
    .automatic
#endif
  }

}
