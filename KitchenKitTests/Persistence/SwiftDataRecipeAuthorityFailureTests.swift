// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import SwiftData
import XCTest

@MainActor
final class SwiftDataRecipeAuthorityFailureTests: XCTestCase {
  func testSelectionValidationAndCollisionLeaveAcceptedChoiceIntact() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)

    let duplicateFrontier = RecipeSelectionCommand(
      kitchenID: kitchen.id, recipeID: command.recipe.id,
      selectedRevisionID: command.revision.id, selectedAt: Date(),
      observedSelectionIDs: [command.selection.id, command.selection.id]
    )
    XCTAssertThrowsError(try repository.select(duplicateFrontier)) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .invalidRecipeSaveCommand)
    }

    let unknownRevision = RecipeSelectionCommand(
      kitchenID: kitchen.id, recipeID: command.recipe.id,
      selectedRevisionID: RecipeRevision.ID(), selectedAt: Date()
    )
    XCTAssertThrowsError(try repository.select(unknownRevision)) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .invalidRecipeSaveCommand)
    }

    let choice = RecipeSelectionCommand(
      kitchenID: kitchen.id, recipeID: command.recipe.id,
      selectedRevisionID: command.revision.id, selectedAt: Date(),
      observedSelectionIDs: [command.selection.id]
    )
    try repository.select(choice)
    let collision = RecipeSelectionCommand(
      id: choice.id, kitchenID: choice.kitchenID, recipeID: choice.recipeID,
      selectedRevisionID: choice.selectedRevisionID,
      selectedAt: choice.selectedAt.addingTimeInterval(1),
      observedSelectionIDs: choice.observedSelectionIDs
    )
    XCTAssertThrowsError(try repository.select(collision)) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .recipeSelectionCommandCollision(commandID: choice.id)
      )
    }
    XCTAssertEqual(
      try ModelContext(container).fetchCount(FetchDescriptor<RecipeSelectionRecord>()),
      2
    )
  }

  func testCompatibilitySaveUsesProjectedRevisionAndSelectionHeads() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let first = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(recipe: first.recipe, revision: first.revision)
    let second = makeCommand(
      kitchenID: kitchen.id, recipeID: first.recipe.id, number: 2,
      parents: [first.revision.id],
      observed: [.init(rawValue: first.revision.id.rawValue)]
    )
    try repository.save(second)
    let choice = RecipeSelectionCommand(
      kitchenID: kitchen.id, recipeID: first.recipe.id,
      selectedRevisionID: first.revision.id, selectedAt: Date(),
      observedSelectionIDs: [second.selection.id]
    )
    try repository.select(choice)

    let thirdRevision = RecipeRevision(
      recipeID: first.recipe.id, revisionNumber: 3, title: "Revision 3"
    )
    let thirdRecipe = Recipe(
      id: first.recipe.id, kitchenID: kitchen.id, currentRevisionID: thirdRevision.id
    )
    try repository.save(recipe: thirdRecipe, revision: thirdRevision)
    try repository.save(recipe: thirdRecipe, revision: thirdRevision)

    let context = ModelContext(container)
    let save = try XCTUnwrap(try context.fetch(FetchDescriptor<RecipeSaveRecord>())
      .first { $0.id == thirdRevision.id.rawValue })
    XCTAssertEqual(
      try RecipeIdentifierSetCodec.decode(
        formatVersion: save.ancestryFormatVersion, data: save.parentRevisionIDsData
      ),
      [first.revision.id.rawValue]
    )
    let selection = try XCTUnwrap(try context.fetch(FetchDescriptor<RecipeSelectionRecord>())
      .first { $0.id == thirdRevision.id.rawValue })
    XCTAssertEqual(
      try RecipeIdentifierSetCodec.decode(
        formatVersion: selection.frontierFormatVersion,
        data: selection.observedSelectionIDsData
      ),
      [choice.id.rawValue]
    )
  }

  func testRepositoryMapsDeletionAndRestoration() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)
    let deletionID = UUID()
    let context = ModelContext(container)
    context.insert(RecipeDeletionRecord(
      id: deletionID, recipeID: command.recipe.id.rawValue,
      kitchenID: kitchen.id.rawValue, deletedAt: Date()
    ))
    try context.save()
    let deletedReader = SwiftDataRecipeRepository(modelContainer: container)
    guard case .deleted = try deletedReader.recipeAuthority(id: command.recipe.id) else {
      XCTFail("Expected deleted authority")
      return
    }
    XCTAssertNil(try deletedReader.recipe(id: command.recipe.id))

    let restorationContext = ModelContext(container)
    restorationContext.insert(RecipeDeletionResolutionRecord(
      id: UUID(), deletionID: deletionID, recipeID: command.recipe.id.rawValue,
      kitchenID: kitchen.id.rawValue, restoredAt: Date()
    ))
    try restorationContext.save()
    let restoredReader = SwiftDataRecipeRepository(modelContainer: container)
    guard case .available = try restoredReader.recipeAuthority(id: command.recipe.id) else {
      XCTFail("Expected restored authority")
      return
    }
  }

  func testRepositoryMapsPruneAndCorruption() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)
    let prunedRecipeID = Recipe.ID()
    let frontier = RecipeAuthorityFrontierCodec.encode(RecipeAuthorityFrontier(
      revisionHeads: [], selectionHeads: [], deletionIDs: [], restorationIDs: []
    ))
    let pruneContext = ModelContext(container)
    pruneContext.insert(RecipePruneRecord(
      id: UUID(), kitchenID: kitchen.id.rawValue, recipeID: prunedRecipeID.rawValue,
      prunedAt: Date(), antiResurrectionUntil: Date().addingTimeInterval(1),
      frontierFormatVersion: frontier.formatVersion, frontierData: frontier.data,
      frontierDigest: frontier.digest
    ))
    try pruneContext.save()
    let pruneReader = SwiftDataRecipeRepository(modelContainer: container)
    XCTAssertEqual(try pruneReader.recipeAuthority(id: prunedRecipeID), .pruned)
    XCTAssertNil(try pruneReader.recipe(id: prunedRecipeID))

    let corruptContext = ModelContext(container)
    let save = try XCTUnwrap(try corruptContext.fetch(FetchDescriptor<RecipeSaveRecord>())
      .first { $0.recipeID == command.recipe.id.rawValue })
    save.parentRevisionIDsData = Data([0])
    try corruptContext.save()
    XCTAssertThrowsError(
      try SwiftDataRecipeRepository(modelContainer: container).recipe(id: command.recipe.id)
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .invalidStoredValue(field: "recipe.authority")
      )
    }
  }

  func testMissingAuthoritativeRevisionMapsToLegacyMissingRevisionFailure() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)
    let context = ModelContext(container)
    for record in try context.fetch(FetchDescriptor<RecipeRevisionRecord>()) {
      context.delete(record)
    }
    try context.save()

    XCTAssertThrowsError(
      try SwiftDataRecipeRepository(modelContainer: container).recipe(id: command.recipe.id)
    ) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .missingCurrentRevision)
    }
  }

  func testSaveRejectsDuplicateManifestIdentityAndChangedImmutablePayload() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let mediaID = RecipeMedia.ID()
    let duplicateMedia = RecipeRevision(
      recipeID: Recipe.ID(), revisionNumber: 1, title: "Duplicate",
      media: [
        RecipeMedia(id: mediaID, role: .hero, assetName: "one"),
        RecipeMedia(id: mediaID, role: .gallery, assetName: "two"),
      ]
    )
    let duplicateRecipe = Recipe(
      id: duplicateMedia.recipeID, kitchenID: kitchen.id,
      currentRevisionID: duplicateMedia.id
    )
    XCTAssertThrowsError(try repository.save(RecipeSaveCommand(
      recipe: duplicateRecipe,
      revision: duplicateMedia,
      savedAt: Date(),
      parentRevisionIDs: [],
      selection: RecipeSelectionCommand(
        kitchenID: kitchen.id, recipeID: duplicateRecipe.id,
        selectedRevisionID: duplicateMedia.id, selectedAt: Date()
      )
    ))) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .invalidRecipeSaveCommand)
    }

    let original = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(original)
    let changedRevision = RecipeRevision(
      id: original.revision.id, recipeID: original.recipe.id,
      revisionNumber: original.revision.revisionNumber, title: "Changed"
    )
    let collision = RecipeSaveCommand(
      recipe: original.recipe, revision: changedRevision, savedAt: Date(),
      parentRevisionIDs: [],
      selection: RecipeSelectionCommand(
        kitchenID: kitchen.id, recipeID: original.recipe.id,
        selectedRevisionID: changedRevision.id, selectedAt: Date()
      )
    )
    XCTAssertThrowsError(try repository.save(collision)) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .recipeSaveCommandCollision(commandID: collision.id)
      )
    }
  }

  private func makeCommand(
    kitchenID: Kitchen.ID,
    recipeID: Recipe.ID = Recipe.ID(),
    number: Int,
    parents: [RecipeRevision.ID] = [],
    observed: [RecipeSelectionCommand.ID] = []
  ) -> RecipeSaveCommand {
    let revision = RecipeRevision(
      recipeID: recipeID, revisionNumber: number, title: "Revision \(number)"
    )
    let recipe = Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id)
    return RecipeSaveCommand(
      recipe: recipe, revision: revision, savedAt: Date(), parentRevisionIDs: parents,
      selection: RecipeSelectionCommand(
        kitchenID: kitchenID, recipeID: recipeID, selectedRevisionID: revision.id,
        selectedAt: Date(), observedSelectionIDs: observed
      )
    )
  }
}
