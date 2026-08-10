# KitchenMemoryDomain

`KitchenMemoryDomain` contains Kitchen Memory concepts and rules without
SwiftData, CloudKit, or user-interface dependencies.

The package currently exposes two library products:

- `KitchenMemoryDomain` — persistence-independent domain values.
- `KitchenMemorySampleData` — deterministic sample resources and their loader.

## Sample resources

Sample content belongs in
`Sources/KitchenMemorySampleData/Resources/SampleRecipes.xcassets`. Keep the
catalog separate from the application's visual assets.

`SampleManifest.dataset` is the versioned index. Recipe data sets and image sets
will use pre-generated stable identifiers so importing the catalog into a fresh
store is repeatable and can be made idempotent.

The loader first uses `NSDataAsset` when Xcode compiles the catalog. It also
supports SwiftPM's command-line behavior, which copies the catalog source into
the package resource bundle during `swift test`.

## Tests

```sh
swift test --package-path KitchenMemoryDomain
```
