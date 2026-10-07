// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

/// One visible cooking screen owns one sleep-prevention lease, independent of lifecycle evidence.
@MainActor
final class ScreenAwakeController {
  private let acquire: @MainActor () -> (() -> Void)
  private var release: (() -> Void)?

  init(acquire: @escaping @MainActor () -> (() -> Void) = NativeCookingScreenAwake.acquire) {
    self.acquire = acquire
  }

  func update(isVisible: Bool, isForeground: Bool, lifecycle: SessionLifecycle, keepsAwake: Bool) {
    let eligible = isVisible && isForeground && lifecycle == .active && keepsAwake
    if eligible, release == nil { release = acquire() } else if !eligible { end() }
  }

  func end() {
    release?()
    release = nil
  }

  isolated deinit { release?() }
}
