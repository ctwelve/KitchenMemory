// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
final class SwiftDataRecipeRepositoryBoundaryTests: XCTestCase {
  func testStoredRecipeUsesTheDurableRecipeIdentity() {
    let stored = makeStoredRecipe(kitchenID: Kitchen.ID(), title: "Identity")

    XCTAssertEqual(stored.id, stored.recipe.id)
  }

  func testSavingAnExistingKitchenUpdatesItsName() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    var kitchen = Kitchen(name: "Before")
    try repository.save(kitchen)
    XCTAssertEqual(try repository.kitchen(id: kitchen.id), kitchen)

    kitchen.name = "After"
    try repository.save(kitchen)

    XCTAssertEqual(try repository.kitchen(id: kitchen.id), kitchen)
    XCTAssertEqual(try repository.kitchens(), [kitchen])
  }

  func testAtomicCreateRefusesToReplaceAnExistingKitchen() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Home")
    try repository.create(kitchen, with: [])

    XCTAssertThrowsError(try repository.create(kitchen, with: [])) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .kitchenAlreadyExists(kitchenID: kitchen.id)
      )
    }
    XCTAssertEqual(try repository.kitchens(), [kitchen])
  }

  func testAtomicCreateRollsBackKitchenWhenRecipeIdentityIsInvalid() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Home")
    let revision = RecipeRevision(recipeID: Recipe.ID(), revisionNumber: 1, title: "Invalid")
    let stored = StoredRecipe(
      recipe: Recipe(
        id: Recipe.ID(),
        kitchenID: kitchen.id,
        currentRevisionID: revision.id
      ),
      revision: revision
    )

    XCTAssertThrowsError(try repository.create(kitchen, with: [stored])) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .inconsistentRecipeIdentity)
    }
    XCTAssertTrue(try repository.kitchens().isEmpty)
  }

  func testDurationFieldsRoundTripFromStoredSeconds() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Home")
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(
      recipeID: recipeID,
      revisionNumber: 1,
      title: "Timed",
      prepDuration: RecipeDuration(seconds: 300),
      cookDuration: RecipeDuration(seconds: 900),
      totalDuration: RecipeDuration(seconds: 1_200)
    )
    let recipe = Recipe(
      id: recipeID,
      kitchenID: kitchen.id,
      currentRevisionID: revision.id
    )
    try repository.save(kitchen)
    try repository.save(recipe: recipe, revision: revision)

    let stored = try XCTUnwrap(repository.recipe(id: recipeID)).revision
    XCTAssertEqual(stored.prepDuration, revision.prepDuration)
    XCTAssertEqual(stored.cookDuration, revision.cookDuration)
    XCTAssertEqual(stored.totalDuration, revision.totalDuration)
  }

  func testReplaceRejectsMissingKitchen() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )

    XCTAssertThrowsError(
      try repository.replaceRecipes(in: Kitchen.ID(), with: [])
    ) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .missingKitchen)
    }
  }

  func testReplaceRejectsEachInconsistentIdentityRelationship() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let valid = makeStoredRecipe(kitchenID: kitchen.id, title: "Valid")
    let wrongKitchen = StoredRecipe(
      recipe: Recipe(
        id: valid.recipe.id,
        kitchenID: Kitchen.ID(),
        currentRevisionID: valid.revision.id
      ),
      revision: valid.revision
    )
    let wrongRecipeRevision = RecipeRevision(
      recipeID: Recipe.ID(),
      revisionNumber: 1,
      title: "Wrong recipe"
    )
    let wrongRecipe = StoredRecipe(
      recipe: Recipe(
        id: valid.recipe.id,
        kitchenID: kitchen.id,
        currentRevisionID: wrongRecipeRevision.id
      ),
      revision: wrongRecipeRevision
    )
    let wrongCurrentRevision = StoredRecipe(
      recipe: Recipe(
        id: valid.recipe.id,
        kitchenID: kitchen.id,
        currentRevisionID: RecipeRevision.ID()
      ),
      revision: valid.revision
    )

    for (relationship, stored) in [
      ("kitchen", wrongKitchen),
      ("recipe", wrongRecipe),
      ("current revision", wrongCurrentRevision),
    ] {
      XCTAssertThrowsError(
        try repository.replaceRecipes(in: kitchen.id, with: [stored]),
        "Expected \(relationship) mismatch to be rejected"
      ) { error in
        XCTAssertEqual(error as? KitchenMemoryPersistenceError, .inconsistentRecipeIdentity)
      }
    }
  }

  private func makeStoredRecipe(kitchenID: Kitchen.ID, title: String) -> StoredRecipe {
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: title)
    return StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id),
      revision: revision
    )
  }
}
