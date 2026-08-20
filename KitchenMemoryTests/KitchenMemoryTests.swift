// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemory
import KitchenMemoryDomain
import KitchenMemoryPersistence
import KitchenMemorySampleData
import XCTest

@MainActor
final class KitchenMemoryTests: XCTestCase {
  func testStarterRecipeLoadsThroughAppComposition() throws {
    let dependencies = try AppDependencies(inMemory: true)

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.recipes.count, 1)
    XCTAssertEqual(
      dependencies.libraryModel.selectedRecipe?.revision.title,
      "Tuna Noodle Hotdish"
    )
  }

  func testReloadingDoesNotDuplicateStarterContent() throws {
    let dependencies = try AppDependencies(inMemory: true)

    dependencies.libraryModel.loadIfNeeded()
    dependencies.libraryModel.reload()

    XCTAssertEqual(dependencies.libraryModel.recipes.count, 1)
  }

  func testNewStoreCreatesOneKitchenAndImportsTheSampleCollectionOnce() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )

    let firstKitchen = try AppDependencies.prepareInitialKitchen(repository: repository)
    let secondKitchen = try AppDependencies.prepareInitialKitchen(repository: repository)
    let manifest = try SampleRecipeCatalog.loadManifest()

    XCTAssertEqual(firstKitchen, secondKitchen)
    XCTAssertEqual(try repository.kitchens(), [firstKitchen])
    XCTAssertEqual(
      try repository.recipes(in: firstKitchen.id).map(\.recipe.id),
      manifest.recipes.map(\.recipeID)
    )
  }

  func testSourceURLPolicyAllowsOnlyBoundedCredentialFreeWebLinks() {
    XCTAssertEqual(
      RecipeSourceURLPolicy.validatedURL(from: "  https://recipes.example/soup  ")?
        .absoluteString,
      "https://recipes.example/soup"
    )
    XCTAssertNotNil(RecipeSourceURLPolicy.validatedURL(from: "http://recipes.example/soup"))
    XCTAssertEqual(
      RecipeSourceURLPolicy.displayHost(
        for: URL(string: "https://recipes.example:8443/soup")!
      ),
      "recipes.example:8443"
    )

    let rejected = [
      "recipes.example/soup",
      "/soup",
      "file:///tmp/soup",
      "javascript:alert(1)",
      "https://person:secret@recipes.example/soup",
      "https:///soup",
      "https://example.com/" + String(repeating: "a", count: 4_096),
    ]
    for value in rejected {
      XCTAssertNil(RecipeSourceURLPolicy.validatedURL(from: value), value)
    }
  }
}
