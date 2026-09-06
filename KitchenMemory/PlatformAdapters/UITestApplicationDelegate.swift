// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if os(macOS) && TESTING
import AppKit

/// Requests the test application's foreground handoff after native launch completes.
@MainActor
final class UITestApplicationDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
    NSApplication.shared.activate()
  }
}
#endif
