// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum CookingSessionClipboard {
  @MainActor
  static func copy(_ text: String) -> Bool {
#if os(macOS)
    NSPasteboard.general.clearContents()
    return NSPasteboard.general.setString(text, forType: .string)
#else
    UIPasteboard.general.string = text
    return UIPasteboard.general.string == text
#endif
  }
}
