// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum RecipeLibraryIssue: Equatable {
  case read
  case save
  case reset
  case samples

  func message(locale: Locale = .current) -> String {
    switch self {
    case .read:
      String(localized: "Kitchen Memory could not read this recipe library.", locale: locale)
    case .save:
      String(localized: "Kitchen Memory could not save this recipe.", locale: locale)
    case .reset:
      String(
        localized: "Kitchen Memory could not reset this Kitchen. No reset was completed.",
        locale: locale
      )
    case .samples:
      String(
        localized: "Kitchen Memory could not add the sample recipes. Your existing recipes were not changed.",
        locale: locale
      )
    }
  }
}
