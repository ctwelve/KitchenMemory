// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

/// An absolute factor applied to the immutable snapshot, with an explicit numeric basis.
struct CookingSessionScaleSelection: Equatable {
  let recipeYield: RecipeYield?
  private(set) var selectedBasisIndex = 0
  private(set) var factor = RationalQuantity(numerator: 1)

  init(session: CookingSessionProjection) {
    recipeYield = session.snapshot.baseYield
    if let saved = session.workingScale?.exactScale?.normalized, saved.numerator > 0 {
      factor = saved
    }
    if let working = session.workingScale?.workingYield?.quantity?.lowerBound,
       let index = bases.firstIndex(where: {
         RecipeScale(baseYield: $0.quantity, workingYield: working)?.multiplier == factor
       }) {
      selectedBasisIndex = index
    }
  }

  var bases: [RecipeYieldBasis] { recipeYield?.scalingBases ?? [] }

  var scale: RecipeScale? {
    let base = bases.indices.contains(selectedBasisIndex)
      ? bases[selectedBasisIndex].quantity : RationalQuantity(numerator: 1)
    guard let working = base.multiplied(by: factor) else { return nil }
    return RecipeScale(baseYield: base, workingYield: working)
  }

  mutating func selectBasis(_ index: Int) {
    guard bases.indices.contains(index) else { return }
    selectedBasisIndex = index
  }

  mutating func selectFactor(_ value: RationalQuantity) {
    guard let normalized = value.normalized, normalized.numerator > 0 else { return }
    factor = normalized
  }

  func displayedYield(locale: Locale) -> String {
    guard !bases.isEmpty else { return factorLabel(locale: locale) }
    return RecipeScalingState(recipeYield: recipeYield,
      workingYield: scale?.workingYield, exactScale: factor).displayedYield(locale: locale)
  }

  func basisLabel(_ basis: RecipeYieldBasis, locale: Locale) -> String {
    RecipeScalingState(recipeYield: recipeYield).basisLabel(basis, locale: locale)
  }

  func factorLabel(locale: Locale) -> String {
    RecipePresentationFormatter(locale: locale).rational(factor) + "×"
  }
}

/// Guidance comes only from retained structured content and the existing scaling rules.
struct CookingSessionScalingGuidance {
  let session: CookingSessionProjection

  private var selection: CookingSessionScaleSelection { .init(session: session) }
  var isNonOriginal: Bool { selection.factor != RationalQuantity(numerator: 1) }
  var missingYield: Bool { selection.bases.isEmpty }
  var hasMethod: Bool { !session.snapshot.instructionSections.flatMap(\.steps).isEmpty }
  var hasTime: Bool {
    session.snapshot.prepDuration != nil || session.snapshot.cookDuration != nil
      || session.snapshot.totalDuration != nil
      || session.snapshot.instructionSections.flatMap(\.steps).contains { $0.value.duration != nil }
  }
  var hasTemperature: Bool {
    session.snapshot.instructionSections.flatMap(\.steps).contains { $0.value.temperature != nil }
  }
  var warrantsExplanation: Bool {
    isNonOriginal && (missingYield || hasMethod || hasTime || hasTemperature
      || session.snapshot.ingredientSections.flatMap(\.ingredients).contains {
        ingredientStatus(for: $0) != .scaled
      })
  }

  func ingredientStatus(for ingredient: SessionIngredient) -> ScaledRecipeIngredient.Status {
    guard let scale = selection.scale else { return .unchangedArithmeticFailure }
    return ingredient.value.scaled(using: scale).status
  }
}

extension CookingSessionPresentationModel {
  func scalingExplanationIsVisible(in session: CookingSessionProjection) -> Bool {
    CookingSessionScalingGuidance(session: session).warrantsExplanation
      && readingPreference(for: session).hasDismissedScalingExplanation != true
  }

  func dismissScalingExplanation(in session: CookingSessionProjection) {
    guard CookingSessionScalingGuidance(session: session).warrantsExplanation else { return }
    var preference = readingPreference(for: session)
    preference.hasDismissedScalingExplanation = true
    saveReadingPreference(preference)
  }
}
