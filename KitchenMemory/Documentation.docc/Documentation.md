# ``KitchenMemory``

The native application that composes KitchenKit into a private, local-first
recipe library and cooking companion.

## Overview

KitchenMemory is the presentation and application-composition layer. It owns
the SwiftUI experience, platform adapters, preferences, localized resources,
and bundled sample content. Presentation-independent concepts and product
operations live in the `KitchenKit` framework.

For a first safari through the source, follow the runtime from
``KitchenMemoryApp`` to ``AppStartupCoordinator``, then through ``AppRuntime``
to ``PreparedApp``. Once preparation succeeds, ``ContentView`` presents two
observable projections: ``RecipeLibraryModel`` for maintained recipes and
``CookingSessionPresentationModel`` for cooking activity and history.

```text
KitchenMemoryApp
└── AppStartupCoordinator
    └── AppRuntime
        └── PreparedApp
            ├── RecipeLibraryModel
            └── CookingSessionPresentationModel
```

Views should translate these projections into native presentation. They should
not reconstruct domain truth, coordinate persistence transactions, or infer
Cooking Session lifecycle from process state.

## Topics

### Start Here

- ``KitchenMemoryApp``
- ``AppStartupCoordinator``
- ``AppRuntime``
- ``PreparedApp``
- ``ContentView``

### Feature Projections

- ``RecipeLibraryModel``
- ``CookingSessionPresentationModel``

### Application Resources and Preferences

- ``BundledSampleRecipeProvider``
- ``KitchenPreferencesStoring``
- ``DefaultsKitchenPreferencesStore``
