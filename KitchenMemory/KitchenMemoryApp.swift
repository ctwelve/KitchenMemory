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
  private let dependencies: AppDependencies

  init() {
    do {
#if DEVELOP
      if AppRuntimeConfiguration.initializesCloudKitSchema(
        arguments: ProcessInfo.processInfo.arguments
      ) {
        try CloudKitDevelopmentSchemaInitializer.initialize()
      }
#endif
      dependencies = try AppDependencies(
        inMemory: AppRuntimeConfiguration.usesInMemoryStore(
          arguments: ProcessInfo.processInfo.arguments
        ),
        synchronizesWithPersonalCloud: AppRuntimeConfiguration.synchronizesWithPersonalCloud(
          environment: ProcessInfo.processInfo.environment
        )
      )
    } catch {
      fatalError("Could not prepare Kitchen Memory: \(error)")
    }
  }

  var body: some Scene {
#if os(macOS)
    WindowGroup {
      ContentView(model: dependencies.libraryModel)
    }
    .commands {
      KitchenCommands()
    }

    Settings {
      KitchenSettingsView(model: dependencies.libraryModel)
    }
#else
    WindowGroup {
      ContentView(model: dependencies.libraryModel)
    }
#endif
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
  /// Whether this process may replace durable storage with an in-memory store.
  ///
  /// UI automation needs deterministic disposable state, but launch arguments
  /// are also ordinary process input on macOS. The switch exists only in the
  /// Testing and non-distributable ProductionTesting configurations.
  static func usesInMemoryStore(
    arguments: [String],
    buildEnvironment: AppBuildEnvironment = .current
  ) -> Bool {
    buildEnvironment.permitsUITestHarness && arguments.contains("--ui-testing")
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

  static func initializesCloudKitSchema(
    arguments: [String],
    buildEnvironment: AppBuildEnvironment = .current
  ) -> Bool {
    buildEnvironment.permitsCloudKitSchemaAdministration
      && arguments.contains("--initialize-cloudkit-schema")
  }
}

@MainActor
struct AppDependencies {
  let modelContainer: ModelContainer
  let libraryModel: RecipeLibraryModel
  let persistentStoreChangeObserver: PersistentStoreChangeObserver?
  let personalCloudStatusMonitor: PersonalCloudStatusMonitor?

  init(
    inMemory: Bool = false,
    synchronizesWithPersonalCloud: Bool = false,
    sampleOnboardingStore: (any SampleRecipeOnboardingStoring)? = nil,
    sampleProvider: (any SampleRecipeProviding)? = nil
  ) throws {
    let synchronization: KitchenMemoryStoreSynchronization = synchronizesWithPersonalCloud
      ? .personalCloud(containerIdentifier: KitchenMemorySchema.personalCloudContainerIdentifier)
      : .localOnly
    let modelContainer = try KitchenMemorySchema.makeContainer(
      inMemory: inMemory,
      synchronization: synchronization
    )
    let repository = SwiftDataRecipeRepository(modelContainer: modelContainer)
    let samples = sampleProvider ?? BundledSampleRecipeProvider()
    let kitchen = try KitchenBootstrapService(repository: repository).prepareInitialKitchen()
    let onboardingStore = sampleOnboardingStore ?? Self.defaultOnboardingStore(inMemory: inMemory)
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
      sampleOnboardingStore: onboardingStore
    )
    self.modelContainer = modelContainer
    self.libraryModel = libraryModel
    persistentStoreChangeObserver = synchronizesWithPersonalCloud
      ? PersistentStoreChangeObserver {
        libraryModel.reloadAfterExternalStoreChange()
      }
      : nil
    let personalCloudStatusMonitor = synchronizesWithPersonalCloud
      ? PersonalCloudStatusMonitor(
        accountChecker: CloudKitAccountChecker(
          containerIdentifier: KitchenMemorySchema.personalCloudContainerIdentifier
        )
      ) { status in
        libraryModel.updatePersonalCloudStatus(status)
      }
      : nil
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

  private static func defaultOnboardingStore(
    inMemory: Bool
  ) -> any SampleRecipeOnboardingStoring {
    inMemory
      ? VolatileSampleRecipeOnboardingStore(response: .accepted)
      : UserDefaultsSampleRecipeOnboardingStore()
  }
}
