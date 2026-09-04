// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

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
