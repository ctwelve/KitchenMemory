// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryApplication
import KitchenMemoryDomain
import KitchenMemoryPersistence
import KitchenMemorySampleData
import SwiftData
import SwiftUI

/// The main entry point for the Kitchen Memory application.
///
/// This type conforms to `App` and is annotated with `@main`, allowing SwiftUI to
/// bootstrap the application. It is responsible for:
/// - Creating and holding the core application dependencies via `AppDependencies`.
/// - Configuring in-memory storage when launched with the `--ui-testing` argument
///   to ensure a clean, ephemeral data store for UI tests and previews.
/// - Wiring the root SwiftUI view (`ContentView`) to the domain models that back
///   the UI (`RecipeLibraryModel`).
///
/// Behavior:
/// - On initialization, attempts to construct `AppDependencies`. If this fails,
///   the app terminates with a fatal error since the application cannot function
///   without its core services.
/// - In the scene body, presents a single `WindowGroup` that hosts `ContentView`,
///   injecting the library model created from the repository and model container.
///
/// Notes:
/// - Persistent storage is provided by SwiftData via `AppDependencies`.
/// - UI tests can opt into an in-memory store by launching with `--ui-testing`.
@main
struct KitchenMemoryApp: App {
  private let dependencies: AppDependencies

    /// Initializes the Kitchen Memory application and configures core dependencies.
    ///
    /// This initializer constructs the shared `AppDependencies` used throughout the app,
    /// including the SwiftData model container, repository, and top-level UI models.
    /// It also detects when the app is launched for UI testing and switches persistence
    /// to an in-memory store to ensure a clean, ephemeral data set for each test run.
    ///
    /// Behavior:
    /// - If the process arguments contain `--ui-testing`, an in-memory SwiftData store
    ///   is created to avoid persisting test data.
    /// - Otherwise, a normal on-disk store is used for persistent application data.
    /// - If dependency setup fails, the app terminates via `fatalError`, as the app
    ///   cannot function without its core services.
    ///
    /// Notes:
    /// - This is called once at app launch by SwiftUI’s lifecycle.
    /// - The resulting dependencies are retained for the lifetime of the app.
  init() {
    do {
      dependencies = try AppDependencies(
        inMemory: ProcessInfo.processInfo.arguments.contains("--ui-testing")
      )
    } catch {
      fatalError("Could not prepare Kitchen Memory: \(error)")
    }
  }

    /// The scene hierarchy for Kitchen Memory’s SwiftUI app lifecycle.
    ///
    /// This property defines the app’s window content and is invoked by the system
    /// to construct the UI. It returns a single WindowGroup that hosts the root
    /// ContentView and injects the shared RecipeLibraryModel sourced from
    /// AppDependencies.
    ///
    /// Behavior:
    /// - Creates a single-window scene via WindowGroup.
    /// - Supplies ContentView with the preconfigured library model so it can drive
    ///   browsing, searching, and editing recipes.
    /// - Inherits the SwiftData model container and other services indirectly via the
    ///   injected models.
    ///
    /// Threading:
    /// - Evaluated on the main actor as part of SwiftUI’s rendering pipeline.
    ///
    /// Testing and previews:
    /// - When launched with the “--ui-testing” argument, the dependencies backing
    ///   this scene use an in-memory store to ensure a clean, ephemeral dataset.
    ///
    /// See also:
    /// - AppDependencies for how the model container and repository are constructed.
    /// - ContentView for the root UI that renders the recipe library.
  var body: some Scene {
    WindowGroup {
      ContentView(model: dependencies.libraryModel)
    }
  }
}

/// A container for the core, long‑lived services and models that power Kitchen Memory’s UI.
///
/// AppDependencies is created once at application startup and wires together:
/// - A SwiftData `ModelContainer` configured with the Kitchen Memory schema.
/// - A `RecipeRepository` backed by SwiftData for all data access.
/// - The high‑level `RecipeLibraryModel` used by the root UI to browse and edit recipes.
///
/// Use the throwing initializer to configure persistence:
/// - Pass `inMemory: true` for previews and UI tests (data is ephemeral).
/// - Pass `inMemory: false` for normal on‑disk persistence.
///
/// Responsibilities:
/// - Build and hold the SwiftData model container.
/// - Ensure a local “Kitchen” exists, creating and seeding one with sample data on first run.
/// - Expose a ready‑to‑use `RecipeLibraryModel` bound to the repository and initial kitchen.
///
/// Threading:
/// - Marked `@MainActor` because it constructs and exposes UI‑consumed models.
///
/// Preview support:
/// - `preview` provides a convenient, in‑memory instance suitable for SwiftUI previews.
///
/// Errors:
/// - Initialization throws if the model container cannot be created or initial data preparation fails.
///
/// See also:
/// - `KitchenMemorySchema.makeContainer(inMemory:)` for container creation.
/// - `prepareInitialKitchen(repository:)` for initial kitchen creation and sample seeding.
@MainActor
struct AppDependencies {
  let modelContainer: ModelContainer
  let libraryModel: RecipeLibraryModel

    /// Creates the application’s core dependencies, including the SwiftData model container and
    /// the high-level models used by the UI.
    ///
    /// This initializer is responsible for:
    /// - Building a SwiftData `ModelContainer` using the Kitchen Memory schema.
    /// - Creating a `RecipeRepository` backed by SwiftData.
    /// - Ensuring there is a local Kitchen to work with (creating and seeding one if needed).
    /// - Wiring up the `RecipeLibraryModel` that powers the main UI.
    ///
    /// Use the `inMemory` flag to control persistence behavior:
    /// - Pass `true` to create an in-memory store suitable for previews and UI tests. Data will
    ///   not persist across launches.
    /// - Pass `false` to use the on-disk store for normal application use.
    ///
    /// - Parameter inMemory: Whether to use an in-memory SwiftData store instead of persistent storage.
    /// - Throws: An error if the model container cannot be created, if the repository cannot be set up,
    ///   or if preparing the initial Kitchen or sample data fails.
  init(inMemory: Bool = false) throws {
    let modelContainer = try KitchenMemorySchema.makeContainer(inMemory: inMemory)
    let repository = SwiftDataRecipeRepository(modelContainer: modelContainer)
    let kitchen = try Self.prepareInitialKitchen(repository: repository)

    self.modelContainer = modelContainer
    libraryModel = RecipeLibraryModel(
      kitchenID: kitchen.id,
      library: RecipeLibrary(repository: repository),
      editor: RecipeEditor(repository: repository)
    )
  }

    /// A convenience instance of `AppDependencies` configured for SwiftUI previews.
    ///
    /// This property constructs an in-memory model container and seeds it with sample data,
    /// providing a lightweight, disposable environment ideal for Xcode previews. Because
    /// the store is ephemeral, changes made while rendering previews do not persist across
    /// preview reloads.
    ///
    /// Behavior:
    /// - Uses `inMemory: true` to avoid writing to disk.
    /// - Crashes the preview session via `fatalError` if setup fails, surfacing configuration
    ///   issues early during development.
    ///
    /// Use this property to supply dependencies to previewed views without affecting the
    /// on-disk application data.
  static var preview: AppDependencies {
    do {
      return try AppDependencies(inMemory: true)
    } catch {
      fatalError("Could not prepare the Kitchen Memory preview: \(error)")
    }
  }

    /// Opens or initializes the local Kitchen for this installation and ensures starter data exists.
    ///
    /// This method provides the app’s initial working context by either:
    /// - Returning the first existing `Kitchen` found in persistent storage, or
    /// - Creating a new “Home Kitchen”, saving it, and seeding it with sample recipes
    ///   the first time the app runs (or when using an empty in‑memory store).
    ///
    /// Seeding behavior:
    /// - Loads the sample recipe catalog manifest via `SampleRecipeCatalog.loadManifest()`.
    /// - For each recipe reference, loads the corresponding document and materializes it
    ///   into the newly created kitchen, then saves both the recipe and its initial revision.
    /// - Sample recipe identities are provided by the sample pack so that future links
    ///   or imports can recognize the same starter recipes and avoid duplicates.
    ///
    /// Threading:
    /// - Synchronous and throwing; call from an appropriate context (typically the main
    ///   actor during app setup) before presenting UI that depends on a kitchen.
    ///
    /// - Parameter repository: A `RecipeRepository` used to query, create, and persist kitchens
    ///   and recipes.
    /// - Returns: The existing local `Kitchen` if present, otherwise the newly created and
    ///   seeded “Home Kitchen”.
    /// - Throws: Any error encountered while querying kitchens, creating/saving the kitchen,
    ///   loading the sample manifest or recipe documents, materializing sample data, or
    ///   saving recipes and their revisions.
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
