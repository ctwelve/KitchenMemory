// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

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
