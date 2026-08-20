// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryPersistence
import SwiftData
import SwiftUI

@main
struct KitchenMemoryApp: App {
  private let dependencies: AppDependencies

  init() {
    do {
      dependencies = try AppDependencies(
        inMemory: AppRuntimeConfiguration.usesInMemoryStore(
          arguments: ProcessInfo.processInfo.arguments
        )
      )
    } catch {
      fatalError("Could not prepare Kitchen Memory: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView(model: dependencies.libraryModel)
    }
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
}

@MainActor
struct AppDependencies {
  let modelContainer: ModelContainer
  let libraryModel: RecipeLibraryModel

  init(inMemory: Bool = false) throws {
    let modelContainer = try KitchenMemorySchema.makeContainer(inMemory: inMemory)
    let repository = SwiftDataRecipeRepository(modelContainer: modelContainer)
    let kitchen = try Self.prepareInitialKitchen(repository: repository)

    self.modelContainer = modelContainer
    libraryModel = RecipeLibraryModel(
      kitchenID: kitchen.id,
      library: RecipeLibrary(repository: repository),
      editor: RecipeEditor(repository: repository),
      importer: RecipeImportService()
    )
  }

  static var preview: AppDependencies {
    do {
      return try AppDependencies(inMemory: true)
    } catch {
      fatalError("Could not prepare the Kitchen Memory preview: \(error)")
    }
  }

  static func prepareInitialKitchen(repository: any RecipeRepository) throws -> Kitchen {
    if let existingKitchen = try repository.kitchens().first {
      return existingKitchen
    }

    let kitchen = Kitchen(name: "Home Kitchen")
    try repository.save(kitchen)

    let manifest = try SampleRecipeCatalog.loadManifest()
    for reference in manifest.recipes {
      let document = try SampleRecipeCatalog.loadRecipe(reference)
      let materialized = try document.materialize(in: kitchen.id)
      try repository.save(recipe: materialized.recipe, revision: materialized.revision)
    }
    return kitchen
  }
}
