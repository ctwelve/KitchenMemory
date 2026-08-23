// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryLogic
import SwiftUI

extension RecipeScalingState {
  func displayedYield(locale: Locale) -> String {
    guard let recipeYield else { return "" }
    let formatter = RecipePresentationFormatter(locale: locale)
    let base = recipeYield.originalText.isEmpty
      ? recipeYield.quantity.flatMap { formatter.quantity($0) } ?? recipeYield.unitText ?? ""
      : recipeYield.originalText
    guard let scale, scale.multiplier != RationalQuantity(numerator: 1) else {
      return base
    }
    return String(localized: "\(workingYieldLabel(locale: locale)) (base: \(base))", locale: locale)
  }

  func workingYieldLabel(locale: Locale) -> String {
    guard let recipeYield, let workingYield else { return recipeYield?.originalText ?? "" }
    return RecipePresentationFormatter(locale: locale).yield(
      quantity: workingYield,
      unitText: recipeYield.unitText
    )
  }

  func basisLabel(_ basis: RecipeYieldBasis, locale: Locale) -> String {
    let value = RecipePresentationFormatter(locale: locale).yield(
      quantity: basis.quantity,
      unitText: recipeYield?.unitText
    )
    switch basis.kind {
    case .exact:
      return value
    case .approximate:
      return String(localized: "About \(value)", locale: locale)
    case .rangeLowerBound:
      return String(localized: "Lower estimate: \(value)", locale: locale)
    case .rangeUpperBound:
      return String(localized: "Upper estimate: \(value)", locale: locale)
    }
  }
}

struct RecipeScalingControls: View {
  @Binding var selection: RecipeScalingState
  @Environment(\.locale) private var locale

  @ViewBuilder
  var body: some View {
    if !selection.bases.isEmpty {
      VStack(alignment: .leading, spacing: 18) {
        heading
        VStack(alignment: .leading, spacing: 14) {
          if selection.bases.count > 1 {
            Picker("Base yield", selection: basisBinding) {
              ForEach(selection.bases.indices, id: \.self) { index in
                Text(selection.basisLabel(selection.bases[index], locale: locale)).tag(index)
              }
            }
            .accessibilityIdentifier("recipe-scaling-basis")
          }
          workingYieldStepper
          footer
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
      .background(Color("ContentSurface"), in: .rect(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color("SubtleBorder"), lineWidth: 1)
      }
      .accessibilityElement(children: .contain)
    }
  }

  private var heading: some View {
    HStack(spacing: 8) {
      Image(systemName: "arrow.up.left.and.arrow.down.right")
        .accessibilityHidden(true)
      Text("Scale recipe")
        .accessibilityHeading(.h2)
        .accessibilityIdentifier("recipe-scaling-section")
    }
    .font(.title2.bold())
    .foregroundStyle(Color("IconMark"))
  }

  private var workingYieldStepper: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Working yield")
          .font(.headline)
        Text(selection.workingYieldLabel(locale: locale))
          .font(.title3.monospacedDigit())
          .foregroundStyle(Color("IconMark"))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Working yield")
      .accessibilityValue(selection.workingYieldLabel(locale: locale))
      .accessibilityIdentifier("recipe-working-yield")

      Button {
        selection.adjustWorkingYield(by: -1)
      } label: {
        Image(systemName: "minus")
      }
      .disabled(!selection.canDecreaseWorkingYield)
      .accessibilityLabel("Decrease working yield")
      .accessibilityIdentifier("recipe-working-yield-decrement")

      Button {
        selection.adjustWorkingYield(by: 1)
      } label: {
        Image(systemName: "plus")
      }
      .disabled(!selection.canIncreaseWorkingYield)
      .accessibilityLabel("Increase working yield")
      .accessibilityIdentifier("recipe-working-yield-increment")
    }
  }

  private var footer: some View {
    HStack(alignment: .firstTextBaseline) {
      Text("Ingredient amounts update for reading only. The saved recipe stays unchanged.")
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer(minLength: 12)
      if selection.workingYield != selection.selectedBasis?.quantity {
        Button("Reset") {
          selection.resetWorkingYield()
        }
        .accessibilityLabel("Reset to base yield")
        .accessibilityIdentifier("recipe-scaling-reset")
      }
    }
  }

  private var basisBinding: Binding<Int> {
    Binding(
      get: { selection.selectedBasisIndex },
      set: { selection.selectBasis($0) }
    )
  }
}

struct ScaledIngredientRow: View {
  let ingredient: RecipeIngredient
  let scale: RecipeScale?
  @Environment(\.locale) private var locale

  private var scaled: ScaledRecipeIngredient? {
    scale.map { ingredient.scaled(using: $0) }
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: "circle.fill")
        .font(.system(size: 5))
        .foregroundStyle(Color("AccentColor"))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(RecipePresentationFormatter(locale: locale).ingredient(scaled?.ingredient ?? ingredient))
          .textSelection(.enabled)
        if let explanation {
          Label(explanation, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("scaled-ingredient-\(ingredient.id.rawValue.uuidString)")
  }

  private var explanation: String? {
    guard let scaled else { return nil }
    switch scaled.status {
    case .scaled, .unchangedWithoutQuantity:
      return nil
    case .unchangedManualReview:
      return String(localized: "Check this amount manually when changing the yield.")
    case .unchangedFixed:
      return isBaseScale ? nil : String(localized: "Fixed amount; left unchanged.")
    case .unchangedText:
      return isBaseScale ? nil : String(localized: "Written amount; left unchanged.")
    case .unchangedPresentationOverride:
      return isBaseScale
        ? nil
        : String(localized: "Display wording could not be scaled safely; left unchanged.")
    case .unchangedArithmeticFailure:
      return String(localized: "Could not scale this amount safely; left unchanged.")
    }
  }

  private var isBaseScale: Bool {
    scale?.multiplier == RationalQuantity(numerator: 1)
  }
}
