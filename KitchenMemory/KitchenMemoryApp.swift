// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryLogic
import KitchenMemoryPersistence
import SwiftData
import SwiftUI

@main
struct KitchenMemoryApp: App {
  @State private var startupState: AppStartupState

  init() {
    _startupState = State(initialValue: Self.prepareDependencies())
  }

  var body: some Scene {
#if os(macOS)
    WindowGroup {
      applicationContent
    }
    .commands {
      KitchenCommands()
    }

    Settings {
      settingsContent
    }
#else
    WindowGroup {
      applicationContent
    }
#endif
  }

  @ViewBuilder
  private var applicationContent: some View {
    switch startupState {
    case .ready(let dependencies):
      ContentView(model: dependencies.libraryModel)
    case .unavailable:
      KitchenUnavailableView(retry: retryPreparation)
    }
  }

#if os(macOS)
  @ViewBuilder
  private var settingsContent: some View {
    switch startupState {
    case .ready(let dependencies):
      NavigationStack {
        KitchenSettingsView(model: dependencies.libraryModel)
      }
    case .unavailable:
      KitchenUnavailableView(retry: retryPreparation)
    }
  }
#endif

  private func retryPreparation() {
    startupState = Self.prepareDependencies()
  }

  private static func prepareDependencies() -> AppStartupState {
    if AppRuntimeConfiguration.simulatesStartupFailure(
      arguments: ProcessInfo.processInfo.arguments
    ) {
      return .unavailable
    }

    return AppStartupState.prepare {
      let personalCloudContainerIdentifier = try AppRuntimeConfiguration
        .personalCloudContainerIdentifier(
          environment: ProcessInfo.processInfo.environment,
          infoDictionary: Bundle.main.infoDictionary ?? [:]
        )
#if DEVELOP && os(macOS)
      if AppRuntimeConfiguration.initializesCloudKitSchema(
        arguments: ProcessInfo.processInfo.arguments
      ) {
        guard let personalCloudContainerIdentifier else {
          throw AppRuntimeConfigurationError.cloudKitContainerIdentifierMissing
        }
        try CloudKitDevelopmentSchemaInitializer.initialize(
          containerIdentifier: personalCloudContainerIdentifier
        )
      }
#endif
      return try AppDependencies(
        inMemory: AppRuntimeConfiguration.usesInMemoryStore(
          arguments: ProcessInfo.processInfo.arguments
        ),
        personalCloudContainerIdentifier: personalCloudContainerIdentifier
      )
    }
  }
}

enum AppStartupState {
  case ready(AppDependencies)
  case unavailable

  static func prepare(using makeDependencies: () throws -> AppDependencies) -> Self {
    do {
      return .ready(try makeDependencies())
    } catch {
      // Persistence and CloudKit errors can contain local paths or framework
      // identifiers. The 0.1 app has no private diagnostic collection path, so
      // do not interpolate or retain the underlying error merely for logging.
      return .unavailable
    }
  }

  var dependencies: AppDependencies? {
    guard case .ready(let dependencies) = self else { return nil }
    return dependencies
  }
}

enum AppBuildEnvironment: CaseIterable {
  case debug
  case develop
  case testing
  case production
  case productionTesting

  static var current: Self {
#if TESTING && PRODUCTION
    .productionTesting
#elseif TESTING
    .testing
#elseif DEVELOP
    .develop
#elseif PRODUCTION
    .production
#else
    .debug
#endif
  }

  var synchronizesWithPersonalCloud: Bool {
    self == .develop || self == .production
  }

  var permitsUITestHarness: Bool {
    self == .testing || self == .productionTesting
  }

  var permitsCloudKitSchemaAdministration: Bool {
    self == .develop
  }
}

enum AppRuntimeConfiguration {
  static let cloudKitContainerInfoKey = "KitchenMemoryCloudKitContainerIdentifier"

  /// Whether this process may replace durable storage with an in-memory store.
  ///
  /// Automated test hosts need deterministic disposable state. Test-plan and
  /// UI-test launch arguments are also ordinary process input on macOS, so
  /// both switches remain confined to the Testing and non-distributable
  /// ProductionTesting configurations.
  static func usesInMemoryStore(
    arguments: [String],
    buildEnvironment: AppBuildEnvironment = .current
  ) -> Bool {
    buildEnvironment.permitsUITestHarness
      && (arguments.contains("--ui-testing") || arguments.contains("--unit-testing"))
  }

  /// Whether UI automation should present the privacy-safe startup failure.
  ///
  /// This is process input, so it is ignored by every distributable build
  /// configuration even if somebody launches the app with the same argument.
  static func simulatesStartupFailure(
    arguments: [String],
    buildEnvironment: AppBuildEnvironment = .current
  ) -> Bool {
    buildEnvironment.permitsUITestHarness
      && arguments.contains("--simulate-startup-failure")
  }

  /// Whether the host process should attach its durable store to CloudKit.
  ///
  /// Develop and Production attach ordinary launches to personal CloudKit.
  /// Debug, Testing, and ProductionTesting remain local so diagnostics and test
  /// evidence never depend on an iCloud account.
  static func synchronizesWithPersonalCloud(
    environment: [String: String],
    buildEnvironment: AppBuildEnvironment = .current
  ) -> Bool {
    buildEnvironment.synchronizesWithPersonalCloud
      && environment["XCTestConfigurationFilePath"] == nil
  }

  /// Returns the signed build's configured container only when this launch
  /// participates in personal sync.
  ///
  /// The same build setting feeds Info.plist and the code-signing entitlements,
  /// keeping the runtime store from silently selecting a different container
  /// than the one Apple authorized in the signature.
  static func personalCloudContainerIdentifier(
    environment: [String: String],
    infoDictionary: [String: Any],
    buildEnvironment: AppBuildEnvironment = .current
  ) throws -> String? {
    guard synchronizesWithPersonalCloud(
      environment: environment,
      buildEnvironment: buildEnvironment
    ) else { return nil }
    guard let identifier = infoDictionary[cloudKitContainerInfoKey] as? String,
          identifier.hasPrefix("iCloud."),
          identifier.count > "iCloud.".count else {
      throw AppRuntimeConfigurationError.cloudKitContainerIdentifierMissing
    }
    return identifier
  }

  static func initializesCloudKitSchema(
    arguments: [String],
    buildEnvironment: AppBuildEnvironment = .current
  ) -> Bool {
#if os(macOS)
    buildEnvironment.permitsCloudKitSchemaAdministration
      && arguments.contains("--initialize-cloudkit-schema")
#else
    false
#endif
  }
}

enum AppRuntimeConfigurationError: Error, Equatable {
  case cloudKitContainerIdentifierMissing
}

@MainActor
struct AppDependencies {
  let modelContainer: ModelContainer
  let libraryModel: RecipeLibraryModel
  let persistentStoreChangeObserver: PersistentStoreChangeObserver?
  let personalCloudStatusMonitor: PersonalCloudStatusMonitor?

  init(
    inMemory: Bool = false,
    personalCloudContainerIdentifier: String? = nil,
    sampleOnboardingStore: (any SampleRecipeOnboardingStoring)? = nil,
    sampleProvider: (any SampleRecipeProviding)? = nil,
    initialKitchenWasCreatedOverride: Bool? = nil
  ) throws {
    let synchronization = Self.storeSynchronization(
      personalCloudContainerIdentifier: personalCloudContainerIdentifier
    )
    let modelContainer = try KitchenMemorySchema.makeContainer(
      inMemory: inMemory,
      synchronization: synchronization
    )
    let repository = SwiftDataRecipeRepository(modelContainer: modelContainer)
    let samples = sampleProvider ?? BundledSampleRecipeProvider()
    let preparedKitchen = try KitchenBootstrapService(repository: repository)
      .prepareInitialKitchenWithStatus()
    let kitchen = preparedKitchen.kitchen
    let onboardingStore = sampleOnboardingStore ?? Self.defaultOnboardingStore(
      inMemory: inMemory,
      synchronizesWithPersonalCloud: personalCloudContainerIdentifier != nil
    )
    let sampleInstaller = SampleRecipeInstallService(repository: repository, samples: samples)

    // Disposable previews and UI smoke tests request a ready-made fixture.
    // Durable launches never infer installation permission from this path.
    if inMemory, sampleOnboardingStore == nil {
      try sampleInstaller.install(in: kitchen.id)
    }

    let libraryModel = RecipeLibraryModel(
      kitchenID: kitchen.id,
      library: RecipeLibrary(repository: repository),
      editor: RecipeEditor(repository: repository),
      importer: RecipeImportService(),
      resetService: KitchenResetService(repository: repository, samples: samples),
      sampleInstaller: sampleInstaller,
      sampleOnboardingStore: onboardingStore,
      kitchenWasCreated: initialKitchenWasCreatedOverride ?? preparedKitchen.wasCreated
    )
    self.modelContainer = modelContainer
    self.libraryModel = libraryModel
    persistentStoreChangeObserver = personalCloudContainerIdentifier != nil
      ? PersistentStoreChangeObserver {
        libraryModel.reloadAfterExternalStoreChange()
      }
      : nil
    let personalCloudStatusMonitor = personalCloudContainerIdentifier.map { containerIdentifier in
      PersonalCloudStatusMonitor(
        accountChecker: CloudKitAccountChecker(
          containerIdentifier: containerIdentifier
        )
      ) { status in
        libraryModel.updatePersonalCloudStatus(status)
      }
    }
    self.personalCloudStatusMonitor = personalCloudStatusMonitor
    personalCloudStatusMonitor?.start()
  }

  static var preview: AppDependencies {
    do {
      return try AppDependencies(inMemory: true)
    } catch {
      fatalError("Could not prepare the Kitchen Memory preview: \(error)")
    }
  }

  static func prepareInitialKitchen(repository: any RecipeRepository) throws -> Kitchen {
    try KitchenBootstrapService(repository: repository).prepareInitialKitchen()
  }

  private static func storeSynchronization(
    personalCloudContainerIdentifier: String?
  ) -> KitchenMemoryStoreSynchronization {
    guard let personalCloudContainerIdentifier else { return .localOnly }
    return .personalCloud(containerIdentifier: personalCloudContainerIdentifier)
  }

  private static func defaultOnboardingStore(
    inMemory: Bool,
    synchronizesWithPersonalCloud: Bool
  ) -> any SampleRecipeOnboardingStoring {
    if inMemory { return VolatileSampleRecipeOnboardingStore(response: .accepted) }
    return synchronizesWithPersonalCloud
      ? UbiquitousSampleRecipeOnboardingStore()
      : UserDefaultsSampleRecipeOnboardingStore()
  }
}
