// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeReconciliationView: View {
  @Bindable var editor: RecipeEditingModel
  @State private var choiceFailed = false
  @Environment(\.locale) private var locale

  var body: some View {
    if let comparison = editor.draft.reconciliation {
      Section {
        Text(.recipeComparisonExplanation)
        if comparison.draft == nil { Text(.recipeComparisonChooseStart).font(.headline) }
        ForEach(comparison.revisions) { revision in
          DisclosureGroup {
            Button(.recipeComparisonUseRevision) { choose { try editor.draft.chooseRevision(revision.id) } }
            ForEach(RecipeComparisonField.allCases) { field in
              VStack(alignment: .leading, spacing: 6) {
                HStack {
                  Text(field.title).font(.headline)
                  if differs(field, revision: revision, comparison: comparison) {
                    Label(.recipeComparisonDifferent, systemImage: "arrow.left.arrow.right")
                      .font(.caption).foregroundStyle(.secondary)
                  }
                }
                Text(RecipeComparisonFormatter(locale: locale).value(field, revision: revision))
                  .textSelection(.enabled)
                if field == .media {
                  ForEach(revision.media) { media in
                    RecipeImage(media: media, contentMode: .fit).frame(height: 100)
                  }
                }
                Button(.recipeComparisonUseField) {
                  choose { try editor.draft.choose(field, from: revision.id) }
                }
                .disabled(comparison.draft == nil)
              }
              .padding(.vertical, 4)
            }
            ingredientChoices(revision)
          } label: {
            VStack(alignment: .leading) {
              Text(revision.title)
              Text(revision.id.rawValue.uuidString).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
          }
        }
      } header: { Text(.recipeComparisonTitle) }
      .alert(.recipeComparisonUnavailable, isPresented: $choiceFailed) {
        Button(.actionCancel, role: .cancel) {}
      } message: { Text(.recipeComparisonCorrectFields) }
    }
  }

  private func differs(_ field: RecipeComparisonField, revision: RecipeRevision,
                       comparison: RecipeReconciliation) -> Bool {
    comparison.revisions.contains {
      ((try? comparison.differences(between: revision.id, and: $0.id)) ?? []).contains(field)
    }
  }

  @ViewBuilder
  private func ingredientChoices(_ revision: RecipeRevision) -> some View {
    if editor.draft.reconciliation?.draft != nil {
      ForEach(Array(revision.ingredientSections.enumerated()), id: \.offset) { sectionIndex, section in
        ForEach(Array(section.ingredients.enumerated()), id: \.offset) { index, ingredient in
          Menu {
            ForEach(Array(editor.session.ingredientSections.enumerated()), id: \.offset) { target, section in
              Section(section.title ?? String(localized: "recipe.comparison.field.ingredients")) {
                Button(.recipeComparisonAddIngredient) {
                  choose {
                    try editor.draft.chooseIngredient(from: revision.id, section: sectionIndex,
                                                     ingredient: index, targetSection: target)
                  }
                }
                Text(.recipeComparisonReplaceIngredient)
                ForEach(Array(section.ingredients.enumerated()), id: \.offset) { targetIndex, targetIngredient in
                  Button(RecipeComparisonFormatter(locale: locale).ingredient(targetIngredient)) {
                    choose {
                      try editor.draft.chooseIngredient(from: revision.id, section: sectionIndex,
                                                       ingredient: index, targetSection: target, replacing: targetIndex)
                    }
                  }
                }
              }
            }
          } label: {
            VStack(alignment: .leading) {
              Text(.recipeComparisonChooseIngredient)
              Text(RecipeComparisonFormatter(locale: locale).ingredient(ingredient))
            }
          }
          .disabled(editor.session.ingredientSections.isEmpty)
        }
      }
    }
  }

  private func choose(_ action: () throws -> Void) {
    do { try action() } catch { choiceFailed = true }
  }
}
