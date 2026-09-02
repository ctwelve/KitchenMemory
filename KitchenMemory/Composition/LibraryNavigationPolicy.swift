// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

enum LibraryNavigationPolicy {
  static func destinationSelectionVisibility(
    current: NavigationSplitViewVisibility,
    preservesSidebar: Bool
  ) -> NavigationSplitViewVisibility {
    preservesSidebar ? current : .detailOnly
  }
}
