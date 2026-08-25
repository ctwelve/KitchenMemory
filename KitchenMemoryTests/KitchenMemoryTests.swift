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
  private final class DescriptionRecorder: @unchecked Sendable {
    var wasRead = false
  }

  private struct PrivateStartupFailure: Error, CustomStringConvertible {
    let recorder: DescriptionRecorder

    var description: String {
      recorder.wasRead = true
      return "private startup details"
    }
  }

  func testStartupPreparationMakesFailureRetryableWithoutReadingPrivateDetails() throws {
    let recorder = DescriptionRecorder()
    var shouldFail = true
    let prepare: () -> AppStartupState = {
      AppStartupState.prepare {
        if shouldFail { throw PrivateStartupFailure(recorder: recorder) }
        return try AppDependencies(inMemory: true)
      }
    }

    XCTAssertNil(prepare().dependencies)
    XCTAssertFalse(recorder.wasRead)

    shouldFail = false
    let recovered = try XCTUnwrap(prepare().dependencies)
    recovered.libraryModel.loadIfNeeded()
    XCTAssertEqual(recovered.libraryModel.recipes.count, 3)
  }

  func testStarterRecipeLoadsThroughAppComposition() throws {
    let dependencies = try AppDependencies(inMemory: true)

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.recipes.count, 3)
    XCTAssertEqual(
      dependencies.libraryModel.selectedRecipe?.revision.title,
      "Dirty Fried Rice"
    )
  }

  func testReloadingDoesNotDuplicateStarterContent() throws {
    let dependencies = try AppDependencies(inMemory: true)

    dependencies.libraryModel.loadIfNeeded()
    dependencies.libraryModel.reload()

    XCTAssertEqual(dependencies.libraryModel.recipes.count, 3)
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

  func testStartupFailureSimulationIsConfinedToTestHarnessBuilds() {
    let arguments = ["KitchenMemory", "--simulate-startup-failure"]

    XCTAssertTrue(AppRuntimeConfiguration.simulatesStartupFailure(
      arguments: arguments,
      buildEnvironment: .testing
    ))
    XCTAssertTrue(AppRuntimeConfiguration.simulatesStartupFailure(
      arguments: arguments,
      buildEnvironment: .productionTesting
    ))
    XCTAssertFalse(AppRuntimeConfiguration.simulatesStartupFailure(
      arguments: arguments,
      buildEnvironment: .debug
    ))
    XCTAssertFalse(AppRuntimeConfiguration.simulatesStartupFailure(
      arguments: arguments,
      buildEnvironment: .develop
    ))
    XCTAssertFalse(AppRuntimeConfiguration.simulatesStartupFailure(
      arguments: arguments,
      buildEnvironment: .production
    ))
  }

  func testCloudSyncPreferenceOverrideIsConfinedToUITestHarnessBuilds() {
    let arguments = [
      "KitchenMemory",
      "--ui-testing",
      "--ui-testing-cloud-sync-disabled",
    ]

    XCTAssertEqual(
      AppRuntimeConfiguration.uiTestCloudSyncPreferenceOverride(
        arguments: arguments,
        buildEnvironment: .productionTesting
      ),
      false
    )
    XCTAssertNil(AppRuntimeConfiguration.uiTestCloudSyncPreferenceOverride(
      arguments: arguments,
      buildEnvironment: .production
    ))
    XCTAssertNil(AppRuntimeConfiguration.uiTestCloudSyncPreferenceOverride(
      arguments: ["KitchenMemory", "--ui-testing-cloud-sync-disabled"],
      buildEnvironment: .productionTesting
    ))
  }

  func testHostedUnitTestsUseDisposableStorageOnlyInTestingBuilds() {
    XCTAssertTrue(AppRuntimeConfiguration.usesInMemoryStore(
      arguments: ["KitchenMemory", "--unit-testing"],
      buildEnvironment: .testing
    ))
    XCTAssertTrue(AppRuntimeConfiguration.usesInMemoryStore(
      arguments: ["KitchenMemory", "--unit-testing"],
      buildEnvironment: .productionTesting
    ))
    XCTAssertFalse(AppRuntimeConfiguration.usesInMemoryStore(
      arguments: ["KitchenMemory", "--unit-testing"],
      buildEnvironment: .production
    ))
  }

  func testCommittedTestPlanRequestsDisposableHostedStorage() {
    XCTAssertTrue(ProcessInfo.processInfo.arguments.contains("--unit-testing"))
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
    XCTAssertFalse(AppRuntimeConfiguration.synchronizesWithPersonalCloud(
      environment: [:],
      cloudSyncIsEnabled: false,
      buildEnvironment: .production
    ))
  }

  func testPersonalCloudContainerComesFromTheSignedBuildConfiguration() throws {
    let productionInfo = [
      AppRuntimeConfiguration.cloudKitContainerInfoKey: "iCloud.net.ctwelve.KitchenMemory",
    ]

    XCTAssertEqual(
      try AppRuntimeConfiguration.personalCloudContainerIdentifier(
        environment: [:],
        infoDictionary: productionInfo,
        buildEnvironment: .production
      ),
      "iCloud.net.ctwelve.KitchenMemory"
    )
    XCTAssertNil(try AppRuntimeConfiguration.personalCloudContainerIdentifier(
      environment: [:],
      infoDictionary: [:],
      buildEnvironment: .testing
    ))
    XCTAssertNil(try AppRuntimeConfiguration.personalCloudContainerIdentifier(
      environment: [:],
      infoDictionary: [:],
      cloudSyncIsEnabled: false,
      buildEnvironment: .production
    ))
    XCTAssertThrowsError(try AppRuntimeConfiguration.personalCloudContainerIdentifier(
      environment: [:],
      infoDictionary: [:],
      buildEnvironment: .develop
    )) { error in
      XCTAssertEqual(
        error as? AppRuntimeConfigurationError,
        .cloudKitContainerIdentifierMissing
      )
    }
  }

  func testCloudKitSchemaInitializationRequiresDevelopAndTheExplicitArgument() {
#if os(macOS)
    XCTAssertTrue(AppRuntimeConfiguration.initializesCloudKitSchema(
      arguments: ["KitchenMemory", "--initialize-cloudkit-schema"],
      buildEnvironment: .develop
    ))
#else
    XCTAssertFalse(AppRuntimeConfiguration.initializesCloudKitSchema(
      arguments: ["KitchenMemory", "--initialize-cloudkit-schema"],
      buildEnvironment: .develop
    ))
#endif
    XCTAssertFalse(AppRuntimeConfiguration.initializesCloudKitSchema(
      arguments: ["KitchenMemory", "--initialize-cloudkit-schema"],
      buildEnvironment: .production
    ))
    XCTAssertFalse(AppRuntimeConfiguration.initializesCloudKitSchema(
      arguments: ["KitchenMemory"],
      buildEnvironment: .develop
    ))
  }
}
