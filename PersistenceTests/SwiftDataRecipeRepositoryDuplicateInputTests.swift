// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryPersistence
import KitchenMemoryDomain
import XCTest

@MainActor
final class RecipeReplacementDuplicateTests: XCTestCase {
  func testReplaceRejectsDuplicateRecipeIDsWithoutPartialMutation() throws {
    let fixture = try makeFixture()
    let duplicateID = Recipe.ID()
    let first = makeStoredRecipe(recipeID: duplicateID, kitchenID: fixture.kitchen.id, title: "A")
    let second = makeStoredRecipe(recipeID: duplicateID, kitchenID: fixture.kitchen.id, title: "B")

    XCTAssertThrowsError(
      try fixture.repository.replaceRecipes(in: fixture.kitchen.id, with: [first, second])
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .duplicateRecipeID(recipeID: duplicateID)
      )
    }

    try assertUnchanged(fixture, absentRecipeIDs: [duplicateID])
  }

  func testReplaceRejectsDuplicateRevisionIDsWithoutPartialMutation() throws {
    let fixture = try makeFixture()
    let duplicateID = RecipeRevision.ID()
    let first = makeStoredRecipe(
      revisionID: duplicateID,
      kitchenID: fixture.kitchen.id,
      title: "A"
    )
    let second = makeStoredRecipe(
      revisionID: duplicateID,
      kitchenID: fixture.kitchen.id,
      title: "B"
    )

    XCTAssertThrowsError(
      try fixture.repository.replaceRecipes(in: fixture.kitchen.id, with: [first, second])
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .duplicateRevisionID(revisionID: duplicateID)
      )
    }

    try assertUnchanged(fixture, absentRecipeIDs: [first.id, second.id])
  }

  private func assertUnchanged(
    _ fixture: Fixture,
    absentRecipeIDs: [Recipe.ID],
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    XCTAssertEqual(
      try fixture.repository.recipes(in: fixture.kitchen.id),
      [fixture.original],
      file: file,
      line: line
    )
    XCTAssertEqual(
      try fixture.repository.revisions(for: fixture.original.id),
      [fixture.original.revision],
      file: file,
      line: line
    )
    for recipeID in absentRecipeIDs {
      XCTAssertNil(try fixture.repository.recipe(id: recipeID), file: file, line: line)
      XCTAssertEqual(
        try fixture.repository.revisions(for: recipeID),
        [],
        file: file,
        line: line
      )
    }
  }

  private func makeFixture() throws -> Fixture {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Home")
    let original = makeStoredRecipe(kitchenID: kitchen.id, title: "Original")
    try repository.save(kitchen)
    try repository.save(recipe: original.recipe, revision: original.revision)
    return Fixture(repository: repository, kitchen: kitchen, original: original)
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

@MainActor
private struct Fixture {
  let repository: SwiftDataRecipeRepository
  let kitchen: Kitchen
  let original: StoredRecipe
}
