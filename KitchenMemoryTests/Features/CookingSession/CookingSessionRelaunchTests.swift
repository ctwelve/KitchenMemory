// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class CookingSessionRelaunchTests: XCTestCase {
  func testRelaunchRestoresRetainedProgressAndWorkingScale() throws {
    let store = VolatileCookingSessionPresentationStore()
    let preparedApp = try AppRuntime.testing(.init(
      library: .installed,
      sessionPresentationStore: store
    ))
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first(where: {
      $0.revision.recipeYield?.scalingBases.isEmpty == false
    }))
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let session = try XCTUnwrap(preparedApp.sessionModel.currentSession)
    let ingredientID = try XCTUnwrap(
      session.snapshot.ingredientSections.first?.ingredients.first?.id
    )
    let instructionID = try XCTUnwrap(
      session.snapshot.instructionSections.first?.steps.first?.id
    )
    let base = try XCTUnwrap(session.snapshot.baseYield?.scalingBases.first?.quantity.normalized)
    let workingYield = RationalQuantity(
      numerator: base.numerator + base.denominator,
      denominator: base.denominator
    )
    let scale = try XCTUnwrap(RecipeScale(baseYield: base, workingYield: workingYield))

    XCTAssertTrue(preparedApp.sessionModel.setIngredient(ingredientID, to: .accounted))
    XCTAssertTrue(preparedApp.sessionModel.setInstruction(instructionID, to: .completed))
    XCTAssertTrue(preparedApp.sessionModel.replaceWorkingScale(with: scale))

    let relaunched = CookingSessionPresentationModel(
      sessions: preparedApp.cookingSessions,
      store: store
    )
    relaunched.loadIfNeeded()

    XCTAssertEqual(Set(try XCTUnwrap(relaunched.currentSession).progress), [
      SessionProgress(target: .ingredient(ingredientID), state: .ingredient(.accounted)),
      SessionProgress(target: .instruction(instructionID), state: .instruction(.completed)),
    ])
    XCTAssertEqual(relaunched.currentSession?.workingScale?.exactScale, scale.multiplier)
  }
}
