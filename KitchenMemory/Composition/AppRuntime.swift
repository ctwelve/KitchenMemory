// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import SwiftData

enum AppLaunchPlanError: Error, Equatable {
  case cloudKitContainerIdentifierMissing
  case simulatedStartupFailure
}

struct AppLaunchInputs {
  static let cloudKitContainerInfoKey = "KitchenMemoryCloudKitContainerIdentifier"

  var arguments: [String]
  var environment: [String: String]
  var infoDictionary: [String: Any]
  var buildEnvironment: AppBuildEnvironment

  static var current: Self {
    AppLaunchInputs(
      arguments: ProcessInfo.processInfo.arguments,
      environment: ProcessInfo.processInfo.environment,
      infoDictionary: Bundle.main.infoDictionary ?? [:],
      buildEnvironment: .current
    )
  }
}

struct AppLaunchPlan: Equatable {
  enum Store: Equatable {
    case inMemory
    case local
    case personalCloud(containerIdentifier: String)

    var isInMemory: Bool {
      self == .inMemory
    }

    var personalCloudContainerIdentifier: String? {
      guard case .personalCloud(let containerIdentifier) = self else { return nil }
      return containerIdentifier
    }

    var synchronization: KitchenMemoryStoreSynchronization {
      guard let personalCloudContainerIdentifier else { return .localOnly }
      return .personalCloud(containerIdentifier: personalCloudContainerIdentifier)
    }
  }

  enum SampleFixture: Equatable {
    case empty
    case installed
  }

  var store: Store
  var sampleFixture: SampleFixture
  var cloudSyncIsEnabledAtLaunch: Bool
  var offersCloudSyncSetting: Bool
  var initializesCloudKitSchema: Bool
  var simulatesStartupFailure: Bool
  var simulatesStartupDelay: Bool

  static func resolve(
    inputs: AppLaunchInputs,
    durableCloudSyncIsEnabled: Bool
  ) throws -> Self {
    let usesTestHarness = inputs.buildEnvironment.permitsUITestHarness
    // The saved platform plans do not inject the former --unit-testing
    // argument. A hosted XCTest process does provide this path, so testing
    // builds still select disposable storage without plan-specific arguments.
    let usesHostedUnitTests = inputs.environment["XCTestConfigurationFilePath"] != nil
    let usesInMemoryStore = usesTestHarness
      && (inputs.arguments.contains("--ui-testing")
        || inputs.arguments.contains("--unit-testing")
        || usesHostedUnitTests)
    let disablesCloudForUITest = usesTestHarness
      && inputs.arguments.contains("--ui-testing")
      && inputs.arguments.contains("--ui-testing-cloud-sync-disabled")
    let cloudSyncIsEnabled = disablesCloudForUITest ? false : durableCloudSyncIsEnabled
    let synchronizesWithPersonalCloud = cloudSyncIsEnabled
      && inputs.buildEnvironment.synchronizesWithPersonalCloud
      && !usesHostedUnitTests
    let store: Store
    if usesInMemoryStore {
      store = .inMemory
    } else if synchronizesWithPersonalCloud {
      guard let identifier = inputs.infoDictionary[AppLaunchInputs.cloudKitContainerInfoKey]
        as? String,
        identifier.hasPrefix("iCloud."),
        identifier.count > "iCloud.".count else {
        throw AppLaunchPlanError.cloudKitContainerIdentifierMissing
      }
      store = .personalCloud(containerIdentifier: identifier)
    } else {
      store = .local
    }

    let initializesCloudKitSchema: Bool
#if os(macOS)
    initializesCloudKitSchema = inputs.buildEnvironment.permitsCloudKitSchemaAdministration
      && inputs.arguments.contains("--initialize-cloudkit-schema")
#else
    initializesCloudKitSchema = false
#endif

    return AppLaunchPlan(
      store: store,
      sampleFixture: usesInMemoryStore ? .installed : .empty,
      cloudSyncIsEnabledAtLaunch: cloudSyncIsEnabled,
      offersCloudSyncSetting: inputs.buildEnvironment.offersCloudSyncSetting,
      initializesCloudKitSchema: initializesCloudKitSchema,
      simulatesStartupFailure: usesTestHarness
        && inputs.arguments.contains("--simulate-startup-failure"),
      simulatesStartupDelay: usesTestHarness
        && inputs.arguments.contains("--simulate-startup-delay")
    )
  }
}

/// Builds the application dependency graph from launch policy and platform state.
///
/// This is the composition root: it selects the store, establishes the personal
/// Kitchen, and connects KitchenKit services to application-owned presentation
/// models. UI code should consume ``PreparedApp`` instead of assembling partial
/// graphs of its own.
@MainActor
enum AppRuntime {
  struct TestingConfiguration {
    var library: AppLaunchPlan.SampleFixture = .installed
    var preferencesStore: (any KitchenPreferencesStoring)?
    var sampleProvider: (any SampleRecipeProviding)?
    var initialKitchenWasCreatedOverride: Bool?
    var sessionPresentationStore: (any CookingSessionPresentationStoring)?
  }

  static func prepare() async -> AppStartupState {
    await AppStartupState.prepare {
      let inputs = AppLaunchInputs.current
      let durablePreferences = DefaultsKitchenPreferencesStore(
        permitsPersonalPreferencesICloud:
          inputs.buildEnvironment.synchronizesWithPersonalCloud
      )
      let plan = try AppLaunchPlan.resolve(
        inputs: inputs,
        durableCloudSyncIsEnabled:
          durablePreferences.personalCloudSynchronizationEnabled
      )
      if plan.simulatesStartupDelay {
        try await Task.sleep(for: .seconds(8))
      }
      guard !plan.simulatesStartupFailure else {
        throw AppLaunchPlanError.simulatedStartupFailure
      }
      let preferences: any KitchenPreferencesStoring = plan.store.isInMemory
        ? VolatileKitchenPreferencesStore(
          sampleRecipeOnboardingResponse: .accepted,
          personalCloudSynchronizationEnabled: plan.cloudSyncIsEnabledAtLaunch
        )
        : durablePreferences
      try initializeCloudKitSchemaIfRequested(plan: plan)
      let ownerID = try await KitchenOwnerIdentity.resolve(plan: plan, inputs: inputs)
      return try PreparedApp(
        plan: plan,
        ownerID: ownerID,
        preferences: preferences,
        samples: BundledSampleRecipeProvider(),
        sessionPresentationStore: plan.store.isInMemory
          ? VolatileCookingSessionPresentationStore()
          : DefaultsCookingSessionPresentationStore()
      )
    }
  }

  static func testing(
    _ configuration: TestingConfiguration = TestingConfiguration()
  ) throws -> PreparedApp {
    let preferences = configuration.preferencesStore
      ?? VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted)
    let plan = AppLaunchPlan(
      store: .inMemory,
      sampleFixture: configuration.library,
      cloudSyncIsEnabledAtLaunch: preferences.personalCloudSynchronizationEnabled,
      offersCloudSyncSetting: false,
      initializesCloudKitSchema: false,
      simulatesStartupFailure: false,
      simulatesStartupDelay: false
    )
    return try PreparedApp(
      plan: plan,
      ownerID: KitchenOwner.ID(rawValue: "testing:personal-kitchen-owner"),
      preferences: preferences,
      samples: configuration.sampleProvider ?? BundledSampleRecipeProvider(),
      initialKitchenWasCreatedOverride:
        configuration.initialKitchenWasCreatedOverride,
      sessionPresentationStore: configuration.sessionPresentationStore
        ?? VolatileCookingSessionPresentationStore()
    )
  }

  private static func initializeCloudKitSchemaIfRequested(
    plan: AppLaunchPlan
  ) throws {
#if DEVELOP && os(macOS)
    guard plan.initializesCloudKitSchema else { return }
    guard let containerIdentifier = plan.store.personalCloudContainerIdentifier else {
      throw AppLaunchPlanError.cloudKitContainerIdentifierMissing
    }
    try CloudKitDevelopmentSchemaInitializer.initialize(
      containerIdentifier: containerIdentifier
    )
#endif
  }

}

@MainActor
struct PreparedCore {
  let modelContainer: ModelContainer
  let libraryModel: RecipeLibraryModel
  let cookingSessionRepository: SwiftDataCookingSessionRepository
  let cookingSessions: CookingSessions
  let recipeRepository: SwiftDataRecipeRepository
  let ownerID: KitchenOwner.ID

  init(
    plan: AppLaunchPlan,
    ownerID: KitchenOwner.ID,
    preferences: any KitchenPreferencesStoring,
    samples: any SampleRecipeProviding,
    initialKitchenWasCreatedOverride: Bool?
  ) throws {
    modelContainer = try KitchenMemorySchema.makeContainer(
      inMemory: plan.store.isInMemory,
      synchronization: plan.store.synchronization
    )
    recipeRepository = SwiftDataRecipeRepository(modelContainer: modelContainer)
    self.ownerID = ownerID
    let preparedKitchen = try KitchenBootstrapService(repository: recipeRepository)
      .prepareInitialKitchenWithStatus(ownerID: ownerID)
    let library = RecipeLibrary(
      kitchenID: preparedKitchen.kitchen.id,
      repository: recipeRepository,
      samples: samples,
      importer: RecipeImportService(),
      resetRepository: SwiftDataKitchenResetRepository(modelContainer: modelContainer)
    )
    if plan.sampleFixture == .installed { try library.installSamples() }
    libraryModel = RecipeLibraryModel(
      library: library,
      samplePreferences: preferences,
      kitchenWasCreated: initialKitchenWasCreatedOverride ?? preparedKitchen.wasCreated
    )
    cookingSessionRepository = SwiftDataCookingSessionRepository(
      modelContainer: modelContainer
    )
    cookingSessions = CookingSessions(
      kitchenID: preparedKitchen.kitchen.id,
      recipeRepository: recipeRepository,
      sessionRepository: cookingSessionRepository
    )
  }
}

/// The complete dependency graph consumed by the prepared application shell.
///
/// It retains the model container and adapters for their required lifetimes and
/// exposes the recipe-library and Cooking Session presentation models used by
/// feature views. External-store notifications re-enter the graph here so both
/// projections refresh from one ownership-reconciled boundary.
@MainActor
struct PreparedApp {
  let modelContainer: ModelContainer
  let libraryModel: RecipeLibraryModel
  let cookingSessionRepository: SwiftDataCookingSessionRepository
  let cookingSessions: CookingSessions
  let recipeRepository: SwiftDataRecipeRepository
  let ownerID: KitchenOwner.ID
  let sessionModel: CookingSessionPresentationModel
  let persistentStoreChangeObserver: PersistentStoreChangeObserver?
  let personalCloudStatusMonitor: PersonalCloudStatusMonitor?
  let cloudSyncSettings: CloudSyncSettings?

  init(
    plan: AppLaunchPlan,
    ownerID: KitchenOwner.ID,
    preferences: any KitchenPreferencesStoring,
    samples: any SampleRecipeProviding,
    initialKitchenWasCreatedOverride: Bool? = nil,
    sessionPresentationStore: any CookingSessionPresentationStoring
  ) throws {
    let core = try PreparedCore(
      plan: plan,
      ownerID: ownerID,
      preferences: preferences,
      samples: samples,
      initialKitchenWasCreatedOverride: initialKitchenWasCreatedOverride
    )
    let sessionModel = CookingSessionPresentationModel(
      sessions: core.cookingSessions,
      store: sessionPresentationStore
    )
    let sessionRepository = core.cookingSessionRepository
    core.libraryModel.installResetPresentationHandler {
      sessionRepository.refreshFromPersistentStore()
      sessionModel.resetAfterKitchenReset()
    }
    modelContainer = core.modelContainer
    libraryModel = core.libraryModel
    cookingSessionRepository = core.cookingSessionRepository
    cookingSessions = core.cookingSessions
    recipeRepository = core.recipeRepository
    self.ownerID = core.ownerID
    self.sessionModel = sessionModel
    cloudSyncSettings = plan.offersCloudSyncSetting
      ? CloudSyncSettings(
        preference: preferences,
        isEnabledAtLaunch: plan.cloudSyncIsEnabledAtLaunch
      )
      : nil
    persistentStoreChangeObserver = makePersistentStoreChangeObserver(
      plan: plan,
      core: core,
      sessionModel: sessionModel
    )
    let personalCloudStatusMonitor = plan.store.personalCloudContainerIdentifier.map { containerIdentifier in
      PersonalCloudStatusMonitor(
        accountChecker: CloudKitAccountChecker(
          containerIdentifier: containerIdentifier
        )
      ) { status in
        core.libraryModel.updatePersonalCloudStatus(status)
      }
    }
    self.personalCloudStatusMonitor = personalCloudStatusMonitor
    personalCloudStatusMonitor?.start()
  }

  func reloadAfterExternalStoreChange() {
    guard (try? reconcileKitchenOwnership(repository: recipeRepository, ownerID: ownerID)) != nil else {
      return
    }
    performExternalStoreRefresh(
      libraryModel: libraryModel,
      sessionRepository: cookingSessionRepository,
      sessionModel: sessionModel
    )
  }

  static var preview: PreparedApp {
    do {
      return try AppRuntime.testing()
    } catch {
      fatalError("Could not prepare the Kitchen Memory preview: \(error)")
    }
  }
}
