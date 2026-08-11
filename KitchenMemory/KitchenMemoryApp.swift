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
  static let starterKitchen = Kitchen(
    id: .init(rawValue: UUID(uuidString: "B8C29EAC-AB61-4F27-961D-BD2E0D91B0B9")!),
    name: "Home Kitchen"
  )

  let modelContainer: ModelContainer
  let libraryModel: RecipeLibraryModel

  init(inMemory: Bool = false) throws {
    let modelContainer = try KitchenMemorySchema.makeContainer(inMemory: inMemory)
    let repository = SwiftDataRecipeRepository(modelContainer: modelContainer)
    try Self.seedStarterRecipeIfNeeded(repository: repository)

    self.modelContainer = modelContainer
    libraryModel = RecipeLibraryModel(
      kitchenID: Self.starterKitchen.id,
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

  private static func seedStarterRecipeIfNeeded(repository: any RecipeRepository) throws {
    if try repository.kitchen(id: starterKitchen.id) == nil {
      try repository.save(starterKitchen)
    }

    let manifest = try SampleRecipeCatalog.loadManifest()
    for reference in manifest.recipes where try repository.recipe(id: reference.recipeID) == nil {
      let document = try SampleRecipeCatalog.loadRecipe(reference)
      let materialized = try document.materialize(in: starterKitchen.id)
      try repository.save(recipe: materialized.recipe, revision: materialized.revision)
    }
  }
}
