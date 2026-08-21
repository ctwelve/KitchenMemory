// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import SwiftUI

struct RecipeYieldEditor: View {
  @Binding var recipeYield: RecipeYield?

  var body: some View {
    EditorTextField(
      "Display wording",
      text: originalTextBinding,
      prompt: "e.g. Serves 4 or Makes one skillet"
    )
    .accessibilityIdentifier("recipe-editor-yield-wording")

    Toggle("Enable recipe scaling", isOn: scalingEnabledBinding)
      .accessibilityIdentifier("recipe-editor-yield-scaling")

    if recipeYield?.quantity != nil {
      QuantityExpressionEditor(
        quantity: quantityBinding,
        availableKinds: [.exact, .range, .approximate],
        accessibilityIdentifier: "recipe-editor-yield-quantity"
      )
      EditorTextField(
        "Yield unit",
        text: unitTextBinding,
        prompt: "servings, loaves, skillets…"
      )
      .accessibilityIdentifier("recipe-editor-yield-unit")
      Text("The numeric yield is the basis used to scale ingredient amounts.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var originalTextBinding: Binding<String> {
    Binding(
      get: { recipeYield?.originalText ?? "" },
      set: { newValue in
        if recipeYield == nil {
          recipeYield = RecipeYield(originalText: newValue)
        } else {
          recipeYield?.originalText = newValue
        }
      }
    )
  }

  private var scalingEnabledBinding: Binding<Bool> {
    Binding(
      get: { recipeYield?.quantity != nil },
      set: { isEnabled in
        if isEnabled {
          if recipeYield == nil {
            recipeYield = RecipeYield(originalText: "")
          }
          recipeYield?.quantity = QuantityExpression(
            kind: .exact,
            lowerBound: RationalQuantity(numerator: 1)
          )
        } else {
          recipeYield?.quantity = nil
          recipeYield?.unitText = nil
        }
      }
    )
  }

  private var quantityBinding: Binding<QuantityExpression?> {
    Binding(
      get: { recipeYield?.quantity },
      set: { recipeYield?.quantity = $0 }
    )
  }

  private var unitTextBinding: Binding<String> {
    Binding(
      get: { recipeYield?.unitText ?? "" },
      set: { recipeYield?.unitText = $0 }
    )
  }
}
