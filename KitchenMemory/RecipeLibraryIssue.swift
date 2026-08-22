// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

enum RecipeLibraryIssue: Equatable {
  case read
  case save
  case reset

  var message: String {
    switch self {
    case .read:
      "Kitchen Memory could not read this recipe library."
    case .save:
      "Kitchen Memory could not save this recipe."
    case .reset:
      "Kitchen Memory could not reset this Kitchen. No reset was completed."
    }
  }
}
