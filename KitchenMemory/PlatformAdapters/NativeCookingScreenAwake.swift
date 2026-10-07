// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
#if os(iOS)
import UIKit
#endif

@MainActor
enum NativeCookingScreenAwake {
#if os(iOS)
  private static var owners = 0
  private static var previousIdleTimerDisabled = false
#endif

  static func acquire() -> (() -> Void) {
#if os(macOS)
    let activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled],
      reason: "Visible Active Cooking Session")
    return { ProcessInfo.processInfo.endActivity(activity) }
#else
    // UIApplication has one process-wide switch; another window's lease must survive this one's exit.
    if owners == 0 { previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled }
    owners += 1
    UIApplication.shared.isIdleTimerDisabled = true
    return {
      owners -= 1
      if owners == 0 { UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled }
    }
#endif
  }
}
