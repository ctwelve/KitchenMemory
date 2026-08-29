// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenKit
import Foundation
import SwiftData
import XCTest

@MainActor
final class SwiftDataRecipeRepositoryAtomicityTests: XCTestCase {
  func testFailedKitchenAndRecipeSavesLeaveNoPendingOrDurablePhantoms() throws {
    try withStore { storeURL in
      var kitchen = Kitchen(name: "Home")
      let original = makeStoredRecipe(kitchenID: kitchen.id, title: "Original")
      let phantomKitchen = Kitchen(name: "Phantom")
      let phantomRecipe = makeStoredRecipe(kitchenID: kitchen.id, title: "Phantom")
      do {
        let writable = SwiftDataRecipeRepository(
          modelContainer: try KitchenMemorySchema.makeContainer(storeURL: storeURL)
        )
        try writable.save(kitchen)
        try writable.save(recipe: original.recipe, revision: original.revision)
      }

      do {
        let repository = SwiftDataRecipeRepository(
          modelContainer: try readOnlyContainer(storeURL: storeURL)
        )
        kitchen.name = "Renamed"
        XCTAssertThrowsError(try repository.save(kitchen))
        XCTAssertThrowsError(try repository.save(phantomKitchen))
        XCTAssertThrowsError(
          try repository.save(recipe: phantomRecipe.recipe, revision: phantomRecipe.revision)
        )

        var originalKitchen = kitchen
        originalKitchen.name = "Home"
        XCTAssertEqual(try repository.kitchen(id: kitchen.id), originalKitchen)
        XCTAssertNil(try repository.kitchen(id: phantomKitchen.id))
        XCTAssertEqual(try repository.recipes(in: kitchen.id), [original])
        XCTAssertNil(try repository.recipe(id: phantomRecipe.id))
      }

      let reopened = SwiftDataRecipeRepository(
        modelContainer: try KitchenMemorySchema.makeContainer(storeURL: storeURL)
      )
      XCTAssertEqual(try reopened.kitchen(id: kitchen.id)?.name, "Home")
      XCTAssertNil(try reopened.kitchen(id: phantomKitchen.id))
      XCTAssertEqual(try reopened.recipes(in: kitchen.id), [original])
      XCTAssertNil(try reopened.recipe(id: phantomRecipe.id))
    }
  }

  func testFailedReplacementLeavesSameRepositoryAndFreshStoreUnchanged() throws {
    try withStore { storeURL in
      let kitchen = Kitchen(name: "Home")
      let original = makeStoredRecipe(kitchenID: kitchen.id, title: "Original")
      do {
        let writable = SwiftDataRecipeRepository(
          modelContainer: try KitchenMemorySchema.makeContainer(storeURL: storeURL)
        )
        try writable.save(kitchen)
        try writable.save(recipe: original.recipe, revision: original.revision)
      }

      let replacement = makeStoredRecipe(kitchenID: kitchen.id, title: "Replacement")
      do {
        let repository = SwiftDataRecipeRepository(
          modelContainer: try readOnlyContainer(storeURL: storeURL)
        )
        XCTAssertThrowsError(
          try repository.replaceRecipes(in: kitchen.id, with: [replacement])
        )
        XCTAssertEqual(try repository.recipes(in: kitchen.id), [original])
      }

      // A fresh coordinator separately proves the failed transaction changed
      // no durable rows after the same repository confirmed usable state.
      let reopened = SwiftDataRecipeRepository(
        modelContainer: try KitchenMemorySchema.makeContainer(storeURL: storeURL)
      )
      XCTAssertEqual(try reopened.recipes(in: kitchen.id), [original])
    }
  }

  private func readOnlyContainer(storeURL: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: KitchenMemorySchemaV3.self)
    let configuration = ModelConfiguration(
      "KitchenMemoryReadOnly",
      schema: schema,
      url: storeURL,
      allowsSave: false,
      cloudKitDatabase: .none
    )
    return try ModelContainer(
      for: schema,
      migrationPlan: KitchenMemoryMigrationPlan.self,
      configurations: [configuration]
    )
  }

  private func withStore(_ operation: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "KitchenMemoryReadOnlyStoreTests")
      .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    try operation(directory.appending(path: "KitchenMemory.store"))
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
