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
#if DEBUG
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

enum AppRuntimeConfiguration {
  /// Whether this process may replace durable storage with an in-memory store.
  ///
  /// UI automation needs deterministic disposable state, but launch arguments
  /// are also ordinary process input on macOS. A production app must never let
  /// an argument make entered or imported recipes appear to save and then
  /// vanish at process exit. Compile the switch out of Release rather than
  /// relying on callers to avoid an undocumented flag.
  static func usesInMemoryStore(arguments: [String]) -> Bool {
#if DEBUG
    arguments.contains("--ui-testing")
#else
    false
#endif
  }

  /// Whether the host process should attach its durable store to CloudKit.
  ///
  /// Hosted unit tests execute the app's `init` before XCTest connects. They
  /// deliberately use the local store because unsigned CI and coverage runs do
  /// not carry the application's iCloud entitlement. Normal Debug and Release
  /// launches still select personal sync.
  static func synchronizesWithPersonalCloud(environment: [String: String]) -> Bool {
#if DEBUG
    environment["XCTestConfigurationFilePath"] == nil
#else
    true
#endif
  }

#if DEBUG
  static func initializesCloudKitSchema(arguments: [String]) -> Bool {
    arguments.contains("--initialize-cloudkit-schema")
  }
#endif
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
