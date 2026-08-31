// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

final class RecipeScalingStateTests: XCTestCase {
  func testMissingYieldHasNoScaleOrAdjustments() {
    var state = RecipeScalingState(recipeYield: nil)

    XCTAssertTrue(state.bases.isEmpty)
    XCTAssertNil(state.selectedBasis)
    XCTAssertNil(state.scale)
    XCTAssertFalse(state.canDecreaseWorkingYield)
    XCTAssertFalse(state.canIncreaseWorkingYield)
    state.selectBasis(1)
    state.adjustWorkingYield(by: 1)
    state.resetWorkingYield()
    XCTAssertNil(state.workingYield)
  }

  func testRangeBasisSelectionAdjustmentBoundsAndReset() {
    let recipeYield = RecipeYield(
      quantity: QuantityExpression(
        kind: .range,
        lowerBound: RationalQuantity(numerator: 2),
        upperBound: RationalQuantity(numerator: 4)
      ),
      unitText: "servings",
      originalText: "2 to 4 servings"
    )
    var state = RecipeScalingState(recipeYield: recipeYield)

    XCTAssertEqual(state.scale?.multiplier, RationalQuantity(numerator: 1))
    state.selectBasis(1)
    XCTAssertEqual(state.workingYield, RationalQuantity(numerator: 4))
    state.selectBasis(99)
    state.adjustWorkingYield(by: -3)
    XCTAssertEqual(state.workingYield, RationalQuantity(numerator: 1))
    XCTAssertFalse(state.canDecreaseWorkingYield)
    state.adjustWorkingYield(by: -1)
    XCTAssertEqual(state.workingYield, RationalQuantity(numerator: 1))
    state.adjustWorkingYield(by: 998)
    XCTAssertEqual(state.workingYield, RationalQuantity(numerator: 999))
    XCTAssertFalse(state.canIncreaseWorkingYield)
    state.adjustWorkingYield(by: 1)
    state.resetWorkingYield()
    XCTAssertEqual(state.workingYield, RationalQuantity(numerator: 4))
  }

  func testOverflowingAdjustmentsLeaveTheWorkingYieldUnchanged() {
    let hugeDenominator = RationalQuantity(numerator: 1, denominator: Int.max)
    var state = RecipeScalingState(recipeYield: RecipeYield(
      quantity: QuantityExpression(kind: .exact, lowerBound: hugeDenominator),
      originalText: "tiny"
    ))

    XCTAssertFalse(state.canIncreaseWorkingYield)
    state.adjustWorkingYield(by: 2)
    XCTAssertEqual(state.workingYield, hugeDenominator)

    let hugeNumerator = RationalQuantity(numerator: Int.max, denominator: 1)
    state = RecipeScalingState(recipeYield: RecipeYield(
      quantity: QuantityExpression(kind: .exact, lowerBound: hugeNumerator),
      originalText: "huge"
    ))
    state.adjustWorkingYield(by: 1)
    XCTAssertEqual(state.workingYield, hugeNumerator)
  }

  func testExplicitSessionScaleRestoresItsRangeBasisAndWorkingYield() {
    let recipeYield = RecipeYield(
      quantity: QuantityExpression(
        kind: .range,
        lowerBound: RationalQuantity(numerator: 2),
        upperBound: RationalQuantity(numerator: 4)
      ),
      unitText: "servings",
      originalText: "2 to 4 servings"
    )

    let state = RecipeScalingState(
      recipeYield: recipeYield,
      workingYield: RationalQuantity(numerator: 6),
      exactScale: RationalQuantity(numerator: 3, denominator: 2)
    )

    XCTAssertEqual(state.selectedBasisIndex, 1)
    XCTAssertEqual(state.workingYield, RationalQuantity(numerator: 6))
    XCTAssertEqual(state.scale?.multiplier, RationalQuantity(numerator: 3, denominator: 2))
  }

  func testInvalidExplicitSessionScaleFallsBackToSnapshotBasis() {
    let recipeYield = RecipeYield(
      quantity: QuantityExpression(
        kind: .exact,
        lowerBound: RationalQuantity(numerator: 2)
      ),
      unitText: "servings",
      originalText: "2 servings"
    )

    let state = RecipeScalingState(
      recipeYield: recipeYield,
      workingYield: RationalQuantity(numerator: 6),
      exactScale: RationalQuantity(numerator: 2)
    )

    XCTAssertEqual(state.selectedBasisIndex, 0)
    XCTAssertEqual(state.workingYield, RationalQuantity(numerator: 2))
    XCTAssertEqual(state.scale?.multiplier, RationalQuantity(numerator: 1))
  }
}
