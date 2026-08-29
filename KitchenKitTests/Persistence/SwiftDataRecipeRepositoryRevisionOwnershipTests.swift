// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenKit
import XCTest

@MainActor
final class RecipeRevisionOwnershipTests: XCTestCase {
  func testSaveCannotMoveAnExistingRevisionToAnotherRecipe() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let owner = makeStoredRecipe(kitchenID: kitchen.id, title: "Owner")
    try repository.save(recipe: owner.recipe, revision: owner.revision)
    let collision = makeStoredRecipe(
      revisionID: owner.revision.id,
      kitchenID: kitchen.id,
      title: "Collision"
    )

    assertRevisionConflict(owner.revision.id) {
      try repository.save(recipe: collision.recipe, revision: collision.revision)
    }

    XCTAssertEqual(try repository.recipe(id: owner.id), owner)
    XCTAssertNil(try repository.recipe(id: collision.id))
    XCTAssertEqual(try repository.revisions(for: owner.id), [owner.revision])
    XCTAssertEqual(try repository.revisions(for: collision.id), [])
  }

  func testReplaceCannotStealARevisionOrPartiallyClearDestination() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let home = Kitchen(name: "Home")
    let cabin = Kitchen(name: "Cabin")
    try repository.save(home)
    try repository.save(cabin)
    let owner = makeStoredRecipe(kitchenID: home.id, title: "Owner")
    let destination = makeStoredRecipe(kitchenID: cabin.id, title: "Destination")
    try repository.save(recipe: owner.recipe, revision: owner.revision)
    try repository.save(recipe: destination.recipe, revision: destination.revision)
    let collision = makeStoredRecipe(
      revisionID: owner.revision.id,
      kitchenID: cabin.id,
      title: "Collision"
    )

    assertRevisionConflict(owner.revision.id) {
      try repository.replaceRecipes(in: cabin.id, with: [collision])
    }

    XCTAssertEqual(try repository.recipes(in: home.id), [owner])
    XCTAssertEqual(try repository.recipes(in: cabin.id), [destination])
    XCTAssertEqual(try repository.revisions(for: owner.id), [owner.revision])
    XCTAssertEqual(try repository.revisions(for: destination.id), [destination.revision])
  }

  private func assertRevisionConflict(
    _ revisionID: RecipeRevision.ID,
    operation: () throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try operation(), file: file, line: line) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .revisionAlreadyOwnedByAnotherRecipe(revisionID: revisionID),
        file: file,
        line: line
      )
    }
  }

  private func makeStoredRecipe(
    recipeID: Recipe.ID = Recipe.ID(),
    revisionID: RecipeRevision.ID = RecipeRevision.ID(),
    kitchenID: Kitchen.ID,
    title: String
  ) -> StoredRecipe {
    let revision = RecipeRevision(
      id: revisionID,
      recipeID: recipeID,
      revisionNumber: 1,
      title: title
    )
    return StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id),
      revision: revision
    )
  }
}
