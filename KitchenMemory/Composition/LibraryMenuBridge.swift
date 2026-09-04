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
#else
    content
#endif
  }
}

#if os(macOS)
private struct LibraryCommandActionsKey: FocusedValueKey {
  typealias Value = LibraryCommandActions
}

extension FocusedValues {
  var libraryCommandActions: LibraryCommandActions? {
    get { self[LibraryCommandActionsKey.self] }
    set { self[LibraryCommandActionsKey.self] = newValue }
  }
}
#endif
