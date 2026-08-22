// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryPersistence
import Foundation
import KitchenMemoryDomain
import SwiftData
import XCTest

// These tests seed only valid domain values, then corrupt V1 rows directly.
// That isolates the defensive read boundary a migration or damaged store would
// cross without weakening normal domain construction to manufacture bad data.
@MainActor
final class SwiftDataRecipeRepositoryCorruptionTests: XCTestCase {
  func testMissingCurrentRevisionIsReportedInsteadOfHidingTheRecipe() throws {
    let fixture = try makeFixture()
    let context = ModelContext(fixture.container)
    let revision = try XCTUnwrap(context.fetch(FetchDescriptor<RecipeRevisionRecord>()).first)
    context.delete(revision)
    try context.save()

    XCTAssertThrowsError(try fixture.reader().recipe(id: fixture.recipeID)) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .missingCurrentRevision)
    }
  }

  func testCurrentRevisionOwnedByAnotherRecipeIsReportedAsCorruption() throws {
    let fixture = try makeFixture()
    let context = ModelContext(fixture.container)
    let revision = try XCTUnwrap(context.fetch(FetchDescriptor<RecipeRevisionRecord>()).first)
    let revisionID = RecipeRevision.ID(rawValue: revision.id)
    revision.recipeID = Recipe.ID().rawValue
    try context.save()

    XCTAssertThrowsError(try fixture.reader().recipe(id: fixture.recipeID)) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .inconsistentStoredRecipeIdentity(
          recipeID: fixture.recipeID,
          revisionID: revisionID
        )
      )
    }
  }

  func testUnknownMediaRoleReportsItsExactField() throws {
    let fixture = try makeFixture()
    let context = ModelContext(fixture.container)
    let media = try XCTUnwrap(context.fetch(FetchDescriptor<RecipeMediaRecord>()).first)
    media.role = "future-role"
    try context.save()

    assertReading(fixture, throwsFor: "media.role")
  }

  func testUnknownIngredientEnumsReportTheirExactFields() throws {
    let corruptions: [(field: String, mutate: (RecipeIngredientRecord) -> Void)] = [
      ("ingredient.presentationMode", { $0.presentationMode = "future-mode" }),
      ("ingredient.scalingBehavior", { $0.scalingBehavior = "future-scaling" }),
      ("ingredient.parseState", { $0.parseState = "future-state" }),
    ]

    for corruption in corruptions {
      let fixture = try makeFixture()
      let context = ModelContext(fixture.container)
      let ingredient = try XCTUnwrap(
        context.fetch(FetchDescriptor<RecipeIngredientRecord>()).first
      )
      corruption.mutate(ingredient)
      try context.save()

      assertReading(fixture, throwsFor: corruption.field)
    }
  }

  func testMalformedEncodedValuesReportTheOwningField() throws {
    let corruptions: [(field: String, mutate: (RecipeRevisionRecord) -> Void)] = [
      ("revision.source", { $0.sourceData = Data("not-json".utf8) }),
      ("revision.yield", { $0.yieldData = Data("not-json".utf8) }),
      ("revision.cuisines", { $0.cuisinesData = Data("not-json".utf8) }),
      ("revision.categories", { $0.categoriesData = Data("not-json".utf8) }),
      ("revision.keywords", { $0.keywordsData = Data("not-json".utf8) }),
    ]

    for corruption in corruptions {
      let fixture = try makeFixture()
      let context = ModelContext(fixture.container)
      let revision = try XCTUnwrap(context.fetch(FetchDescriptor<RecipeRevisionRecord>()).first)
      corruption.mutate(revision)
      try context.save()

      assertReading(fixture, throwsFor: corruption.field)
    }
  }

  func testMalformedChildValuesReportTheOwningField() throws {
    let equipmentFixture = try makeFixture()
    let equipmentContext = ModelContext(equipmentFixture.container)
    let equipment = try XCTUnwrap(
      equipmentContext.fetch(FetchDescriptor<EquipmentRecord>()).first
    )
    equipment.quantityData = Data("not-json".utf8)
    try equipmentContext.save()
    assertReading(equipmentFixture, throwsFor: "equipment.quantity")

    let ingredientFixture = try makeFixture()
    let ingredientContext = ModelContext(ingredientFixture.container)
    let ingredient = try XCTUnwrap(
      ingredientContext.fetch(FetchDescriptor<RecipeIngredientRecord>()).first
    )
    ingredient.packageData = Data("not-json".utf8)
    try ingredientContext.save()
    assertReading(ingredientFixture, throwsFor: "ingredient.package")

    let quantityFixture = try makeFixture()
    let quantityContext = ModelContext(quantityFixture.container)
    let quantityIngredient = try XCTUnwrap(
      quantityContext.fetch(FetchDescriptor<RecipeIngredientRecord>()).first
    )
    quantityIngredient.quantityData = Data("not-json".utf8)
    try quantityContext.save()
    assertReading(quantityFixture, throwsFor: "ingredient.quantity")

    let stepFixture = try makeFixture()
    let stepContext = ModelContext(stepFixture.container)
    let step = try XCTUnwrap(
      stepContext.fetch(FetchDescriptor<InstructionStepRecord>()).first
    )
    step.temperatureData = Data("not-json".utf8)
    try stepContext.save()
    assertReading(stepFixture, throwsFor: "step.temperature")
  }

  private func assertReading(
    _ fixture: Fixture,
    throwsFor field: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(
      try fixture.reader().recipe(id: fixture.recipeID),
      file: file,
      line: line
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .invalidStoredValue(field: field),
        file: file,
        line: line
      )
    }
  }

  private func makeFixture() throws -> Fixture {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(
      recipeID: recipeID,
      revisionNumber: 1,
      title: "Stored",
      source: RecipeSource(kind: .webpage),
      recipeYield: RecipeYield(originalText: "2 servings"),
      cuisines: ["Midwestern"],
      categories: ["Dinner"],
      keywords: ["cozy"],
      media: [RecipeMedia(role: .hero, assetName: "hero")],
      equipment: [EquipmentItem(originalText: "1 pot", name: "pot")],
      ingredientSections: [
        IngredientSection(ingredients: [
          RecipeIngredient(originalText: "1 onion", presentationMode: .original),
        ]),
      ],
      instructionSections: [
        InstructionSection(steps: [InstructionStep(text: "Cook.")])
      ]
    )
    let recipe = Recipe(
      id: recipeID,
      kitchenID: kitchen.id,
      currentRevisionID: revision.id
    )
    try repository.save(kitchen)
    try repository.save(recipe: recipe, revision: revision)
    return Fixture(container: container, recipeID: recipeID)
  }
}

@MainActor
private struct Fixture {
  let container: ModelContainer
  let recipeID: Recipe.ID

  func reader() -> SwiftDataRecipeRepository {
    SwiftDataRecipeRepository(modelContainer: container)
  }
}
