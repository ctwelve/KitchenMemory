// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

enum ActiveRecipeSheet: Identifiable {
  case create
  case edit(StoredRecipe)
  case importURL
  case review(RecipeImportOption)

  var id: String {
    switch self {
    case .create: "create"
    case .edit(let recipe): "edit-\(recipe.recipe.id.rawValue.uuidString)"
    case .importURL: "import-url"
    case .review(let option):
      "review-\(option.id.blockIndex)-\(option.id.objectIndex)"
    }
  }
}

struct RecipeLibrarySheetContent: View {
  let sheet: ActiveRecipeSheet
  let model: RecipeLibraryModel
  let selectSheet: (ActiveRecipeSheet) -> Void

  @ViewBuilder
  var body: some View {
    switch sheet {
    case .create:
      RecipeEditorView(mode: .create) { draft in
        model.createRecipe(from: draft)
      }
    case .edit(let storedRecipe):
      RecipeEditorView(mode: .revise, draft: RecipeDraft(revision: storedRecipe.revision)) { draft in
        model.reviseRecipe(id: storedRecipe.recipe.id, from: draft)
      }
    case .importURL:
      RecipeURLImportView(
        load: { url in try await model.importRecipe(from: url) },
        select: { selectSheet(.review($0)) }
      )
    case .review(let option):
      RecipeEditorView(
        mode: .importReview,
        draft: option.draft,
        reviewConcerns: option.concerns
      ) { draft in
        model.createRecipe(from: draft)
      }
    }
  }
}
