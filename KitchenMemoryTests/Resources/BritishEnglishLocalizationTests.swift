// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class BritishEnglishLocalizationTests: XCTestCase {
  func testCompiledBritishResourcesDoNotFallBackToAmericanSpelling() throws {
    let locale = Locale(identifier: "en-GB")
    XCTAssertEqual(LocalizedStringResource.organizationTitle.localized(for: locale), "Organisation")
    XCTAssertTrue(LocalizedStringResource.recoveryWaitingMessage.localized(for: locale).contains("synchronisation"))
    let bundle = SampleRecipeCatalog.resourceBundle
    XCTAssertTrue(bundle.localizations.contains("en-GB"))
    let credits = try XCTUnwrap(bundle.url(
      forResource: "Credits", withExtension: "rtf", subdirectory: nil, localization: "en-GB"))
    XCTAssertTrue(credits.path.contains("en-GB.lproj"))
    XCTAssertTrue(try String(contentsOf: credits, encoding: .utf8).contains("licence information"))
  }

  func testBritishAuthoredVariantsPreserveAmountsAndCookingConditions() throws {
    let manifest = try SampleRecipeCatalog.loadManifest()
    for family in manifest.recipes {
      let british = try SampleRecipeCatalog.loadRecipe(XCTUnwrap(family.variant(preferredLanguages: ["en-GB"])))
      let american = try SampleRecipeCatalog.loadRecipe(XCTUnwrap(family.variant(preferredLanguages: ["en-US"])))
      XCTAssertNotEqual(british.recipeID, american.recipeID)
      XCTAssertEqual(british.revision.contentLanguage?.rawValue, "en-GB")
      let ingredients = british.revision.ingredientSections.flatMap(\.ingredients)
      let sourceIngredients = american.revision.ingredientSections.flatMap(\.ingredients)
      XCTAssertEqual(ingredients.map(\.quantity), sourceIngredients.map(\.quantity))
      XCTAssertEqual(ingredients.map { $0.package?.quantity }, sourceIngredients.map { $0.package?.quantity })
      XCTAssertEqual(ingredients.map(\.isOptional), sourceIngredients.map(\.isOptional))
      let steps = british.revision.instructionSections.flatMap(\.steps)
      let sourceSteps = american.revision.instructionSections.flatMap(\.steps)
      XCTAssertEqual(steps.map(\.temperature), sourceSteps.map(\.temperature))
      XCTAssertEqual(steps.map(\.duration), sourceSteps.map(\.duration))
      XCTAssertEqual(british.revision.source?.canonicalURL, american.revision.source?.canonicalURL)
    }
  }
}
