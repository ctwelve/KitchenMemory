// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenKit
import XCTest

@MainActor
final class SwiftDataRecipeRepositoryOwnershipTests: XCTestCase {
  func testSaveCannotMoveAnExistingRecipeToAnotherKitchen() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let home = Kitchen(name: "Home")
    let cabin = Kitchen(name: "Cabin")
    try repository.save(home)
    try repository.save(cabin)
    let original = makeStoredRecipe(kitchenID: home.id, title: "Home Soup")
    try repository.save(recipe: original.recipe, revision: original.revision)
    let collision = makeStoredRecipe(
      recipeID: original.id,
      kitchenID: cabin.id,
      title: "Cabin Soup"
    )

    assertOwnershipConflict(original.id) {
      try repository.save(recipe: collision.recipe, revision: collision.revision)
    }

    XCTAssertEqual(try repository.recipes(in: home.id), [original])
    XCTAssertEqual(try repository.recipes(in: cabin.id), [])
    XCTAssertEqual(try repository.revisions(for: original.id), [original.revision])
  }

  func testReplaceCannotStealARecipeOrPartiallyClearTheDestinationKitchen() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let home = Kitchen(name: "Home")
    let cabin = Kitchen(name: "Cabin")
    try repository.save(home)
    try repository.save(cabin)
    let homeRecipe = makeStoredRecipe(kitchenID: home.id, title: "Home Soup")
    let cabinRecipe = makeStoredRecipe(kitchenID: cabin.id, title: "Cabin Chili")
    try repository.save(recipe: homeRecipe.recipe, revision: homeRecipe.revision)
    try repository.save(recipe: cabinRecipe.recipe, revision: cabinRecipe.revision)
    let collision = makeStoredRecipe(
      recipeID: homeRecipe.id,
      kitchenID: cabin.id,
      title: "Stolen Soup"
    )

    assertOwnershipConflict(homeRecipe.id) {
      try repository.replaceRecipes(in: cabin.id, with: [collision])
    }

    XCTAssertEqual(try repository.recipes(in: home.id), [homeRecipe])
    XCTAssertEqual(try repository.recipes(in: cabin.id), [cabinRecipe])
    XCTAssertEqual(try repository.revisions(for: homeRecipe.id), [homeRecipe.revision])
    XCTAssertEqual(try repository.revisions(for: cabinRecipe.id), [cabinRecipe.revision])
  }

  private func assertOwnershipConflict(
    _ recipeID: Recipe.ID,
    operation: () throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try operation(), file: file, line: line) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .recipeAlreadyOwnedByAnotherKitchen(recipeID: recipeID),
        file: file,
        line: line
      )
    }
  }

  private func makeStoredRecipe(
    recipeID: Recipe.ID = Recipe.ID(),
    kitchenID: Kitchen.ID,
    title: String
  ) -> StoredRecipe {
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: title)
    return StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id),
      revision: revision
    )
  }
}
