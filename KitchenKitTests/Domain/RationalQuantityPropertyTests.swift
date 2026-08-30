// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenKit
import XCTest

final class RationalQuantityPropertyTests: XCTestCase {
    func testNormalizationProducesEquivalentReducedFractionsForSeededInputs() throws {
        let seed = try PropertyTestSeeds.bundled().seed(named: .domainRationalNormalization)
        var generator = SeededGenerator(seed: seed.value)

        for iteration in 0..<1_000 {
            let quantity = RationalQuantity(
                numerator: generator.int(in: 0...100_000),
                denominator: generator.int(in: 1...1_000)
            )
            let context = "seed=\(seed.hexadecimal) case=\(iteration) quantity=\(quantity)"
            let normalized = try XCTUnwrap(
                quantity.normalized,
                "Unexpected invalid value; \(context)"
            )

            XCTAssertEqual(
                normalized.numerator * quantity.denominator,
                quantity.numerator * normalized.denominator,
                "Normalization changed the value; \(context)"
            )
            XCTAssertEqual(
                greatestCommonDivisor(normalized.numerator, normalized.denominator),
                1,
                "Result was not reduced; \(context) normalized=\(normalized)"
            )
            XCTAssertEqual(
                normalized.normalized,
                normalized,
                "Normalization was not idempotent; \(context)"
            )
        }
    }

    func testMultiplicationMatchesReducedReferenceForSeededInputs() throws {
        let seed = try PropertyTestSeeds.bundled().seed(named: .domainRationalMultiplication)
        var generator = SeededGenerator(seed: seed.value)

        // Bounded operands keep the independent reference arithmetic far from
        // overflow; explicit edge tests below exercise machine-integer limits.
        for iteration in 0..<1_000 {
            let left = RationalQuantity(
                numerator: generator.int(in: 0...10_000),
                denominator: generator.int(in: 1...1_000)
            )
            let right = RationalQuantity(
                numerator: generator.int(in: 0...10_000),
                denominator: generator.int(in: 1...1_000)
            )
            let expected = reduced(
                numerator: left.numerator * right.numerator,
                denominator: left.denominator * right.denominator
            )
            let context = "seed=\(seed.hexadecimal) case=\(iteration) left=\(left) right=\(right)"

            XCTAssertEqual(
                left.multiplied(by: right),
                expected,
                "Multiplication mismatch; \(context)"
            )
            XCTAssertEqual(
                left.multiplied(by: right),
                right.multiplied(by: left),
                "Multiplication was not commutative; \(context)"
            )
        }
    }

    func testScalingThenApplyingItsInverseRestoresSeededQuantities() throws {
        let seed = try PropertyTestSeeds.bundled().seed(named: .domainRationalInverseScaling)
        var generator = SeededGenerator(seed: seed.value)

        for iteration in 0..<512 {
            let base = RationalQuantity(
                numerator: generator.int(in: 1...50),
                denominator: generator.int(in: 1...12)
            )
            let working = RationalQuantity(
                numerator: generator.int(in: 1...50),
                denominator: generator.int(in: 1...12)
            )
            let quantity = RationalQuantity(
                numerator: generator.int(in: 0...100),
                denominator: generator.int(in: 1...12)
            )
            let context = [
                "seed=\(seed.hexadecimal)", "case=\(iteration)", "base=\(base)",
                "working=\(working)", "quantity=\(quantity)",
            ].joined(separator: " ")
            let forwardScale = try XCTUnwrap(
                RecipeScale(baseYield: base, workingYield: working),
                "Forward scale unexpectedly failed; \(context)"
            )
            let inverseScale = try XCTUnwrap(
                RecipeScale(baseYield: working, workingYield: base),
                "Inverse scale unexpectedly failed; \(context)"
            )
            let scaled = try XCTUnwrap(
                quantity.multiplied(by: forwardScale.multiplier),
                "Forward multiplication unexpectedly failed; \(context)"
            )

            XCTAssertEqual(
                scaled.multiplied(by: inverseScale.multiplier),
                quantity.normalized,
                "Inverse scaling failed; \(context)"
            )
        }
    }

    func testCrossCancellationPreservesRepresentableExtremeResult() {
        let left = RationalQuantity(numerator: Int.max, denominator: 2)
        let right = RationalQuantity(numerator: 2, denominator: Int.max)

        XCTAssertEqual(left.multiplied(by: right), RationalQuantity(numerator: 1))
    }

    func testOverflowAndInvalidValuesFailWithoutTrapping() {
        XCTAssertNil(
            RationalQuantity(numerator: Int.max).multiplied(
                by: RationalQuantity(numerator: 2)
            )
        )
        XCTAssertNil(
            RationalQuantity(numerator: 1, denominator: Int.max).multiplied(
                by: RationalQuantity(numerator: 1, denominator: 2)
            )
        )
        XCTAssertNil(RationalQuantity(numerator: -1, denominator: 2).normalized)
        XCTAssertNil(RationalQuantity(numerator: 1, denominator: 0).normalized)
    }

    private func reduced(numerator: Int, denominator: Int) -> RationalQuantity {
        let divisor = greatestCommonDivisor(numerator, denominator)
        return RationalQuantity(
            numerator: numerator / divisor,
            denominator: denominator / divisor
        )
    }

    private func greatestCommonDivisor(_ first: Int, _ second: Int) -> Int {
        var left = first
        var right = second
        while right != 0 {
            (left, right) = (right, left % right)
        }
        return max(left, 1)
    }
}
