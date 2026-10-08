// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class CookingSessionScalingPresentationTests: XCTestCase {
  func testPresetsAndCustomFactorsAreAbsoluteAndRestoreRetainedRangeBasis() throws {
    let yield = RecipeYield(quantity: .init(kind: .range,
      lowerBound: .init(numerator: 2), upperBound: .init(numerator: 4)),
      unitText: "servings", originalText: "2–4 servings")
    let session = CookingSessionProjection(id: CookingSession.ID(),
      snapshot: .init(title: "Soup", baseYield: yield),
      workingScale: .init(workingYield: .init(quantity: .init(kind: .exact,
        lowerBound: .init(numerator: 6)), unitText: "servings", originalText: yield.originalText),
        exactScale: .init(numerator: 3, denominator: 2), quantities: []))
    var selection = CookingSessionScaleSelection(session: session)
    XCTAssertEqual(selection.selectedBasisIndex, 1)
    let factors = [RationalQuantity(numerator: 1, denominator: 2), .init(numerator: 1),
      .init(numerator: 3, denominator: 2), .init(numerator: 2), ]
    for factor in factors {
      selection.selectFactor(factor)
      selection.selectFactor(factor)
      XCTAssertEqual(selection.scale?.multiplier, factor)
      XCTAssertEqual(selection.scale?.baseYield, .init(numerator: 4))
    }
    selection.selectBasis(0)
    XCTAssertEqual(selection.factor, .init(numerator: 2))
    XCTAssertEqual(selection.scale?.workingYield, .init(numerator: 4))
    selection.selectFactor(.init(numerator: 10, denominator: 4))
    XCTAssertEqual(selection.factor, .init(numerator: 5, denominator: 2))
    XCTAssertEqual(selection.scale?.workingYield, .init(numerator: 5))
    selection.selectFactor(.init(numerator: 0))
    selection.selectFactor(.init(numerator: -2))
    selection.selectFactor(.init(numerator: 1, denominator: 0))
    selection.selectBasis(99)
    XCTAssertEqual(selection.factor, .init(numerator: 5, denominator: 2))
    XCTAssertEqual(selection.selectedBasisIndex, 0)
    XCTAssertEqual(session.snapshot.baseYield, yield)
  }

  func testMissingOrTextualYieldOffersFactorOnlyWithoutIngredientUncertainty() throws {
    for yield in [nil, RecipeYield(originalText: "one pot"),
      RecipeYield(quantity: .init(kind: .exact, lowerBound: .init(numerator: 0)), originalText: "unknown"), ] {
      let ingredient = scalingIngredient(quantity: .init(kind: .exact, lowerBound: .init(numerator: 1)))
      let session = scalingSession(yield: yield, ingredients: [ingredient], factor: .init(numerator: 2))
      let selection = CookingSessionScaleSelection(session: session)
      let guidance = CookingSessionScalingGuidance(session: session)
      XCTAssertTrue(selection.bases.isEmpty)
      XCTAssertEqual(selection.scale?.baseYield, .init(numerator: 1))
      XCTAssertEqual(selection.scale?.multiplier, .init(numerator: 2))
      XCTAssertEqual(selection.displayedYield(locale: Locale(identifier: "en_US")), "2×")
      XCTAssertTrue(guidance.missingYield)
      XCTAssertEqual(guidance.ingredientStatus(for: ingredient), .scaled)
      XCTAssertTrue(guidance.warrantsExplanation)
      XCTAssertFalse(guidance.hasMethod)
    }
  }

  func testIngredientGuidanceUsesRetainedScalingPoliciesAndPreservesQuantityKinds() throws {
    let expressions: [QuantityExpression?] = [
      .init(kind: .exact, lowerBound: .init(numerator: 1)),
      .init(kind: .approximate, lowerBound: .init(numerator: 1)),
      .init(kind: .range, lowerBound: .init(numerator: 1), upperBound: .init(numerator: 2)),
      .init(kind: .text, text: "to taste"), .init(kind: .none), nil,
    ]
    let expected: [ScaledRecipeIngredient.Status] = [.scaled, .scaled, .scaled,
      .unchangedText, .unchangedText, .unchangedWithoutQuantity, ]
    for (quantity, status) in zip(expressions, expected) {
      let ingredient = scalingIngredient(quantity: quantity)
      let session = scalingSession(ingredients: [ingredient], factor: .init(numerator: 2))
      let guidance = CookingSessionScalingGuidance(session: session)
      XCTAssertEqual(guidance.ingredientStatus(for: ingredient), status)
      let scaled = ingredient.value.scaled(using: try XCTUnwrap(CookingSessionScaleSelection(session: session).scale))
      XCTAssertEqual(scaled.ingredient.quantity?.kind, quantity?.kind)
      if quantity?.kind == .range {
        XCTAssertEqual(scaled.ingredient.quantity?.lowerBound, .init(numerator: 2))
        XCTAssertEqual(scaled.ingredient.quantity?.upperBound, .init(numerator: 4))
      }
      XCTAssertEqual(session.snapshot.ingredientSections.first?.ingredients.first, ingredient)
    }
    for (policy, status) in [(RecipeIngredient.ScalingBehavior.fixed, ScaledRecipeIngredient.Status.unchangedFixed),
      (.manualReview, .unchangedManualReview), ] {
      let ingredient = scalingIngredient(quantity: .init(kind: .exact, lowerBound: .init(numerator: 1)), policy: policy)
      XCTAssertEqual(CookingSessionScalingGuidance(session: scalingSession(ingredients: [ingredient],
        factor: .init(numerator: 2))).ingredientStatus(for: ingredient), status)
    }
    var custom = scalingIngredient(quantity: .init(kind: .exact, lowerBound: .init(numerator: 1)))
    custom.value.presentationMode = .custom
    custom.value.customDisplayText = "a handful"
    XCTAssertEqual(CookingSessionScalingGuidance(session: scalingSession(ingredients: [custom],
      factor: .init(numerator: 2))).ingredientStatus(for: custom), .unchangedPresentationOverride)
  }

  func testCulinaryConditionsStayAuthoredAndGuidanceDoesNotParseProse() {
    let step = SessionInstruction(sourceInstructionID: nil, value: .init(text: "Bake gently",
      duration: .init(seconds: 600), temperature: .init(value: .init(numerator: 180), unit: .celsius)))
    let session = scalingSession(instructions: [step], factor: .init(numerator: 2))
    let guidance = CookingSessionScalingGuidance(session: session)
    XCTAssertTrue(guidance.hasMethod)
    XCTAssertTrue(guidance.hasTime)
    XCTAssertTrue(guidance.hasTemperature)
    XCTAssertTrue(guidance.warrantsExplanation)
    XCTAssertEqual(session.snapshot.instructionSections.first?.steps.first, step)
    let proseSession = scalingSession(instructions: [.init(sourceInstructionID: nil,
      value: .init(text: "Bake at 180 degrees for ten minutes")), ], factor: .init(numerator: 2))
    let prose = CookingSessionScalingGuidance(session: proseSession)
    XCTAssertTrue(prose.hasMethod)
    XCTAssertFalse(prose.hasTime)
    XCTAssertFalse(prose.hasTemperature)
  }

  func testExplanationDismissalSurvivesRelaunchAndDoesNotLeakToAnotherSession() throws {
    let session = scalingSession(factor: .init(numerator: 2))
    let defaults = try makeTestUserDefaults(suiteNamePrefix: "ScalingExplanation").defaults
    let service = ScalingPresentationService(session: session)
    let model = CookingSessionPresentationModel(sessions: service,
      store: DefaultsCookingSessionPresentationStore(defaults: defaults))
    XCTAssertTrue(model.scalingExplanationIsVisible(in: session))
    model.dismissScalingExplanation(in: session)
    let reopened = CookingSessionPresentationModel(sessions: service,
      store: DefaultsCookingSessionPresentationStore(defaults: defaults))
    XCTAssertFalse(reopened.scalingExplanationIsVisible(in: session))
    let changedPreset = CookingSessionProjection(id: session.id, snapshot: session.snapshot,
      workingScale: .init(workingYield: nil, exactScale: .init(numerator: 3), quantities: []))
    XCTAssertFalse(reopened.scalingExplanationIsVisible(in: changedPreset))
    XCTAssertTrue(reopened.scalingExplanationIsVisible(in: scalingSession(factor: .init(numerator: 2))))
    XCTAssertTrue(reopened.pendingCommands.isEmpty)
    XCTAssertTrue(try XCTUnwrap(reopened.readingPreference(for: session).hasDismissedScalingExplanation))
  }

  func testExplanationOnlyAppearsForApplicableNonOriginalConditions() {
    let ingredient = scalingIngredient(quantity: .init(kind: .exact, lowerBound: .init(numerator: 1)))
    let numericYield = RecipeYield(quantity: .init(kind: .exact, lowerBound: .init(numerator: 2)),
      originalText: "2 servings")
    let exactOnly = scalingSession(yield: numericYield, ingredients: [ingredient], factor: .init(numerator: 2))
    XCTAssertFalse(CookingSessionScalingGuidance(session: exactOnly).warrantsExplanation)
    let original = scalingSession(factor: .init(numerator: 1))
    XCTAssertFalse(CookingSessionScalingGuidance(session: original).warrantsExplanation)
    let model = CookingSessionPresentationModel(sessions: ScalingPresentationService(session: original),
      store: VolatileCookingSessionPresentationStore())
    model.dismissScalingExplanation(in: original)
    XCTAssertNil(model.readingPreference(for: original).hasDismissedScalingExplanation)
    XCTAssertFalse(model.scalingExplanationIsVisible(in: original))
  }

  func testLegacyReadingPreferenceWithoutDismissalStillRestoresPositionAndAwakeChoice() throws {
    let sessionID = CookingSession.ID()
    let stepID = SessionInstruction.ID()
    let old = LegacyScalingReadingPreference(sessionID: sessionID, emphasizedInstructionID: stepID,
      position: .init(instructionID: stepID, offset: 37), keepsScreenAwake: false)
    let defaults = try makeTestUserDefaults(suiteNamePrefix: "LegacyScalingExplanation").defaults
    defaults.set(
      try PropertyListEncoder().encode([old]),
      forKey: DefaultsCookingSessionPresentationStore.readingPreferencesKey
    )
    let restored = try XCTUnwrap(DefaultsCookingSessionPresentationStore(defaults: defaults).readingPreferences.first)
    XCTAssertEqual(restored.sessionID, sessionID)
    XCTAssertEqual(restored.emphasizedInstructionID, stepID)
    XCTAssertEqual(restored.position, old.position)
    XCTAssertFalse(restored.keepsScreenAwake)
    XCTAssertNil(restored.hasDismissedScalingExplanation)
  }
}

private func scalingIngredient(
  quantity: QuantityExpression?,
  policy: RecipeIngredient.ScalingBehavior = .linear
) -> SessionIngredient {
  SessionIngredient(sourceIngredientID: nil, value: RecipeIngredient(originalText: "broth", quantity: quantity,
    ingredientText: "broth", scalingBehavior: policy, parseState: .reviewed))
}

private func scalingSession(
  yield: RecipeYield? = nil,
  ingredients: [SessionIngredient] = [],
  instructions: [SessionInstruction] = [],
  factor: RationalQuantity
) -> CookingSessionProjection {
  CookingSessionProjection(id: CookingSession.ID(), snapshot: .init(title: "Soup", baseYield: yield,
    ingredientSections: [.init(title: nil, ingredients: ingredients)],
    instructionSections: [.init(title: nil, steps: instructions)]),
    workingScale: .init(workingYield: nil, exactScale: factor, quantities: []))
}

private struct LegacyScalingReadingPreference: Codable {
  let sessionID: CookingSession.ID
  let emphasizedInstructionID: SessionInstruction.ID?
  let position: CookingSessionReadingPosition?
  let keepsScreenAwake: Bool
}

@MainActor
private final class ScalingPresentationService: CookingSessionServing {
  let session: CookingSessionProjection
  init(session: CookingSessionProjection) { self.session = session }
  func sessions() -> [SessionProjectionResult] { [.session(session)] }
  func history() -> CookingSessionHistoryRead {
    fixtureHistoryRead(sessions: [.session(session)], sessionIDsByRecipe: [:])
  }
  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    _ = recipeID
    throw CookingSessionTestSupportError.unsupportedRead("sessions(for:)")
  }
  func unresolvedDeletionIDs(for sessionID: CookingSession.ID) throws -> [SessionDeletion.ID] {
    _ = sessionID
    throw CookingSessionTestSupportError.unsupportedRead("unresolvedDeletionIDs(for:)")
  }
  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.sessionWriteFailed
  }
  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.sessionWriteFailed
  }
}
