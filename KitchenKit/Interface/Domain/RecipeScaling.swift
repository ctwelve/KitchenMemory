// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

public extension RationalQuantity {
    /// The reduced nonnegative ratio, or nil for a negative numerator or nonpositive denominator.
    ///
    /// Zero normalizes to 0/1.
    var normalized: RationalQuantity? {
        guard numerator >= 0, denominator > 0 else { return nil }
        let divisor = greatestCommonDivisor(numerator, denominator)
        return RationalQuantity(
            numerator: numerator / divisor,
            denominator: denominator / divisor
        )
    }

    /// Multiplies two valid nonnegative ratios exactly, reducing crosswise before arithmetic.
    ///
    /// Returns nil for invalid input or integer overflow; it never falls back to a rounded value.
    func multiplied(by multiplier: RationalQuantity) -> RationalQuantity? {
        guard let value = normalized, let multiplier = multiplier.normalized else { return nil }

        // Cancel crosswise before multiplying so a representable final value
        // does not fail only because its unreduced intermediate products overflow.
        let leftDivisor = greatestCommonDivisor(value.numerator, multiplier.denominator)
        let rightDivisor = greatestCommonDivisor(multiplier.numerator, value.denominator)
        let leftNumerator = value.numerator / leftDivisor
        let rightDenominator = multiplier.denominator / leftDivisor
        let rightNumerator = multiplier.numerator / rightDivisor
        let leftDenominator = value.denominator / rightDivisor
        let (numerator, numeratorOverflow) = leftNumerator.multipliedReportingOverflow(
            by: rightNumerator
        )
        let (denominator, denominatorOverflow) = leftDenominator.multipliedReportingOverflow(
            by: rightDenominator
        )
        guard !numeratorOverflow, !denominatorOverflow else { return nil }
        return RationalQuantity(numerator: numerator, denominator: denominator).normalized
    }
}

private func greatestCommonDivisor(_ first: Int, _ second: Int) -> Int {
    var left = first
    var right = second
    while right != 0 {
        (left, right) = (right, left % right)
    }
    return max(left, 1)
}

/// One explicit numeric interpretation offered as the base for scaling a yield.
public struct RecipeYieldBasis: Equatable, Sendable {
    /// Explains which authored yield value supplies the scaling denominator.
    public enum Kind: Equatable, Sendable {
        /// Uses the exact authored yield.
        case exact
        /// Uses the approximate authored amount while retaining that qualification.
        case approximate
        /// Uses the lower endpoint of the authored range.
        case rangeLowerBound
        /// Uses the upper endpoint of the authored range.
        case rangeUpperBound
    }

    /// Explains the authored numeric choice rather than hiding a range decision.
    public let kind: Kind
    /// The positive normalized amount offered by `RecipeYield.scalingBases`.
    public let quantity: RationalQuantity

    /// Retains a proposed basis; direct construction does not validate its quantity.
    public init(kind: Kind, quantity: RationalQuantity) {
        self.kind = kind
        self.quantity = quantity
    }
}

public extension RecipeYield {
    /// Positive normalized choices that may honestly serve as the denominator for scaling.
    ///
    /// Exact and approximate yields offer their lower bound. Ranges offer valid
    /// endpoints separately, coalescing equal values. Invalid, zero, absent, or
    /// textual amounts offer no basis; no value is inferred from original wording.
    var scalingBases: [RecipeYieldBasis] {
        guard let quantity else { return [] }
        switch quantity.kind {
        case .exact:
            return basis(.exact, quantity.lowerBound)
        case .approximate:
            return basis(.approximate, quantity.lowerBound)
        case .range:
            let lower = basis(.rangeLowerBound, quantity.lowerBound)
            let upper = basis(.rangeUpperBound, quantity.upperBound)
            return lower.first?.quantity == upper.first?.quantity ? lower : lower + upper
        case .none, .text:
            return []
        }
    }

    private func basis(
        _ kind: RecipeYieldBasis.Kind,
        _ quantity: RationalQuantity?
    ) -> [RecipeYieldBasis] {
        guard let quantity = quantity?.normalized, quantity.numerator > 0 else { return [] }
        return [RecipeYieldBasis(kind: kind, quantity: quantity)]
    }
}

/// Exact ratio between a recipe's selected base yield and its working yield.
public struct RecipeScale: Equatable, Sendable {
    /// The positive normalized authored output chosen as the scaling denominator.
    public let baseYield: RationalQuantity
    /// The positive normalized output requested for this reading or cook.
    public let workingYield: RationalQuantity
    /// The exact working-to-base ratio, reduced without floating-point rounding.
    public let multiplier: RationalQuantity

    /// Creates an exact scale only for valid positive yields and representable arithmetic.
    ///
    /// Returns nil for zero, negative, invalid-denominator, or overflowing values.
    public init?(baseYield: RationalQuantity, workingYield: RationalQuantity) {
        guard let baseYield = baseYield.normalized, baseYield.numerator > 0,
              let workingYield = workingYield.normalized, workingYield.numerator > 0,
              let multiplier = workingYield.multiplied(
                by: RationalQuantity(
                    numerator: baseYield.denominator,
                    denominator: baseYield.numerator
                )
              )
        else { return nil }
        self.baseYield = baseYield
        self.workingYield = workingYield
        self.multiplier = multiplier
    }
}

public extension QuantityExpression {
    /// Scales numeric bounds exactly while preserving the kind and retained text.
    ///
    /// Absent and textual expressions return unchanged. Returns nil when a required
    /// bound is missing, invalid, or overflows; it does not parse the text.
    func scaled(by scale: RecipeScale) -> QuantityExpression? {
        switch kind {
        case .exact, .approximate:
            guard let lowerBound = lowerBound?.multiplied(by: scale.multiplier) else { return nil }
            return QuantityExpression(kind: kind, lowerBound: lowerBound, text: text)
        case .range:
            guard let lowerBound = lowerBound?.multiplied(by: scale.multiplier),
                  let upperBound = upperBound?.multiplied(by: scale.multiplier)
            else { return nil }
            return QuantityExpression(
                kind: .range,
                lowerBound: lowerBound,
                upperBound: upperBound,
                text: text
            )
        case .none, .text:
            return self
        }
    }
}

/// A transient reading value paired with the reason scaling did or did not change it.
public struct ScaledRecipeIngredient: Equatable, Sendable {
    /// Explains whether arithmetic changed the row or why its original value was retained.
    public enum Status: Equatable, Sendable {
        /// Structured quantity was scaled successfully, possibly to the same amount.
        case scaled
        /// The authored fixed policy preserved the row.
        case unchangedFixed
        /// The authored policy requires human review instead of arithmetic.
        case unchangedManualReview
        /// The amount is absent or textual and cannot be interpreted numerically.
        case unchangedText
        /// The row has no quantity expression.
        case unchangedWithoutQuantity
        /// Custom presentation, or unstructured original presentation, prevented a truthful scaled display.
        case unchangedPresentationOverride
        /// A required bound was invalid, missing, or unrepresentable in exact arithmetic.
        case unchangedArithmeticFailure
    }

    /// The transient row copy; authored identity and original wording are retained.
    public let ingredient: RecipeIngredient
    /// The reason quantity changed or the original row was returned.
    public let status: Status

    /// Pairs a transient row with its scaling explanation without applying arithmetic.
    public init(ingredient: RecipeIngredient, status: Status) {
        self.ingredient = ingredient
        self.status = status
    }
}

public extension RecipeIngredient {
    /// Produces a transient reading value with an explicit scaling status.
    ///
    /// Fixed and manual-review policies win before any quantity checks. Custom
    /// display, absent/textual amounts, and arithmetic failures preserve the row.
    /// A changed amount shown in original mode switches the transient copy to
    /// structured presentation only when an ingredient name can support it.
    /// Authored source wording, package size, and maintained content remain retained.
    func scaled(using scale: RecipeScale) -> ScaledRecipeIngredient {
        switch scalingBehavior {
        case .fixed:
            return ScaledRecipeIngredient(ingredient: self, status: .unchangedFixed)
        case .manualReview:
            return ScaledRecipeIngredient(ingredient: self, status: .unchangedManualReview)
        case .linear:
            break
        }

        guard presentationMode != .custom else {
            return ScaledRecipeIngredient(ingredient: self, status: .unchangedPresentationOverride)
        }
        guard let quantity else {
            return ScaledRecipeIngredient(ingredient: self, status: .unchangedWithoutQuantity)
        }
        guard quantity.kind != .none, quantity.kind != .text else {
            return ScaledRecipeIngredient(ingredient: self, status: .unchangedText)
        }
        guard let scaledQuantity = quantity.scaled(by: scale) else {
            return ScaledRecipeIngredient(ingredient: self, status: .unchangedArithmeticFailure)
        }

        var scaled = self
        scaled.quantity = scaledQuantity
        if presentationMode == .original, scale.multiplier != RationalQuantity(numerator: 1) {
            guard scaled.hasStructuredDisplayContent else {
                return ScaledRecipeIngredient(
                    ingredient: self,
                    status: .unchangedPresentationOverride
                )
            }
            // Original wording remains canonical. The transient scaled copy
            // uses its structured interpretation so the changed amount can be shown.
            scaled.presentationMode = .structured
        }
        return ScaledRecipeIngredient(ingredient: scaled, status: .scaled)
    }
}
