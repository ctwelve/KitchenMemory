// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// Reading-only yield selection and arithmetic, independent of presentation.
public struct RecipeScalingState: Equatable, Sendable {
  public let recipeYield: RecipeYield?
  public private(set) var selectedBasisIndex = 0
  public private(set) var workingYield: RationalQuantity?

  public init(recipeYield: RecipeYield?) {
    self.recipeYield = recipeYield
    workingYield = recipeYield?.scalingBases.first?.quantity
  }

  public var bases: [RecipeYieldBasis] { recipeYield?.scalingBases ?? [] }

  public var selectedBasis: RecipeYieldBasis? {
    guard bases.indices.contains(selectedBasisIndex) else { return nil }
    return bases[selectedBasisIndex]
  }

  public var scale: RecipeScale? {
    guard let baseYield = selectedBasis?.quantity, let workingYield else { return nil }
    return RecipeScale(baseYield: baseYield, workingYield: workingYield)
  }

  public var canDecreaseWorkingYield: Bool {
    guard let current = workingYield?.normalized else { return false }
    return current.numerator > current.denominator
  }

  public var canIncreaseWorkingYield: Bool {
    guard let current = workingYield?.normalized else { return false }
    let (maximumNumerator, overflow) = current.denominator.multipliedReportingOverflow(by: 999)
    return !overflow && current.numerator <= maximumNumerator - current.denominator
  }

  public mutating func selectBasis(_ index: Int) {
    guard bases.indices.contains(index) else { return }
    selectedBasisIndex = index
    workingYield = bases[index].quantity
  }

  public mutating func adjustWorkingYield(by wholeNumber: Int) {
    guard let current = workingYield?.normalized else { return }
    let (delta, deltaOverflow) = current.denominator.multipliedReportingOverflow(by: wholeNumber)
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

  public mutating func resetWorkingYield() {
    workingYield = selectedBasis?.quantity
  }
}
