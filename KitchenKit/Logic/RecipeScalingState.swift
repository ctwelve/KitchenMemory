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

  /// Restores the complete, explicit scale retained by a Cooking Session.
  /// The exact multiplier selects the authored basis when a range has more
  /// than one valid base; mismatched state safely falls back to the snapshot.
  public init(
    recipeYield: RecipeYield?,
    workingYield: RationalQuantity?,
    exactScale: RationalQuantity?
  ) {
    self.init(recipeYield: recipeYield)
    guard let workingYield, let exactScale,
          let index = bases.firstIndex(where: { basis in
            RecipeScale(baseYield: basis.quantity, workingYield: workingYield)?.multiplier
              == exactScale
          }) else { return }
    selectedBasisIndex = index
    self.workingYield = workingYield
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
