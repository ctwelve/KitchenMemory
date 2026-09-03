// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class KitchenMemoryTests: XCTestCase {
  func testStarterRecipeLoadsThroughAppComposition() throws {
    let preparedApp = try AppRuntime.testing()

    preparedApp.libraryModel.loadIfNeeded()

    XCTAssertEqual(preparedApp.libraryModel.recipes.count, 3)
    XCTAssertEqual(
      preparedApp.libraryModel.selectedRecipe?.revision.title,
      "Dirty Fried Rice"
    )
  }

  func testCurrentRuntimeUsesTheHostedTestEnvironment() async throws {
    let startupState = await AppRuntime.prepare()
    let preparedApp = try XCTUnwrap(startupState.preparedApp)

    preparedApp.libraryModel.loadIfNeeded()

    XCTAssertEqual(preparedApp.libraryModel.recipes.count, 3)
    XCTAssertNotNil(preparedApp.cloudSyncSettings)
    XCTAssertNil(preparedApp.persistentStoreChangeObserver)
    XCTAssertNil(preparedApp.personalCloudStatusMonitor)
  }

  func testReloadingDoesNotDuplicateStarterContent() throws {
    let preparedApp = try AppRuntime.testing()

    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.libraryModel.reload()

    XCTAssertEqual(preparedApp.libraryModel.recipes.count, 3)
  }

  func testNewStoreCreatesOneEmptyKitchenWithoutAssumingSamplePermission() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )

    let bootstrap = KitchenBootstrapService(repository: repository)
    let firstKitchen = try bootstrap.prepareInitialKitchen()
    let secondKitchen = try bootstrap.prepareInitialKitchen()

    XCTAssertEqual(firstKitchen, secondKitchen)
    XCTAssertEqual(try repository.kitchens(), [firstKitchen])
    XCTAssertTrue(try repository.recipes(in: firstKitchen.id).isEmpty)
  }

  func testResetKitchenRemovesUserRecipesAndRestoresCurrentSamples() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    let manifest = try SampleRecipeCatalog.loadManifest()

    XCTAssertTrue(
      preparedApp.libraryModel.createRecipe(from: RecipeDraft(title: "Temporary Recipe"))
    )
    let temporaryRecipeID = try XCTUnwrap(preparedApp.libraryModel.selectedRecipeID)
    XCTAssertEqual(preparedApp.libraryModel.recipes.count, manifest.recipes.count + 1)

    XCTAssertTrue(preparedApp.libraryModel.resetKitchen())
    XCTAssertEqual(
      Set(preparedApp.libraryModel.recipes.map(\.recipe.id)),
      Set(try SampleRecipeCatalog.localizedRecipes(
        in: manifest,
        preferredLanguages: Locale.preferredLanguages
      ).map(\.recipeID))
    )
    XCTAssertFalse(
      preparedApp.libraryModel.recipes.contains { $0.recipe.id == temporaryRecipeID }
    )
  }

  func testResetLeavesOnlySamplesAndClearsAllSessionStateAcrossRelaunch() throws {
    let store = VolatileCookingSessionPresentationStore()
    let preparedApp = try AppRuntime.testing(.init(sessionPresentationStore: store))
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    XCTAssertTrue(try preparedApp.cookingSessionRepository.sessions(in: recipe.recipe.kitchenID).isEmpty)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let sessionID = try XCTUnwrap(preparedApp.sessionModel.currentSessionID)
    preparedApp.sessionModel.replaceDraft(CookingSessionEntryDraft(
      sessionID: sessionID,
      text: "Remember less salt"
    ))
    store.pendingCommands = [
      .stop(factID: SessionFact.ID(), sessionID: sessionID, authoredAt: Date()),
    ]

    XCTAssertTrue(preparedApp.libraryModel.resetKitchen())

    XCTAssertEqual(preparedApp.libraryModel.recipes.count, 3)
    XCTAssertTrue(try preparedApp.cookingSessionRepository
      .sessions(in: recipe.recipe.kitchenID).isEmpty)
    let relaunched = SwiftDataCookingSessionRepository(modelContainer: preparedApp.modelContainer)
    XCTAssertTrue(try relaunched.sessions(in: recipe.recipe.kitchenID).isEmpty)
    XCTAssertNil(store.currentSessionID)
    XCTAssertTrue(store.pendingCommands.isEmpty)
    XCTAssertTrue(store.entryDrafts.isEmpty)
    XCTAssertTrue(store.sessionVisits.isEmpty)
    XCTAssertNil(preparedApp.sessionModel.currentSessionID)
    XCTAssertNil(preparedApp.sessionModel.detachedEntryDraft)
    XCTAssertTrue(preparedApp.sessionModel.sessions.isEmpty)
    XCTAssertTrue(preparedApp.sessionModel.finishedSessions.isEmpty)
    XCTAssertTrue(preparedApp.sessionModel.deletedSessions.isEmpty)
    XCTAssertTrue(preparedApp.sessionModel.waitingSessions.isEmpty)
    XCTAssertTrue(preparedApp.sessionModel.recoverySessions.isEmpty)
  }

  func testFailedResetPreservesDurableAndPresentationSessionState() throws {
    let store = VolatileCookingSessionPresentationStore()
    let preparedApp = try AppRuntime.testing(.init(
      library: .empty,
      sampleProvider: FailingResetSampleProvider(),
      sessionPresentationStore: store
    ))
    preparedApp.libraryModel.loadIfNeeded()
    XCTAssertTrue(preparedApp.libraryModel.createRecipe(from: RecipeDraft(title: "Keep Me")))
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.selectedRecipe)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let sessionID = try XCTUnwrap(preparedApp.sessionModel.currentSessionID)
    preparedApp.sessionModel.replaceDraft(CookingSessionEntryDraft(
      sessionID: sessionID,
      text: "Keep this too"
    ))

    XCTAssertFalse(preparedApp.libraryModel.resetKitchen())

    XCTAssertEqual(preparedApp.libraryModel.recipes.map(\.revision.title), ["Keep Me"])
    XCTAssertEqual(try preparedApp.cookingSessionRepository
      .sessions(in: recipe.recipe.kitchenID).count, 1)
    XCTAssertEqual(store.currentSessionID, sessionID)
    XCTAssertEqual(store.entryDrafts.map(\.text), ["Keep this too"])
    XCTAssertEqual(preparedApp.sessionModel.currentSessionID, sessionID)
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

@MainActor
private struct FailingResetSampleProvider: SampleRecipeProviding {
  struct Failure: Error {}

  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    throw Failure()
  }
}

@MainActor
final class AppLaunchPlanTests: XCTestCase {
  func testBuildEnvironmentPolicyKeepsCloudAndTestHarnessesSeparate() {
    XCTAssertFalse(AppBuildEnvironment.debug.synchronizesWithPersonalCloud)
    XCTAssertTrue(AppBuildEnvironment.develop.synchronizesWithPersonalCloud)
    XCTAssertFalse(AppBuildEnvironment.testing.synchronizesWithPersonalCloud)
    XCTAssertTrue(AppBuildEnvironment.production.synchronizesWithPersonalCloud)
    XCTAssertFalse(AppBuildEnvironment.productionTesting.synchronizesWithPersonalCloud)

    XCTAssertFalse(AppBuildEnvironment.debug.offersCloudSyncSetting)
    XCTAssertTrue(AppBuildEnvironment.develop.offersCloudSyncSetting)
    XCTAssertTrue(AppBuildEnvironment.testing.offersCloudSyncSetting)
    XCTAssertTrue(AppBuildEnvironment.production.offersCloudSyncSetting)
    XCTAssertTrue(AppBuildEnvironment.productionTesting.offersCloudSyncSetting)

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

  func testUITestingProducesOneCoherentDisposableLaunchPlan() throws {
    let plan = try AppLaunchPlan.resolve(
      inputs: inputs(
        arguments: [
          "KitchenMemory",
          "--ui-testing",
          "--ui-testing-cloud-sync-disabled",
        ],
        buildEnvironment: .productionTesting
      ),
      durableCloudSyncIsEnabled: true
    )

    XCTAssertEqual(plan.store, .inMemory)
    XCTAssertEqual(plan.sampleFixture, .installed)
    XCTAssertFalse(plan.cloudSyncIsEnabledAtLaunch)
    XCTAssertTrue(plan.offersCloudSyncSetting)
  }

  func testStartupFailureSimulationIsPartOfTheLaunchPlan() throws {
    let arguments = ["KitchenMemory", "--simulate-startup-failure"]

    XCTAssertTrue(try plan(arguments: arguments, buildEnvironment: .testing)
      .simulatesStartupFailure)
    XCTAssertTrue(try plan(arguments: arguments, buildEnvironment: .productionTesting)
      .simulatesStartupFailure)
    XCTAssertFalse(try plan(arguments: arguments, buildEnvironment: .debug)
      .simulatesStartupFailure)
    XCTAssertFalse(try plan(arguments: arguments, buildEnvironment: .develop)
      .simulatesStartupFailure)
    XCTAssertFalse(try plan(arguments: arguments, buildEnvironment: .production)
      .simulatesStartupFailure)
  }

  func testStartupDelaySimulationIsLimitedToTheUITestHarness() throws {
    let arguments = ["KitchenMemory", "--simulate-startup-delay"]

    XCTAssertTrue(try plan(arguments: arguments, buildEnvironment: .testing)
      .simulatesStartupDelay)
    XCTAssertTrue(try plan(arguments: arguments, buildEnvironment: .productionTesting)
      .simulatesStartupDelay)
    XCTAssertFalse(try plan(arguments: arguments, buildEnvironment: .debug)
      .simulatesStartupDelay)
    XCTAssertFalse(try plan(arguments: arguments, buildEnvironment: .develop)
      .simulatesStartupDelay)
    XCTAssertFalse(try plan(arguments: arguments, buildEnvironment: .production)
      .simulatesStartupDelay)
  }

  func testProductionIgnoresTestingArguments() throws {
    let arguments = [
      "KitchenMemory",
      "--ui-testing",
      "--ui-testing-cloud-sync-disabled",
    ]
    let production = try plan(arguments: arguments, buildEnvironment: .production)

    XCTAssertEqual(
      production.store,
      .personalCloud(containerIdentifier: "iCloud.net.ctwelve.KitchenMemory")
    )
    XCTAssertTrue(production.cloudSyncIsEnabledAtLaunch)
    XCTAssertEqual(production.sampleFixture, .empty)
  }

  func testHostedUnitTestsUseDisposableStorageAndNeverPersonalCloud() throws {
    for buildEnvironment in [AppBuildEnvironment.testing, .productionTesting] {
      let hosted = try AppLaunchPlan.resolve(
        inputs: inputs(
          environment: [
            "XCTestConfigurationFilePath": "/tmp/KitchenMemory.xctestconfiguration",
          ],
          buildEnvironment: buildEnvironment
        ),
        durableCloudSyncIsEnabled: true
      )
      XCTAssertEqual(hosted.store, .inMemory)
      XCTAssertEqual(hosted.sampleFixture, .installed)
    }

    let developHosted = try AppLaunchPlan.resolve(
      inputs: inputs(
        environment: [
          "XCTestConfigurationFilePath": "/tmp/KitchenMemory.xctestconfiguration",
        ],
        buildEnvironment: .develop
      ),
      durableCloudSyncIsEnabled: true
    )
    XCTAssertEqual(developHosted.store, .local)
  }

  func testSavedPlanExposesTheHostedXCTestEnvironment() throws {
    XCTAssertNotNil(ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"])
    XCTAssertEqual(
      try AppLaunchPlan.resolve(
        inputs: .current,
        durableCloudSyncIsEnabled: true
      ).store,
      .inMemory
    )
  }

  func testDisabledCloudPreferenceSelectsTheLocalDurableStore() throws {
    let plan = try AppLaunchPlan.resolve(
      inputs: inputs(buildEnvironment: .production),
      durableCloudSyncIsEnabled: false
    )

    XCTAssertEqual(plan.store, .local)
    XCTAssertFalse(plan.cloudSyncIsEnabledAtLaunch)
  }

  func testPersonalCloudStoreComesFromTheSignedBuildConfiguration() throws {
    XCTAssertEqual(
      try plan(buildEnvironment: .production).store,
      .personalCloud(containerIdentifier: "iCloud.net.ctwelve.KitchenMemory")
    )
    XCTAssertThrowsError(try AppLaunchPlan.resolve(
      inputs: inputs(infoDictionary: [:], buildEnvironment: .develop),
      durableCloudSyncIsEnabled: true
    )) { error in
      XCTAssertEqual(
        error as? AppLaunchPlanError,
        .cloudKitContainerIdentifierMissing
      )
    }
  }

  func testCloudKitSchemaInitializationIsPartOfTheDevelopLaunchPlan() throws {
#if os(macOS)
    XCTAssertTrue(try plan(
      arguments: ["KitchenMemory", "--initialize-cloudkit-schema"],
      buildEnvironment: .develop
    ).initializesCloudKitSchema)
#else
    XCTAssertFalse(try plan(
      arguments: ["KitchenMemory", "--initialize-cloudkit-schema"],
      buildEnvironment: .develop
    ).initializesCloudKitSchema)
#endif
    XCTAssertFalse(try plan(
      arguments: ["KitchenMemory", "--initialize-cloudkit-schema"],
      buildEnvironment: .production
    ).initializesCloudKitSchema)
    XCTAssertFalse(try plan(buildEnvironment: .develop).initializesCloudKitSchema)
  }

  private func plan(
    arguments: [String] = ["KitchenMemory"],
    buildEnvironment: AppBuildEnvironment
  ) throws -> AppLaunchPlan {
    try AppLaunchPlan.resolve(
      inputs: inputs(arguments: arguments, buildEnvironment: buildEnvironment),
      durableCloudSyncIsEnabled: true
    )
  }

  private func inputs(
    arguments: [String] = ["KitchenMemory"],
    environment: [String: String] = [:],
    infoDictionary: [String: Any] = [
      AppLaunchInputs.cloudKitContainerInfoKey: "iCloud.net.ctwelve.KitchenMemory",
    ],
    buildEnvironment: AppBuildEnvironment
  ) -> AppLaunchInputs {
    AppLaunchInputs(
      arguments: arguments,
      environment: environment,
      infoDictionary: infoDictionary,
      buildEnvironment: buildEnvironment
    )
  }
}
