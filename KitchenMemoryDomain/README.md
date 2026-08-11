# KitchenMemoryDomain

`KitchenMemoryDomain` contains Kitchen Memory concepts and rules without
SwiftData, CloudKit, or user-interface dependencies.

The package currently exposes four library products:

- `KitchenMemoryDomain` — persistence-independent domain values.
- `KitchenMemorySampleData` — deterministic sample resources and their loader.
- `KitchenMemoryPersistence` — SwiftData records and domain-facing repositories.
- `KitchenMemoryApplication` — reusable use cases that coordinate domain-facing repositories.

## Application

`KitchenMemoryApplication` begins with `RecipeLibrary`, the read capability used
to list recipes in a Kitchen and retrieve a recipe by stable identifier. SwiftUI
and future automation call this boundary rather than reaching into SwiftData.

## Persistence

`KitchenMemoryPersistence` is the first adapter behind the domain boundary. Its
record types are intentionally internal: application and interface code exchange
`Kitchen`, `Recipe`, and `RecipeRevision` values through `RecipeRepository` and
never retain SwiftData models.

The initial schema stores kitchens, recipes, revisions, media, equipment,
sections, ingredients, and instruction steps as separate rows connected by
stable UUID foreign keys. Ordered children carry an explicit `sortIndex`, since
database fetch order is not meaningful by itself. Small atomic value objects
such as rational quantity expressions are encoded into individual columns; they
can later become queryable records without changing the domain API.

`SwiftDataRecipeRepository` is main-actor isolated because each `ModelContext`
is an actor-bound unit of work. Background import will use a separate context
rather than moving SwiftData records between actors. The repository enforces the
Kitchen ownership boundary when saving and exposes Kitchen-scoped recipe lists
already reconstructed as domain values.

`KitchenMemorySchema.makeContainer()` uses SwiftData's standard permanent local
store location, deliberately configured without CloudKit. Synchronization will
be added behind this boundary after the collaboration prototype. In-memory
containers remain available for previews and tests, and callers may provide an
explicit URL for isolated tests or migration work.

The store begins at `KitchenMemorySchemaV1` under
`KitchenMemoryMigrationPlan`. Every later schema change must add a new immutable
version and an explicit migration stage; V1's models are never edited in place
after release.

## Sample resources

Sample content belongs in
`Sources/KitchenMemorySampleData/Resources/SampleRecipes.xcassets`. Keep the
catalog separate from the application's visual assets.

Assets for one recipe may be collected in an organizational asset-catalog group.
The sample loader supports nested data sets during command-line SwiftPM tests;
ordinary Xcode builds continue to resolve the compiled catalog by logical name.

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

### Sample image specifications

Place each rendition in its own Single Scale image set. Different aspect ratios
are semantic assets, not 1x, 2x, and 3x density variants of one image.

| Role | Preferred dimensions | Aspect ratio | Purpose |
| --- | ---: | ---: | --- |
| `hero` | 2400 × 1800 | 4:3 landscape | Recipe detail headers and prominent cards |
| `thumbnail` | 900 × 900 | 1:1 | Library rows, compact cards, and search results |
| `gallery` | 2400 × 1600 | 3:2 landscape | Additional process, ingredient, or finished-dish photographs |

Gallery photographs may instead use 1600 × 2400 at 2:3 when the original
composition is portrait. Runtime gallery presentation must accommodate both
orientations rather than forcing every user photograph into a landscape crop.

Use HEIC when preserving Apple-native wide-color or HDR photography is useful;
use JPEG when broader external-tool compatibility matters. Both are supported
source formats. Prefer sRGB or Display P3, omit transparency, keep the subject
away from crop-sensitive edges, and do not bake interface decoration or text
into recipe photographs.

The loader first uses `NSDataAsset` when Xcode compiles the catalog. It also
supports SwiftPM's command-line behavior, which copies the catalog source into
the package resource bundle during `swift test`.

## Tests

```sh
swift test --package-path KitchenMemoryDomain
```
