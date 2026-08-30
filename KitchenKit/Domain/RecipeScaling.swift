// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

public extension RationalQuantity {
    var normalized: RationalQuantity? {
        guard numerator >= 0, denominator > 0 else { return nil }
        let divisor = greatestCommonDivisor(numerator, denominator)
        return RationalQuantity(
            numerator: numerator / divisor,
            denominator: denominator / divisor
        )
    }

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

public struct RecipeYieldBasis: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case exact
        case approximate
        case rangeLowerBound
        case rangeUpperBound
    }

    public let kind: Kind
    public let quantity: RationalQuantity

    public init(kind: Kind, quantity: RationalQuantity) {
        self.kind = kind
        self.quantity = quantity
    }
}

public extension RecipeYield {
    /// Numeric choices that may honestly serve as the denominator for scaling.
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
    public let baseYield: RationalQuantity
    public let workingYield: RationalQuantity
    public let multiplier: RationalQuantity

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

public struct ScaledRecipeIngredient: Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case scaled
        case unchangedFixed
        case unchangedManualReview
        case unchangedText
        case unchangedWithoutQuantity
        case unchangedPresentationOverride
        case unchangedArithmeticFailure
    }

    public let ingredient: RecipeIngredient
    public let status: Status

    public init(ingredient: RecipeIngredient, status: Status) {
        self.ingredient = ingredient
        self.status = status
    }
}

public extension RecipeIngredient {
    /// Produces a reading-only ingredient value; the maintained recipe remains untouched.
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
