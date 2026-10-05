// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

/// Publishes the invoking library window's actions to SwiftUI's focused commands.
///
/// Menus are app-level UI, but their window effects must use the focused scene's
/// closures. While the library presents an import sheet or reset confirmation,
/// it publishes no actions but keeps its presence marker. Command resolution
/// can then distinguish blocked input from no library window and honor the
/// window's modal state instead of using app-level fallback.
struct LibraryMenuBridge: ViewModifier {
  let actions: LibraryCommandActions?
  let isAvailable: Bool

  func body(content: Content) -> some View {
#if os(macOS)
    content.focusedSceneValue(\.libraryCommandActions, isAvailable ? actions : nil)
      .focusedSceneValue(\.libraryWindowPresent, true)
#else
    content
#endif
  }
}

#if os(macOS)
private struct LibraryCommandActionsKey: FocusedValueKey {
  typealias Value = LibraryCommandActions
}

private struct LibraryWindowPresentKey: FocusedValueKey {
  typealias Value = Bool
}

extension FocusedValues {
  var libraryWindowPresent: Bool? {
    get { self[LibraryWindowPresentKey.self] }
    set { self[LibraryWindowPresentKey.self] = newValue }
  }

  var libraryCommandActions: LibraryCommandActions? {
    get { self[LibraryCommandActionsKey.self] }
    set { self[LibraryCommandActionsKey.self] = newValue }
  }
}
#endif
