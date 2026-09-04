// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct IngredientSectionEditor: View {
  @Binding var section: IngredientSection
  let moveUp: () -> Void
  let moveDown: () -> Void
  let delete: () -> Void
  @Environment(\.locale) private var locale

  var body: some View {
    EditorDisclosureGroup(
      title: section.title
        ?? LocalizedStringResource.recipeEditorIngredientSectionFallbackTitle.localized(for: locale),
      accessibilityIdentifier: "ingredient-editor-section-\(section.id.rawValue.uuidString)"
    ) {
      EditorTextField(.recipeEditorSectionNameField, text: titleBinding, prompt: .fieldOptionalPrompt)
      ForEach(section.ingredients.indices, id: \.self) { index in
        IngredientEditor(
            ingredient: $section.ingredients[index],
            moveUp: { move(index, by: -1) },
            moveDown: { move(index, by: 1) },
            delete: { section.ingredients.remove(at: index) }
        )
        .modifier(EditorGroupSurface(index: index, level: .item))
      }
      Button(.recipeEditorIngredientsActionAdd, systemImage: "plus") {
        section.ingredients.append(RecipeIngredient(parseState: .edited))
      }
        .accessibilityIdentifier("add-ingredient-\(section.id.rawValue.uuidString)")
      HStack {
        Button(.actionMoveUp, action: moveUp)
        Button(.actionMoveDown, action: moveDown)
        Spacer()
        Button(.actionDeleteSection, role: .destructive, action: delete)
      }
    }
  }
  private var titleBinding: Binding<String> {
    Binding(
      get: { section.title ?? "" },
      set: { section.title = $0 }
    )
  }
  private func move(_ index: Int, by offset: Int) {
    let destination = index + offset
    guard section.ingredients.indices.contains(destination) else { return }
    section.ingredients.swapAt(index, destination)
  }
}

private struct IngredientEditor: View {
  @Binding var ingredient: RecipeIngredient
  @Environment(\.locale) private var locale
  let moveUp: () -> Void
  let moveDown: () -> Void
  let delete: () -> Void
  var body: some View {
    EditorDisclosureGroup(
      title: !ingredient.hasMeaningfulDisplayContent
        ? LocalizedStringResource.recipeEditorIngredientFallbackTitle.localized(for: locale)
        : RecipePresentationFormatter(locale: locale).ingredient(ingredient),
      accessibilityIdentifier: "ingredient-editor-row-\(ingredient.id.rawValue.uuidString)"
    ) {
      LabeledContent {
        Text(
          ingredient.originalText.isEmpty
            ? LocalizedStringResource.valueNotAvailable.localized(for: locale)
            : ingredient.originalText
        )
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      } label: {
        EditorFieldLabel(.recipeEditorIngredientOriginalWordingField)
      }
      Picker(selection: $ingredient.presentationMode) {
        ForEach(RecipeIngredient.PresentationMode.allCases, id: \.self) {
          Text($0.label).tag($0)
        }
      } label: {
        EditorFieldLabel(.recipeEditorIngredientPresentationField)
      }
      if ingredient.presentationMode == .custom {
        EditorTextField(
          .recipeEditorIngredientCustomTextField,
          text: optionalBinding(\.customDisplayText),
          multiline: true
        )
      }
      EditorTextField(.recipeEditorIngredientNameField, text: optionalBinding(\.ingredientText))
      IngredientQuantityEditor(quantity: $ingredient.quantity, package: $ingredient.package)
      EditorTextField(.recipeEditorIngredientUnitField, text: optionalBinding(\.unitText))
      EditorTextField(
        .recipeEditorIngredientPreparationField,
        text: optionalBinding(\.preparation),
        multiline: true
      )
      EditorTextField(.recipeEditorIngredientNoteField, text: optionalBinding(\.note), multiline: true)
      Toggle(isOn: $ingredient.isOptional) {
        EditorFieldLabel(.fieldOptionalPrompt)
      }
      Picker(selection: $ingredient.scalingBehavior) {
        ForEach(RecipeIngredient.ScalingBehavior.allCases, id: \.self) { Text($0.label).tag($0) }
      } label: {
        EditorFieldLabel(.recipeEditorIngredientScalingField)
      }
        HStack {
            Button(.actionMoveUp, action: moveUp)
            Button(.actionMoveDown, action: moveDown)
            Spacer()
            Button(.actionDelete, role: .destructive, action: delete)
        }
    }
  }
  private func optionalBinding(_ keyPath: WritableKeyPath<RecipeIngredient, String?>) -> Binding<String> {
    Binding(
      get: { ingredient[keyPath: keyPath] ?? "" },
      set: { ingredient[keyPath: keyPath] = $0 }
    )
  }
}

private extension RecipeIngredient.ScalingBehavior {
  static var allCases: [Self] { [.linear, .fixed, .manualReview] }
  var label: LocalizedStringResource {
    switch self {
    case .linear: .recipeIngredientScalingLinear
    case .fixed: .recipeIngredientScalingFixed
    case .manualReview: .recipeIngredientScalingManualReview
    }
  }
}
private extension RecipeIngredient.PresentationMode {
  var label: LocalizedStringResource {
    switch self {
    case .structured: .recipeIngredientPresentationStructured
    case .original: .recipeSourceKindOriginal
    case .custom: .recipeIngredientPresentationCustom
    }
  }
}
