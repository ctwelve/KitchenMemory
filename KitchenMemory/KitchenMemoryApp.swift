// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryApplication
import KitchenMemoryDomain
import KitchenMemoryPersistence
import KitchenMemorySampleData
import SwiftData
import SwiftUI

@main
struct KitchenMemoryApp: App {
  private let dependencies: AppDependencies

  init() {
    do {
      dependencies = try AppDependencies(
        inMemory: ProcessInfo.processInfo.arguments.contains("--ui-testing")
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
      library: RecipeLibrary(repository: repository)
    )
  }

  static var preview: AppDependencies {
    do {
      return try AppDependencies(inMemory: true)
    } catch {
      fatalError("Could not prepare the Kitchen Memory preview: \(error)")
    }
  }

  /// Opens the existing local kitchen, or creates and seeds one new install.
  ///
  /// A Kitchen identity belongs to an installation, so it is generated when a
  /// new store has no kitchens. Sample recipe identities are deliberately
  /// supplied by the sample pack: a later linked Kitchen can recognize the
  /// same starter recipe instead of accumulating duplicate Hotdishes.
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
