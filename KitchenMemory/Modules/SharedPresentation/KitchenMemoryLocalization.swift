// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

extension LocalizedStringResource {
  /// Resolves a generated catalog symbol using an explicit presentation locale.
  ///
  /// SwiftUI applies its environment locale automatically. Presentation code
  /// that must return `String` instead carries the same locale through the
  /// resource before resolving it.
  nonisolated func localized(for locale: Locale) -> String {
    var resource = self
    resource.locale = locale
    return String(localized: resource)
  }
}
