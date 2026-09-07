// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class GermanLocalizationTests: XCTestCase {
  func testCompiledGermanResourcesDoNotFallBackToEnglish() throws {
    let locale = Locale(identifier: "de-DE")
    XCTAssertEqual(LocalizedStringResource.organizationTitle.localized(for: locale), "Organisation")
    XCTAssertTrue(LocalizedStringResource.recoveryWaitingMessage.localized(for: locale).contains("Synchronisierung"))
    let bundle = SampleRecipeCatalog.resourceBundle
    XCTAssertTrue(bundle.localizations.contains("de-DE"))
    let credits = try XCTUnwrap(bundle.url(
      forResource: "Credits", withExtension: "rtf", subdirectory: nil, localization: "de-DE"))
    XCTAssertTrue(credits.path.contains("de-DE.lproj"))
    XCTAssertTrue(try String(contentsOf: credits, encoding: .utf8).contains("Lizenzinformationen"))
  }

  func testGermanAuthoredVariantsPreserveAmountsAndCookingConditions() throws {
    let manifest = try SampleRecipeCatalog.loadManifest()
    for family in manifest.recipes {
      let german = try SampleRecipeCatalog.loadRecipe(XCTUnwrap(family.variant(preferredLanguages: ["de-DE"])))
      let american = try SampleRecipeCatalog.loadRecipe(XCTUnwrap(family.variant(preferredLanguages: ["en-US"])))
      XCTAssertNotEqual(german.recipeID, american.recipeID)
      XCTAssertEqual(german.revision.contentLanguage?.rawValue, "de-DE")
      let ingredients = german.revision.ingredientSections.flatMap(\.ingredients)
      let sourceIngredients = american.revision.ingredientSections.flatMap(\.ingredients)
      XCTAssertEqual(ingredients.map { $0.quantity?.kind }, sourceIngredients.map { $0.quantity?.kind })
      XCTAssertEqual(ingredients.map { $0.quantity?.lowerBound }, sourceIngredients.map { $0.quantity?.lowerBound })
      XCTAssertEqual(ingredients.map { $0.quantity?.upperBound }, sourceIngredients.map { $0.quantity?.upperBound })
      XCTAssertEqual(ingredients.map { $0.package?.quantity }, sourceIngredients.map { $0.package?.quantity })
      XCTAssertEqual(ingredients.map(\.isOptional), sourceIngredients.map(\.isOptional))
      let steps = german.revision.instructionSections.flatMap(\.steps)
      let sourceSteps = american.revision.instructionSections.flatMap(\.steps)
      XCTAssertEqual(steps.map(\.temperature), sourceSteps.map(\.temperature))
      XCTAssertEqual(steps.map(\.duration), sourceSteps.map(\.duration))
      XCTAssertEqual(german.revision.source?.canonicalURL, american.revision.source?.canonicalURL)
    }
  }
}
