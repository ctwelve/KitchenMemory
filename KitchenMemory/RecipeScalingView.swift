// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import SwiftUI

struct RecipeScalingSelection: Equatable {
  let recipeYield: RecipeYield?
  var selectedBasisIndex = 0
  var workingYield: RationalQuantity?

  init(recipeYield: RecipeYield?) {
    self.recipeYield = recipeYield
    workingYield = recipeYield?.scalingBases.first?.quantity
  }

  var bases: [RecipeYieldBasis] { recipeYield?.scalingBases ?? [] }

  var selectedBasis: RecipeYieldBasis? {
    guard bases.indices.contains(selectedBasisIndex) else { return nil }
    return bases[selectedBasisIndex]
  }

  var scale: RecipeScale? {
    guard let baseYield = selectedBasis?.quantity, let workingYield else { return nil }
    return RecipeScale(baseYield: baseYield, workingYield: workingYield)
  }

  var displayedYield: String {
    guard let recipeYield else { return "" }
    guard let scale, scale.multiplier != RationalQuantity(numerator: 1) else {
      return recipeYield.originalText
    }
    return "\(workingYieldLabel) (base: \(recipeYield.originalText))"
  }

  var workingYieldLabel: String {
    guard let recipeYield, let workingYield else { return recipeYield?.originalText ?? "" }
    return joinedYield(quantity: workingYield, unitText: recipeYield.unitText)
  }

  var canDecreaseWorkingYield: Bool {
    guard let current = workingYield?.normalized else { return false }
    return current.numerator > current.denominator
  }

  var canIncreaseWorkingYield: Bool {
    guard let current = workingYield?.normalized else { return false }
    let (maximumNumerator, overflow) = current.denominator.multipliedReportingOverflow(by: 999)
    return !overflow && current.numerator <= maximumNumerator - current.denominator
  }

  mutating func selectBasis(_ index: Int) {
    guard bases.indices.contains(index) else { return }
    selectedBasisIndex = index
    workingYield = bases[index].quantity
  }

  mutating func adjustWorkingYield(by wholeNumber: Int) {
    guard let current = workingYield?.normalized else { return }
    let (delta, deltaOverflow) = current.denominator.multipliedReportingOverflow(
      by: wholeNumber
    )
    let (numerator, additionOverflow) = current.numerator.addingReportingOverflow(delta)
    guard !deltaOverflow, !additionOverflow, numerator > 0 else { return }

    let (maximumNumerator, maximumOverflow) = current.denominator.multipliedReportingOverflow(
      by: 999
    )
    guard !maximumOverflow, numerator <= maximumNumerator else { return }
    workingYield = RationalQuantity(
      numerator: numerator,
      denominator: current.denominator
    ).normalized
  }

  func basisLabel(_ basis: RecipeYieldBasis) -> String {
    let value = joinedYield(quantity: basis.quantity, unitText: recipeYield?.unitText)
    switch basis.kind {
    case .exact:
      return value
    case .approximate:
      return "About \(value)"
    case .rangeLowerBound:
      return "Lower estimate: \(value)"
    case .rangeUpperBound:
      return "Upper estimate: \(value)"
    }
  }

  private func joinedYield(quantity: RationalQuantity, unitText: String?) -> String {
    let unit: String?
    if quantity == RationalQuantity(numerator: 1), let unitText, unitText.hasSuffix("s") {
      unit = String(unitText.dropLast())
    } else {
      unit = unitText
    }
    return [quantity.renderedText, unit].compactMap { $0 }.joined(separator: " ")
  }
}

struct RecipeScalingControls: View {
  @Binding var selection: RecipeScalingSelection

  @ViewBuilder
  var body: some View {
    if !selection.bases.isEmpty {
      VStack(alignment: .leading, spacing: 18) {
        heading
        VStack(alignment: .leading, spacing: 14) {
          if selection.bases.count > 1 {
            Picker("Base yield", selection: basisBinding) {
              ForEach(selection.bases.indices, id: \.self) { index in
                Text(selection.basisLabel(selection.bases[index])).tag(index)
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
        Text(selection.workingYieldLabel)
          .font(.title3.monospacedDigit())
          .foregroundStyle(Color("IconMark"))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Working yield")
      .accessibilityValue(selection.workingYieldLabel)
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
          selection.workingYield = selection.selectedBasis?.quantity
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
        Text(scaled?.ingredient.effectiveDisplayText ?? ingredient.effectiveDisplayText)
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
      return "Check this amount manually when changing the yield."
    case .unchangedFixed:
      return isBaseScale ? nil : "Fixed amount; left unchanged."
    case .unchangedText:
      return isBaseScale ? nil : "Written amount; left unchanged."
    case .unchangedPresentationOverride:
      return isBaseScale ? nil : "Display wording could not be scaled safely; left unchanged."
    case .unchangedArithmeticFailure:
      return "Could not scale this amount safely; left unchanged."
    }
  }

  private var isBaseScale: Bool {
    scale?.multiplier == RationalQuantity(numerator: 1)
  }
}
