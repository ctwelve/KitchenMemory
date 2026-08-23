// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryLogic
import KitchenMemoryDomain
import XCTest

final class RecipeScalingStatePropertyTests: XCTestCase {
  func testSeededAdjustmentSequencesStayWithinHonestYieldBounds() throws {
    let seed = try PropertyTestSeeds.bundled().seed(named: .logicScalingAdjustments)
    var generator = SeededGenerator(seed: seed.value)

    for iteration in 0..<512 {
      let denominator = generator.int(in: 1...12)
      let initialWholeYield = generator.int(in: 1...30)
      let initial = RationalQuantity(
        numerator: initialWholeYield * denominator,
        denominator: denominator
      )
      var state = RecipeScalingState(recipeYield: RecipeYield(
        quantity: QuantityExpression(kind: .exact, lowerBound: initial),
        originalText: "Seeded yield"
      ))

      for adjustmentIndex in 0..<64 {
        state.adjustWorkingYield(by: generator.int(in: -20...20))
        let working = try XCTUnwrap(state.workingYield)
        let context = [
          "seed=\(seed.hexadecimal)", "case=\(iteration)",
          "adjustment=\(adjustmentIndex)", "working=\(working)",
        ].joined(separator: " ")

        XCTAssertEqual(working, working.normalized, context)
        XCTAssertGreaterThan(working.numerator, 0, context)
        XCTAssertLessThanOrEqual(
          working.numerator,
          working.denominator * 999,
          context
        )
        XCTAssertNotNil(state.scale, context)
      }

      state.resetWorkingYield()
      XCTAssertEqual(state.workingYield, initial.normalized)
    }
  }
}
