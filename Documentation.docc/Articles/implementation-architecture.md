# Implementation architecture

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

Kitchen Memory uses native Xcode framework targets for boundaries that carry
independent technical responsibilities. Interface code, platform composition,
and bundled starter content compile directly into the application target.

## Target organization

`KitchenMemory/Modules` contains four internal frameworks. They enforce
dependency direction inside the Xcode project; they are not separately
distributed products.

- `KitchenMemoryDomain` owns persistence-independent domain values.
- `KitchenMemoryImport` owns deterministic Schema.org recipe discovery and
  normalization.
- `KitchenMemoryPersistence` owns SwiftData records and domain-facing
  repositories.
- `KitchenMemoryLogic` owns product operations and presentation-independent
  workflow state.

The application target links all four frameworks because composition adapters
exchange domain values, construct persistence and import implementations, and
inject Logic operations. Import and persistence each depend on the domain but
not on one another. Logic coordinates all three public boundaries without
depending on the application or SwiftUI.

```text
KitchenMemory application ──→ all four internal frameworks

KitchenMemoryLogic
├── KitchenMemoryImport ───────┐
├── KitchenMemoryPersistence ──┼──→ KitchenMemoryDomain
└──────────────────────────────┘
```

This structure keeps reusable technical boundaries explicit without turning
small, app-specific groups of files into framework products merely for source
organization.

## Import

`KitchenMemoryImport` owns pure, fixture-testable discovery and normalization
of Schema.org `Recipe` JSON-LD, plus the bounded webpage fetcher. It produces
domain values and retained source evidence without saving recipes or presenting
review UI. Product logic coordinates those later steps.

## Product logic

`KitchenMemoryLogic` owns recipe editing and library operations, import-result
interpretation, scaling selection, Kitchen bootstrap/reset operations, and pure
edit/import workflow state. SwiftUI views bind to those values and translate
typed failures into presentation strings. This boundary keeps current sheets
replaceable by future in-page editing without rewriting validation or losing
input, and lets complete product behavior run in fast framework tests.

### Application composition and stitching points

The application target contains a deliberately small set of stitching points.
They connect platform facilities and replaceable SwiftUI presentation to the
stable framework boundaries without moving business rules back into the app.

```text
KitchenMemoryApp
└── AppDependencies
    ├── SwiftDataRecipeRepository
    ├── BundledSampleRecipeProvider
    ├── KitchenBootstrapService
    ├── SampleRecipeInstallService
    ├── SampleRecipeOnboardingStoring
    └── RecipeLibraryModel
        ├── RecipeLibrary
        ├── RecipeEditor
        ├── RecipeImportService
        └── KitchenResetService
```

`AppDependencies` is the composition root. It creates the concrete SwiftData
repository and asset-backed sample provider, asks the bootstrap service for the
initial empty Kitchen, selects the durable or disposable onboarding store, and
injects the resulting collaborators into
`RecipeLibraryModel`. Concrete construction stays here so neither the views nor
the reusable frameworks need to locate their own dependencies.

`RecipeLibraryModel` is the principal application glue. It owns the UI-facing
state for one Kitchen: the loaded recipe list, current selection, load state,
sample-onboarding and live pack-presence states, startup phase, and typed
presentation issue. Every library-wide read or mutation passes through it. The
model delegates validation and durable operations to
`KitchenMemoryLogic`, then applies the small amount of presentation coordination
that follows a successful operation, such as reloading the list while preserving
or changing the selection. Its main-actor isolation and observation belong to
the app boundary; recipe rules do not.

`BundledSampleRecipeProvider` adapts the application asset catalog to
`SampleRecipeProviding`. `SampleRecipeInstallService` adds only recipe UUIDs
that are not already present and derives none/partial/complete presence from
the current localized pack's stable identities. `KitchenResetService`
deliberately replaces the Kitchen after explicit destructive confirmation.
Bootstrap itself creates an empty Kitchen and never interprets emptiness as
permission. A future background-asset provider can replace the bundled adapter
without changing these use cases.

`SampleRecipeOnboardingStoring` persists `undecided`, `accepted`, or `declined`
outside recipe storage to prevent repeating the onboarding question. It is not
standing authority to reinsert a deleted recipe: current presence comes from
the repository, and repair requires an explicit Settings action. The in-app
startup gate moves through loading, sample choice, and library states; the
operating-system launch screen remains static and does not perform product work.

Views own transient presentation and bind directly to pure workflow values such
as `RecipeEditSession`, `RecipeImportSession`, and `RecipeScalingState`. They ask
`RecipeLibraryModel` to cross the library boundary rather than constructing
repositories or use cases themselves. `RecipeLibraryIssue` is the final
presentation seam: it converts typed failure categories into user-facing copy.
That copy now comes from String Catalogs without changing the underlying logic.

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

`KitchenMemorySchema.makeContainer()` currently uses SwiftData's standard
permanent local store location and is deliberately configured without CloudKit.
Slice 10 will replace that local-only production configuration with the selected
private cross-device integration after a focused prototype, while keeping the
choice behind this boundary. In-memory containers remain available for previews
and tests, and callers may provide an explicit URL for isolated tests or
migration work.

The store begins at `KitchenMemorySchemaV1` under
`KitchenMemoryMigrationPlan`. V1 remains intentionally mutable before the first
release, with development stores deleted after incompatible changes. At first
release V1 becomes immutable; every later local schema change must add a new
version and an explicit migration stage. The production CloudKit schema follows
the corresponding additive rule: later features may introduce record types and
fields but must not remove or redefine published elements.

## Localization resources

String Catalogs, locale-aware presentation formatters, and localized bundled
content belong to the application target. English-oriented display helpers have
been removed from the domain; the frameworks return semantic domain values and
typed failures rather than choosing interface language. This keeps formatting
and pluralization replaceable without making locale a hidden input to business
rules.

Interface copy and authored recipe content use separate resources. String
Catalogs hold labels, actions, errors, and pluralized messages. Complete sample
recipe documents remain data assets so a translation preserves coherent
instructions, ingredients, attribution, and accessibility descriptions. See
<doc:localization-architecture>.

## Sample resources

Deterministic starter content is application data, so its loader and resources
live directly in the `KitchenMemory` target. The source asset catalog is
`KitchenMemory/SampleRecipes.xcassets`, separate from the application's visual
assets.

Assets for one recipe may be collected in an organizational asset-catalog
group. The sample loader resolves nested source data sets when Xcode copies the
catalog for tests, while ordinary builds resolve the compiled catalog by logical
name.

`SampleManifest.dataset` is a versioned recipe-pack index. Its XML property list
names each recipe data asset and optional hero image asset. Recipe data sets use
Foundation property lists so Xcode can provide structured editing without
adding a parser dependency. Recipe, revision, row, step, and media identities
are pre-generated so importing the catalog into a fresh store is repeatable and
can be made idempotent.

The manifest contains explicit locale-tagged
recipe variants. A manifest-level sample-family identifier relates the variants,
while each authored translation has its own stable recipe, revision, and child
identities. Reusing one durable recipe identity for different translated
payloads would create a synchronization conflict. The application adapter
selects an exact regional match, a supported language fallback, or the English
development asset before Logic performs an idempotent installation or atomic
reset operation.

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

`SampleRecipeCatalog` resolves the compiled catalog from the bundle containing
the application-owned loader.

## Tests

Framework, application, integration, and UI tests belong to the shared
`KitchenMemory` scheme and the committed `KitchenMemory.xctestplan`. Tests for
starter content and app composition live directly in `KitchenMemoryTests`;
framework tests remain grouped by their corresponding module, including
`KitchenMemoryLogicTests`. The exact coverage gate currently requires every
executable line in the four internal frameworks to be covered by the non-UI
suite. The UI target contains only application-shell smoke tests. See
<doc:0007-business-logic-coverage-and-ui-smoke-tests>.
