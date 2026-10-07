// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

extension RecipeSource.Kind {
  var label: LocalizedStringResource {
    switch self {
    case .original: .recipeSourceKindOriginal
    case .webpage: .recipeSourceKindWebpage
    case .book: .recipeSourceKindBook
    case .person: .recipeSourceKindPerson
    case .imported: .recipeSourceKindImported
    }
  }
}
