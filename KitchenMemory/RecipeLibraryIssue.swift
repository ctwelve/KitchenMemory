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
      LocalizedStringResource.libraryFailureRead.localized(for: locale)
    case .save:
      LocalizedStringResource.libraryFailureSave.localized(for: locale)
    case .reset:
      LocalizedStringResource.libraryFailureReset.localized(for: locale)
    case .samples:
      LocalizedStringResource.libraryFailureSamples.localized(for: locale)
    }
  }
}
