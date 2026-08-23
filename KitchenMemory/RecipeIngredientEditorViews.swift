// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import SwiftUI

struct IngredientSectionEditor: View {
  @Binding var section: IngredientSection
  let moveUp: () -> Void
  let moveDown: () -> Void
  let delete: () -> Void

  var body: some View {
    EditorDisclosureGroup(
      title: section.title ?? "Ingredient section",
      accessibilityIdentifier: "ingredient-editor-section-\(section.id.rawValue.uuidString)"
    ) {
      EditorTextField("Section name", text: titleBinding, prompt: "Optional")
      ForEach(section.ingredients.indices, id: \.self) { index in
        IngredientEditor(
            ingredient: $section.ingredients[index],
            moveUp: { move(index, by: -1) },
            moveDown: { move(index, by: 1) },
            delete: { section.ingredients.remove(at: index) }
        )
      }
      Button("Add Ingredient", systemImage: "plus") {
        section.ingredients.append(RecipeIngredient(parseState: .edited))
      }
        .accessibilityIdentifier("add-ingredient-\(section.id.rawValue.uuidString)")
      HStack {
        Button("Move Up", action: moveUp)
        Button("Move Down", action: moveDown)
        Spacer()
        Button("Delete Section", role: .destructive, action: delete)
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
        ? "New ingredient"
        : RecipePresentationFormatter(locale: locale).ingredient(ingredient),
      accessibilityIdentifier: "ingredient-editor-row-\(ingredient.id.rawValue.uuidString)"
    ) {
      LabeledContent {
        Text(ingredient.originalText.isEmpty ? "Not available" : ingredient.originalText)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      } label: {
        EditorFieldLabel("Original wording")
      }
      Picker(selection: $ingredient.presentationMode) {
        ForEach(RecipeIngredient.PresentationMode.allCases, id: \.self) {
          Text($0.label).tag($0)
        }
      } label: {
        EditorFieldLabel("Presentation")
      }
      if ingredient.presentationMode == .custom {
        EditorTextField(
          "Custom text",
          text: optionalBinding(\.customDisplayText),
          multiline: true
        )
      }
      EditorTextField("Ingredient name", text: optionalBinding(\.ingredientText))
      IngredientQuantityEditor(quantity: $ingredient.quantity, package: $ingredient.package)
      EditorTextField("Unit", text: optionalBinding(\.unitText))
      EditorTextField("Preparation", text: optionalBinding(\.preparation), multiline: true)
      EditorTextField("Note", text: optionalBinding(\.note), multiline: true)
      Toggle(isOn: $ingredient.isOptional) {
        EditorFieldLabel("Optional")
      }
      Picker(selection: $ingredient.scalingBehavior) {
        ForEach(RecipeIngredient.ScalingBehavior.allCases, id: \.self) { Text($0.label).tag($0) }
      } label: {
        EditorFieldLabel("Scaling")
      }
        HStack {
            Button("Move Up", action: moveUp)
            Button("Move Down", action: moveDown)
            Spacer()
            Button("Delete", role: .destructive, action: delete)
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
  var label: String {
    switch self {
    case .linear: String(localized: "Linear")
    case .fixed: String(localized: "Fixed")
    case .manualReview: String(localized: "Manual review")
    }
  }
}
private extension RecipeIngredient.PresentationMode {
  var label: String {
    switch self {
    case .structured: String(localized: "Structured")
    case .original: String(localized: "Original")
    case .custom: String(localized: "Custom")
    }
  }
}
