// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenKit
import Foundation
import XCTest

final class RecipeEditSessionTests: XCTestCase {
  func testRichDraftRoundTripsThroughPresentationNeutralState() throws {
    let capture = RecipeSourceCapture(
      kind: .schemaOrgJSONLD,
      sourceURL: URL(string: "https://example.com")!,
      capturedAt: Date(timeIntervalSince1970: 12),
      mediaType: "application/ld+json",
      payload: Data("{}".utf8),
      blockIndex: 0,
      objectIndex: 0
    )
    let draft = RecipeDraft(
      title: "Soup",
      summary: "Summary",
      authorName: "Cook",
      contentLanguage: RecipeContentLanguage(rawValue: "fr-CA"),
      source: RecipeSource(
        kind: .book,
        title: "Book",
        authorName: "Writer",
        publisherName: "Press",
        canonicalURL: URL(string: "https://example.com/soup")
      ),
      sourceCapture: capture,
      recipeYield: RecipeYield(
        quantity: QuantityExpression(
          kind: .exact,
          lowerBound: RationalQuantity(numerator: 4)
        ),
        unitText: " servings ",
        originalText: " Serves four "
      ),
      prepDuration: RecipeDuration(seconds: 600),
      cookDuration: RecipeDuration(seconds: 1_200),
      totalDuration: RecipeDuration(seconds: 1_800),
      cuisines: ["French"],
      categories: ["Dinner"],
      keywords: ["warm"],
      ingredientSections: [IngredientSection(title: "Main", ingredients: [])],
      instructionSections: [InstructionSection(title: "Cook", steps: [])]
    )

    let result = try RecipeEditSession(draft: draft).validatedDraft()

    XCTAssertEqual(result.sourceCapture, capture)
    XCTAssertEqual(result.contentLanguage?.rawValue, "fr-CA")
    XCTAssertEqual(result.recipeYield?.unitText, "servings")
    XCTAssertEqual(result.recipeYield?.originalText, "Serves four")
    XCTAssertEqual(result.prepDuration?.seconds, 600)
    XCTAssertEqual(result.cookDuration?.seconds, 1_200)
    XCTAssertEqual(result.totalDuration?.seconds, 1_800)
    XCTAssertEqual([result.cuisines, result.categories, result.keywords], [["French"], ["Dinner"], ["warm"]])
    XCTAssertEqual(result.source?.publisherName, "Press")
  }

  func testValidationReportsEveryInvalidFieldWithoutDroppingInput() {
    var session = RecipeEditSession()
    session.title = " \n "
    session.prepMinutes = "soon"
    session.cookMinutes = "-1"
    session.totalMinutes = String(RecipeEditSession.maximumDurationMinutes + 1)
    session.sourceURL = "file:///soup"

    let expected: Set<RecipeEditValidationIssue> = [
      .missingTitle,
      .invalidDuration(.preparation),
      .invalidDuration(.cooking),
      .invalidDuration(.total),
      .invalidSourceURL,
    ]
    XCTAssertEqual(session.validationIssues, expected)
    XCTAssertFalse(session.canSave)
    XCTAssertThrowsError(try session.validatedDraft()) { error in
      XCTAssertEqual(error as? RecipeEditSessionError, .invalid(expected))
    }
  }

  func testYieldFallbackEmptySourceAndSectionMovesAreDeterministic() throws {
    var session = RecipeEditSession()
    session.title = " Soup "
    session.recipeYield = RecipeYield(
      quantity: QuantityExpression(
        kind: .exact,
        lowerBound: RationalQuantity(numerator: 3)
      ),
      unitText: " bowls ",
      originalText: " "
    )
    session.ingredientSections = [
      IngredientSection(title: "First", ingredients: []),
      IngredientSection(title: "Second", ingredients: []),
    ]
    session.instructionSections = [
      InstructionSection(title: "First", steps: []),
      InstructionSection(title: "Second", steps: []),
    ]

    session.moveIngredientSection(at: 0, by: 1)
    session.moveIngredientSection(at: 0, by: -1)
    session.moveInstructionSection(at: 1, by: -1)
    session.moveInstructionSection(at: 9, by: 1)
    let result = try session.validatedDraft()

    XCTAssertEqual(session.ingredientSections.map(\.title), ["Second", "First"])
    XCTAssertEqual(session.instructionSections.map(\.title), ["Second", "First"])
    XCTAssertEqual(result.title, " Soup ")
    XCTAssertEqual(result.recipeYield?.originalText, "")
    XCTAssertEqual(result.recipeYield?.unitText, "bowls")
    XCTAssertNil(result.source)
    XCTAssertNil(result.prepDuration)
  }

  func testYieldWithoutMeaningfulTextOrQuantityIsRemoved() throws {
    var session = RecipeEditSession()
    session.title = "Soup"
    session.recipeYield = RecipeYield(unitText: " bowls ", originalText: " ")
    session.prepMinutes = "0"

    let result = try session.validatedDraft()

    XCTAssertNil(result.recipeYield)
    XCTAssertEqual(result.prepDuration?.seconds, 0)
  }
}
