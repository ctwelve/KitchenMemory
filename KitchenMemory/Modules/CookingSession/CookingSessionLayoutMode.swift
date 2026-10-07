// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

nonisolated enum CookingSessionLayoutMode: Equatable {
  case compact
  case regular
  case wide

  static func resolve(
    width: Double,
    usesAccessibilityTextSize: Bool = false
  ) -> Self {
    guard !usesAccessibilityTextSize else { return .compact }
    if width >= 900 { return .wide }
    if width >= 540 { return .regular }
    return .compact
  }
}
