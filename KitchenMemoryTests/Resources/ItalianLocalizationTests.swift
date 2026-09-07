// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class ItalianLocalizationTests: XCTestCase {
  func testCompiledItalianResourcesDoNotFallBackToEnglish() throws {
    let locale = Locale(identifier: "it-IT")
    XCTAssertEqual(LocalizedStringResource.organizationTitle.localized(for: locale), "Organizzazione")
    XCTAssertTrue(LocalizedStringResource.recoveryWaitingMessage.localized(for: locale).contains("sincronizzazione"))
    let bundle = SampleRecipeCatalog.resourceBundle
    XCTAssertTrue(bundle.localizations.contains("it-IT"))
    let credits = try XCTUnwrap(bundle.url(
      forResource: "Credits", withExtension: "rtf", subdirectory: nil, localization: "it-IT"))
    XCTAssertTrue(credits.path.contains("it-IT.lproj"))
    XCTAssertTrue(try String(contentsOf: credits, encoding: .utf8).contains("informazioni sulla licenza"))
  }

  func testItalianAuthoredVariantsPreserveAmountsAndCookingConditions() throws {
    let manifest = try SampleRecipeCatalog.loadManifest()
    for family in manifest.recipes {
      let italian = try SampleRecipeCatalog.loadRecipe(XCTUnwrap(family.variant(preferredLanguages: ["it-IT"])))
      let american = try SampleRecipeCatalog.loadRecipe(XCTUnwrap(family.variant(preferredLanguages: ["en-US"])))
      XCTAssertNotEqual(italian.recipeID, american.recipeID)
      XCTAssertEqual(italian.revision.contentLanguage?.rawValue, "it-IT")
      let ingredients = italian.revision.ingredientSections.flatMap(\.ingredients)
      let sourceIngredients = american.revision.ingredientSections.flatMap(\.ingredients)
      XCTAssertEqual(ingredients.map { $0.quantity?.kind }, sourceIngredients.map { $0.quantity?.kind })
      XCTAssertEqual(ingredients.map { $0.quantity?.lowerBound }, sourceIngredients.map { $0.quantity?.lowerBound })
      XCTAssertEqual(ingredients.map { $0.quantity?.upperBound }, sourceIngredients.map { $0.quantity?.upperBound })
      XCTAssertEqual(ingredients.map { $0.package?.quantity }, sourceIngredients.map { $0.package?.quantity })
      XCTAssertEqual(ingredients.map(\.isOptional), sourceIngredients.map(\.isOptional))
      let steps = italian.revision.instructionSections.flatMap(\.steps)
      let sourceSteps = american.revision.instructionSections.flatMap(\.steps)
      XCTAssertEqual(steps.map(\.temperature), sourceSteps.map(\.temperature))
      XCTAssertEqual(steps.map(\.duration), sourceSteps.map(\.duration))
      XCTAssertEqual(italian.revision.source?.canonicalURL, american.revision.source?.canonicalURL)
    }
  }
}
