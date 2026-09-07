// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

enum RecipeLibraryIssue: Equatable {
  case read
  case reset
  case samples
  case disposition

  func message(locale: Locale = .current) -> String {
    switch self {
    case .read:
      LocalizedStringResource.libraryFailureRead.localized(for: locale)
    case .reset:
      LocalizedStringResource.libraryFailureReset.localized(for: locale)
    case .disposition:
      LocalizedStringResource.recipeDispositionFailure.localized(for: locale)
    case .samples:
      LocalizedStringResource.libraryFailureSamples.localized(for: locale)
    }
  }
}
