// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import SwiftData
import XCTest

@MainActor
final class SwiftDataRecipeRepositoryCloudMergeTests: XCTestCase {
  // The scenario intentionally assembles one complete duplicated payload graph.
  // swiftlint:disable:next function_body_length
  func testDuplicatedPayloadWithoutAuthorityCannotWinByArrivalOrder() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    let recipeID = Recipe.ID()
    let originalRevision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "First")
    try repository.save(kitchen)
    try repository.save(
      recipe: Recipe(
        id: recipeID,
        kitchenID: kitchen.id,
        currentRevisionID: originalRevision.id
      ),
      revision: originalRevision
    )

    let lowerID = try XCTUnwrap(UUID(uuidString: "10000000-0000-0000-0000-000000000000"))
    let higherID = try XCTUnwrap(UUID(uuidString: "F0000000-0000-0000-0000-000000000000"))
    let context = ModelContext(container)
    context.insert(KitchenRecord(id: kitchen.id.rawValue, name: "Second device"))
    context.insert(
      RecipeRecord(
        id: recipeID.rawValue,
        kitchenID: kitchen.id.rawValue,
        currentRevisionID: lowerID
      )
    )
    context.insert(
      RecipeRecord(
        id: recipeID.rawValue,
        kitchenID: kitchen.id.rawValue,
        currentRevisionID: higherID
      )
    )
    context.insert(makeRevision(id: lowerID, recipeID: recipeID.rawValue, title: "Lower tie"))
    context.insert(makeRevision(id: higherID, recipeID: recipeID.rawValue, title: "Chosen"))
    insertDuplicateChildren(revisionID: higherID, into: context)
    try context.save()

    XCTAssertEqual(
      try repository.recipeAuthority(id: recipeID),
      .unavailable(.missingSave(.init(rawValue: lowerID)))
    )
    XCTAssertNil(try repository.recipe(id: recipeID))
    XCTAssertEqual(try repository.kitchens().count, 1)
    XCTAssertTrue(try repository.recipes(in: kitchen.id).isEmpty)
    let revisions = try repository.revisions(for: recipeID)
    XCTAssertEqual(revisions.count, 3)
    let duplicated = try XCTUnwrap(revisions.first { $0.id.rawValue == higherID })
    XCTAssertEqual(duplicated.media.count, 1)
    XCTAssertEqual(duplicated.equipment.count, 1)
    XCTAssertEqual(duplicated.ingredientSections.count, 1)
    XCTAssertEqual(duplicated.ingredientSections[0].ingredients.count, 1)
    XCTAssertEqual(duplicated.instructionSections.count, 1)
    XCTAssertEqual(duplicated.instructionSections[0].steps.count, 1)
  }

  private func makeRevision(id: UUID, recipeID: UUID, title: String) -> RecipeRevisionRecord {
    let emptyList = Data("[]".utf8)
    return RecipeRevisionRecord(
      id: id,
      recipeID: recipeID,
      revisionNumber: 2,
      title: title,
      summary: nil,
      authorName: nil,
      contentLanguage: nil,
      sourceData: nil,
      yieldData: nil,
      prepSeconds: nil,
      cookSeconds: nil,
      totalSeconds: nil,
      cuisinesData: emptyList,
      categoriesData: emptyList,
      keywordsData: emptyList
    )
  }

  // CloudKit has no SwiftData uniqueness constraint. These duplicate rows model
  // two offline devices inserting the same UUID-backed sample graph.
  private func insertDuplicateChildren(revisionID: UUID, into context: ModelContext) {
    let mediaID = UUID()
    let equipmentID = UUID()
    let ingredientSectionID = UUID()
    let ingredientID = UUID()
    let instructionSectionID = UUID()
    let stepID = UUID()
    for _ in 0..<2 {
      insertMedia(id: mediaID, revisionID: revisionID, into: context)
      insertEquipment(id: equipmentID, revisionID: revisionID, into: context)
      insertIngredientSection(
        id: ingredientSectionID,
        revisionID: revisionID,
        ingredientID: ingredientID,
        into: context
      )
      insertInstructionSection(
        id: instructionSectionID,
        revisionID: revisionID,
        stepID: stepID,
        into: context
      )
    }
  }

  private func insertMedia(id: UUID, revisionID: UUID, into context: ModelContext) {
    context.insert(
      RecipeMediaRecord(
        id: id,
        revisionID: revisionID,
        sortIndex: 0,
        role: RecipeMedia.Role.hero.rawValue,
        assetName: "hero",
        accessibilityLabel: nil
      )
    )
  }

  private func insertEquipment(id: UUID, revisionID: UUID, into context: ModelContext) {
    context.insert(
      EquipmentRecord(
        id: id,
        revisionID: revisionID,
        sortIndex: 0,
        originalText: "Pan",
        quantityData: nil,
        name: "Pan",
        isOptional: false
      )
    )
  }

  private func insertIngredientSection(
    id: UUID,
    revisionID: UUID,
    ingredientID: UUID,
    into context: ModelContext
  ) {
    context.insert(
      IngredientSectionRecord(id: id, revisionID: revisionID, sortIndex: 0, title: nil)
    )
    context.insert(
      RecipeIngredientRecord(
        id: ingredientID,
        sectionID: id,
        sortIndex: 0,
        originalText: "Salt",
        presentationMode: RecipeIngredient.PresentationMode.original.rawValue,
        customDisplayText: nil,
        quantityData: nil,
        unitText: nil,
        packageData: nil,
        ingredientText: nil,
        preparation: nil,
        note: nil,
        isOptional: false,
        scalingBehavior: RecipeIngredient.ScalingBehavior.fixed.rawValue,
        parseState: RecipeIngredient.ParseState.unparsed.rawValue
      )
    )
  }

  private func insertInstructionSection(
    id: UUID,
    revisionID: UUID,
    stepID: UUID,
    into context: ModelContext
  ) {
    context.insert(
      InstructionSectionRecord(id: id, revisionID: revisionID, sortIndex: 0, title: nil)
    )
    context.insert(
      InstructionStepRecord(
        id: stepID,
        sectionID: id,
        sortIndex: 0,
        name: nil,
        text: "Cook",
        durationSeconds: nil,
        temperatureData: nil
      )
    )
  }
}
