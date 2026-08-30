// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
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
    return LocalizedStringResource.recipeScalingDisplayedYield(
      workingYield: workingYieldLabel(locale: locale),
      baseYield: base
    ).localized(for: locale)
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
      return LocalizedStringResource.recipeScalingBasisApproximate(value: value).localized(for: locale)
    case .rangeLowerBound:
      return LocalizedStringResource.recipeScalingBasisLowerEstimate(value: value).localized(for: locale)
    case .rangeUpperBound:
      return LocalizedStringResource.recipeScalingBasisUpperEstimate(value: value).localized(for: locale)
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
            Picker(LocalizedStringResource.recipeScalingBaseYield, selection: basisBinding) {
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
      Text(.recipeScalingSection)
        .accessibilityHeading(.h2)
        .accessibilityIdentifier("recipe-scaling-section")
    }
    .font(.title2.bold())
    .foregroundStyle(Color("IconMark"))
  }

  private var workingYieldStepper: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(.recipeScalingWorkingYield)
          .font(.headline)
        Text(selection.workingYieldLabel(locale: locale))
          .font(.title3.monospacedDigit())
          .foregroundStyle(Color("IconMark"))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(Text(.recipeScalingWorkingYield))
      .accessibilityValue(selection.workingYieldLabel(locale: locale))
      .accessibilityIdentifier("recipe-working-yield")

      Button {
        selection.adjustWorkingYield(by: -1)
      } label: {
        Image(systemName: "minus")
      }
      .disabled(!selection.canDecreaseWorkingYield)
      .accessibilityLabel(Text(.recipeScalingActionDecrease))
      .accessibilityIdentifier("recipe-working-yield-decrement")

      Button {
        selection.adjustWorkingYield(by: 1)
      } label: {
        Image(systemName: "plus")
      }
      .disabled(!selection.canIncreaseWorkingYield)
      .accessibilityLabel(Text(.recipeScalingActionIncrease))
      .accessibilityIdentifier("recipe-working-yield-increment")
    }
  }

  private var footer: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(.recipeScalingReadingOnlyNote)
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer(minLength: 12)
      if selection.workingYield != selection.selectedBasis?.quantity {
        Button(.actionReset) {
          selection.resetWorkingYield()
        }
        .accessibilityLabel(Text(.recipeScalingActionResetAccessibilityLabel))
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
      return LocalizedStringResource.recipeScalingStatusManualReview.localized(for: locale)
    case .unchangedFixed:
      return isBaseScale
        ? nil
        : LocalizedStringResource.recipeScalingStatusFixed.localized(for: locale)
    case .unchangedText:
      return isBaseScale
        ? nil
        : LocalizedStringResource.recipeScalingStatusWritten.localized(for: locale)
    case .unchangedPresentationOverride:
      return isBaseScale
        ? nil
        : LocalizedStringResource.recipeScalingStatusPresentationOverride.localized(for: locale)
    case .unchangedArithmeticFailure:
      return LocalizedStringResource.recipeScalingStatusArithmeticFailure.localized(for: locale)
    }
  }

  private var isBaseScale: Bool {
    scale?.multiplier == RationalQuantity(numerator: 1)
  }
}
