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

`SampleManifest.dataset` is a versioned recipe-pack index. Its XML property list
names each recipe data asset and optional hero image asset. Recipe data sets use
Foundation property lists so Xcode can provide structured editing without adding
a parser dependency. Recipe, revision, row, step, and media identities are
pre-generated so importing the catalog into a fresh store is repeatable and can
be made idempotent.

The catalog does not contain a Kitchen identifier. A sample recipe retains its
own stable recipe, revision, and media identities, while the importing use case
attaches it to the destination Kitchen created for that installation or sharing
context.

Recipe media refers to logical asset names and semantic roles such as `hero`,
`thumbnail`, and `gallery`. File encoding and pixel dimensions remain asset-
catalog concerns rather than domain properties.

The loader first uses `NSDataAsset` when Xcode compiles the catalog. It also
supports SwiftPM's command-line behavior, which copies the catalog source into
the package resource bundle during `swift test`.

## Tests

```sh
swift test --package-path KitchenMemoryDomain
```
