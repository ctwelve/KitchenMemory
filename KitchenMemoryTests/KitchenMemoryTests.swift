// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemory
import KitchenMemoryDomain
import KitchenMemoryLogic
import KitchenMemoryPersistence
import XCTest

@MainActor
final class KitchenMemoryTests: XCTestCase {
  func testStarterRecipeLoadsThroughAppComposition() throws {
    let dependencies = try AppDependencies(inMemory: true)

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.recipes.count, 2)
    XCTAssertEqual(
      dependencies.libraryModel.selectedRecipe?.revision.title,
      "Dirty Fried Rice"
    )
  }

  func testReloadingDoesNotDuplicateStarterContent() throws {
    let dependencies = try AppDependencies(inMemory: true)

    dependencies.libraryModel.loadIfNeeded()
    dependencies.libraryModel.reload()

    XCTAssertEqual(dependencies.libraryModel.recipes.count, 2)
  }

  func testNewStoreCreatesOneEmptyKitchenWithoutAssumingSampleConsent() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )

    let firstKitchen = try AppDependencies.prepareInitialKitchen(repository: repository)
    let secondKitchen = try AppDependencies.prepareInitialKitchen(repository: repository)

    XCTAssertEqual(firstKitchen, secondKitchen)
    XCTAssertEqual(try repository.kitchens(), [firstKitchen])
    XCTAssertTrue(try repository.recipes(in: firstKitchen.id).isEmpty)
  }

  func testResetKitchenRemovesUserRecipesAndRestoresCurrentSamples() throws {
    let dependencies = try AppDependencies(inMemory: true)
    dependencies.libraryModel.loadIfNeeded()
    let manifest = try SampleRecipeCatalog.loadManifest()

    XCTAssertTrue(
      dependencies.libraryModel.createRecipe(from: RecipeDraft(title: "Temporary Recipe"))
    )
    let temporaryRecipeID = try XCTUnwrap(dependencies.libraryModel.selectedRecipeID)
    XCTAssertEqual(dependencies.libraryModel.recipes.count, manifest.recipes.count + 1)

    XCTAssertTrue(dependencies.libraryModel.resetKitchen())
    XCTAssertEqual(
      Set(dependencies.libraryModel.recipes.map(\.recipe.id)),
      Set(try SampleRecipeCatalog.localizedRecipes(
        in: manifest,
        preferredLanguages: Locale.preferredLanguages
      ).map(\.recipeID))
    )
    XCTAssertFalse(
      dependencies.libraryModel.recipes.contains { $0.recipe.id == temporaryRecipeID }
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

#if DEBUG
  func testUITestingUsesDisposableStorageOnlyWhenExplicitlyRequestedInDebug() {
    XCTAssertTrue(AppRuntimeConfiguration.usesInMemoryStore(
      arguments: ["KitchenMemory", "--ui-testing"]
    ))
    XCTAssertFalse(AppRuntimeConfiguration.usesInMemoryStore(
      arguments: ["KitchenMemory"]
    ))
  }
#endif
}
