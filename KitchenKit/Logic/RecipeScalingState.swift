// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// Reading-only yield selection and arithmetic, independent of presentation.
public struct RecipeScalingState: Equatable, Sendable {
  /// Authored yield that supplies the available scaling bases.
  public let recipeYield: RecipeYield?
  /// Index of the current authored scaling basis; initially the first basis.
  public private(set) var selectedBasisIndex = 0
  /// Exact selected working quantity, or nil when authored yield cannot supply a base.
  public private(set) var workingYield: RationalQuantity?

  /// Starts at the first authored scaling basis without modifying Recipe content.
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

  /// Valid authored yield bases, including explicit alternatives for a range.
  public var bases: [RecipeYieldBasis] { recipeYield?.scalingBases ?? [] }

  /// Currently selected basis, or nil when no valid basis exists.
  public var selectedBasis: RecipeYieldBasis? {
    guard bases.indices.contains(selectedBasisIndex) else { return nil }
    return bases[selectedBasisIndex]
  }

  /// Exact multiplier from the selected base to the working yield, when both are valid.
  public var scale: RecipeScale? {
    guard let baseYield = selectedBasis?.quantity, let workingYield else { return nil }
    return RecipeScale(baseYield: baseYield, workingYield: workingYield)
  }

  /// Whether a whole-unit decrease remains positive under the current arithmetic policy.
  public var canDecreaseWorkingYield: Bool {
    guard let current = workingYield?.normalized else { return false }
    return current.numerator > current.denominator
  }

  /// Whether a whole-unit increase stays within 999 and avoids integer overflow.
  public var canIncreaseWorkingYield: Bool {
    guard let current = workingYield?.normalized else { return false }
    let (maximumNumerator, overflow) = current.denominator.multipliedReportingOverflow(by: 999)
    return !overflow && current.numerator <= maximumNumerator - current.denominator
  }

  /// Selects a valid basis and resets working yield to it; invalid indices do nothing.
  public mutating func selectBasis(_ index: Int) {
    guard bases.indices.contains(index) else { return }
    selectedBasisIndex = index
    workingYield = bases[index].quantity
  }

  /// Adds whole units to the exact working yield.
  /// Requests that overflow, become nonpositive, or exceed 999 leave it unchanged.
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

  /// Restores the selected authored basis quantity without changing basis selection.
  public mutating func resetWorkingYield() {
    workingYield = selectedBasis?.quantity
  }
}
