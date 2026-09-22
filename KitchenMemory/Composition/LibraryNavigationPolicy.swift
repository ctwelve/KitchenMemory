// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

enum LibraryNavigationPolicy {
  static var initialVisibility: NavigationSplitViewVisibility {
#if os(macOS)
    .all
#else
    .automatic
#endif
  }

}
