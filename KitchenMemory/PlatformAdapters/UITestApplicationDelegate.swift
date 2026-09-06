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
    // Cloud can finish launching a regular application with a window while
    // leaving it in the background. Request the foreground handoff here:
    // XCUIApplication.launch() must complete before test-side recovery runs.
    NSApplication.shared.activate()
  }
}
#endif
