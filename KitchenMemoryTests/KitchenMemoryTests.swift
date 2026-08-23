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

  func testNewStoreCreatesOneEmptyKitchenWithoutAssumingSamplePermission() throws {
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

  func testBuildEnvironmentPolicyKeepsCloudAndTestHarnessesSeparate() {
    XCTAssertFalse(AppBuildEnvironment.debug.synchronizesWithPersonalCloud)
    XCTAssertTrue(AppBuildEnvironment.develop.synchronizesWithPersonalCloud)
    XCTAssertFalse(AppBuildEnvironment.testing.synchronizesWithPersonalCloud)
    XCTAssertTrue(AppBuildEnvironment.production.synchronizesWithPersonalCloud)
    XCTAssertFalse(AppBuildEnvironment.productionTesting.synchronizesWithPersonalCloud)

    XCTAssertFalse(AppBuildEnvironment.debug.permitsUITestHarness)
    XCTAssertFalse(AppBuildEnvironment.develop.permitsUITestHarness)
    XCTAssertTrue(AppBuildEnvironment.testing.permitsUITestHarness)
    XCTAssertFalse(AppBuildEnvironment.production.permitsUITestHarness)
    XCTAssertTrue(AppBuildEnvironment.productionTesting.permitsUITestHarness)

    XCTAssertFalse(AppBuildEnvironment.debug.permitsCloudKitSchemaAdministration)
    XCTAssertTrue(AppBuildEnvironment.develop.permitsCloudKitSchemaAdministration)
    XCTAssertFalse(AppBuildEnvironment.testing.permitsCloudKitSchemaAdministration)
    XCTAssertFalse(AppBuildEnvironment.production.permitsCloudKitSchemaAdministration)
    XCTAssertFalse(AppBuildEnvironment.productionTesting.permitsCloudKitSchemaAdministration)
  }

  func testCurrentBuildEnvironmentMatchesCompilationConditions() {
#if TESTING && PRODUCTION
    XCTAssertEqual(AppBuildEnvironment.current, .productionTesting)
#elseif TESTING
    XCTAssertEqual(AppBuildEnvironment.current, .testing)
#elseif DEVELOP
    XCTAssertEqual(AppBuildEnvironment.current, .develop)
#elseif PRODUCTION
    XCTAssertEqual(AppBuildEnvironment.current, .production)
#else
    XCTAssertEqual(AppBuildEnvironment.current, .debug)
#endif
  }

  func testUITestingUsesDisposableStorageOnlyInTestingBuilds() {
    XCTAssertTrue(AppRuntimeConfiguration.usesInMemoryStore(
      arguments: ["KitchenMemory", "--ui-testing"],
      buildEnvironment: .productionTesting
    ))
    XCTAssertFalse(AppRuntimeConfiguration.usesInMemoryStore(
      arguments: ["KitchenMemory", "--ui-testing"],
      buildEnvironment: .production
    ))
  }

  func testHostedUnitTestsDisablePersonalCloudInCloudEnabledBuilds() {
    XCTAssertFalse(AppRuntimeConfiguration.synchronizesWithPersonalCloud(
      environment: ["XCTestConfigurationFilePath": "/tmp/KitchenMemory.xctestconfiguration"],
      buildEnvironment: .develop
    ))
    XCTAssertTrue(AppRuntimeConfiguration.synchronizesWithPersonalCloud(
      environment: [:],
      buildEnvironment: .production
    ))
  }

  func testCloudKitSchemaInitializationRequiresDevelopAndTheExplicitArgument() {
    XCTAssertTrue(AppRuntimeConfiguration.initializesCloudKitSchema(
      arguments: ["KitchenMemory", "--initialize-cloudkit-schema"],
      buildEnvironment: .develop
    ))
    XCTAssertFalse(AppRuntimeConfiguration.initializesCloudKitSchema(
      arguments: ["KitchenMemory", "--initialize-cloudkit-schema"],
      buildEnvironment: .production
    ))
  }
}
