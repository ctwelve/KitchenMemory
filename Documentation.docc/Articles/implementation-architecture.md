# Implementation architecture

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

Kitchen Memory uses native Xcode framework targets for boundaries that carry
independent technical responsibilities. Separate iOS and macOS application
targets currently consume the same shared SwiftUI presentation, composition,
localization, and starter content.

## Target organization

Four root-level folders contain the internal frameworks. They enforce dependency
direction inside the Xcode project; they are not separately distributed products.

- `KitchenMemoryDomain` owns persistence-independent domain values.
- `KitchenMemoryImport` owns deterministic Schema.org recipe discovery and
  normalization.
- `KitchenMemoryPersistence` owns SwiftData records, domain-facing
  repositories, local/personal-cloud store configuration, and persistence
  runtime signals.
- `KitchenMemoryLogic` owns product operations and presentation-independent
  workflow state.

Both application targets link all four frameworks because composition adapters
exchange domain values, construct persistence and import implementations, and
inject Logic operations. Import and persistence each depend on the domain but
not on one another. Logic coordinates all three public boundaries without
depending on the application or SwiftUI.

```text
KitchenMemory iOS ───┐
                     ├──→ all four internal frameworks
KitchenMemory macOS ─┘

KitchenMemoryLogic
├── KitchenMemoryImport ───────┐
├── KitchenMemoryPersistence ──┼──→ KitchenMemoryDomain
└──────────────────────────────┘
```

This structure keeps reusable technical boundaries explicit without turning
small, app-specific groups of files into framework products merely for source
organization.

`KitchenMemory/` is the shared application layer. `KitchenMemoryIOS/` and
`KitchenMemoryMac/` contain resources and entitlements owned by only one app
target. Each root-level framework folder belongs only to its matching framework
target. This direct target membership replaces filename conventions and
per-file platform filters.

The shared SwiftUI layer is an explicit 0.1 compromise, not a permanent promise.
The app-target boundary lets 0.2 replace either platform's presentation with
UIKit, AppKit, or platform-specific SwiftUI without moving product logic again.
See <doc:0009-separate-native-app-targets>.

## Build environments

Project-level `.xcconfig` files define operational policy independently of
target implementation details:

| Configuration | Intended action | Personal CloudKit | Optimization |
| --- | --- | --- | --- |
| `Debug` | local diagnostics and previews | off | debug |
| `Develop` | ordinary developer runs and schema exercises | development | debug |
| `Testing` | deterministic business-logic and integration tests | off | debug |
| `Production` | profile, archive, and distribution | production | release |
| `ProductionTesting` | production UI smoke-test host only | off | release |

`ProductionTesting` is deliberately non-distributable. It retains production
compiler behavior while admitting disposable automated-test storage that is
disabled in the actual `Production` application. Hosted unit tests and UI-test
launches use that storage only in a testing configuration. Each platform's
Development scheme runs `Develop`, each Testing scheme runs the non-UI plan with
`Testing`, and each Production scheme archives `Production` while running its UI
target through `ProductionTesting`.

Production retains automatic signing but does not pin an Apple Development
identity. Xcode therefore remains responsible for selecting the appropriate
distribution credentials during archive export.

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

The shared application layer contains a deliberately small set of stitching
points, compiled into both native app targets. They connect platform facilities
and replaceable SwiftUI presentation to the stable framework boundaries without
moving business rules back into the app.

```text
KitchenMemoryApp
└── AppDependencies
    ├── SwiftDataRecipeRepository
    ├── BundledSampleRecipeProvider
    ├── KitchenBootstrapService
    ├── SampleRecipeInstallService
    ├── SampleRecipeOnboardingStoring
    ├── PersistentStoreChangeObserver
    ├── PersonalCloudStatusMonitor
    └── RecipeLibraryModel
        ├── RecipeLibrary
        ├── RecipeEditor
        ├── RecipeImportService
        └── KitchenResetService
```

`AppDependencies` is the composition root. It creates the concrete SwiftData
repository and asset-backed sample provider, asks the bootstrap service for the
initial empty Kitchen, selects the durable or disposable onboarding store, and
injects the resulting collaborators into `RecipeLibraryModel`. For a managed
personal-cloud store it also connects the persistence framework's remote-change
and status adapters to that model. Concrete construction stays here so neither
the views nor the reusable frameworks need to locate their own dependencies.

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

`KitchenMemoryPersistence` is the app's persistence implementation behind the
domain boundary. It deliberately includes both the local SwiftData store and
the managed personal-CloudKit behavior of that same store. Its record types are
intentionally internal: application and interface code exchange `Kitchen`,
`Recipe`, and `RecipeRevision` values through `RecipeRepository` and never
retain SwiftData models.

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

`KitchenMemorySchema.makeContainer()` selects either SwiftData's standard
permanent store with a named private CloudKit database or an explicit local-only
configuration. The application uses private synchronization for ordinary
launches. In-memory containers, hosted unit tests, and callers that provide an
explicit test URL remain local-only; they never require an iCloud entitlement or
account. Persistence-owned adapters translate Core Data and CloudKit callbacks
into plain status and refresh signals before the application connects them to
`RecipeLibraryModel`. Domain, Logic, and the repository protocol remain unaware
of the transport. See <doc:personal-icloud-synchronization>.

SwiftData continues to own synchronization. The framework imports Core Data
only for public managed-store notifications and development schema
initialization, and imports CloudKit for account availability. Those adapters
remain Swift: Objective-C would neither change their queue-delivery rules nor
add sharing capability. A distinct store framework should wait until a future
implementation has a genuinely different lifecycle, such as a versioned
document package or direct shared-Kitchen repository.

The store begins at `KitchenMemorySchemaV1` under
`KitchenMemoryMigrationPlan`. V1 remains intentionally mutable before the first
release, with development stores deleted after incompatible changes. At first
release V1 becomes immutable; every later local schema change must add a new
version and an explicit migration stage. The production CloudKit schema follows
the corresponding additive rule: later features may introduce record types and
fields but must not remove or redefine published elements.

## Localization resources

String Catalogs, locale-aware presentation formatters, and localized bundled
content belong to the shared application layer and have membership in both app
targets. English-oriented display helpers have been removed from the domain;
the frameworks return semantic domain values and typed failures rather than
choosing interface language. This keeps formatting and pluralization replaceable
without making locale a hidden input to business rules.

Interface copy and authored recipe content use separate resources. String
Catalogs hold labels, actions, errors, and pluralized messages. Complete sample
recipe documents remain data assets so a translation preserves coherent
instructions, ingredients, attribution, and accessibility descriptions. See
<doc:localization-architecture>.

## Sample resources

Deterministic starter content is application data, so its loader and resources
live directly in the shared `KitchenMemory/` layer with membership in both app
targets. The source asset catalog is `KitchenMemory/SampleRecipes.xcassets`,
separate from the shared visual asset catalog.

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
attaches it to the destination Kitchen. Fresh personal-sync stores converge on a
deterministic personal Kitchen identity; future sharing supplies a different
Kitchen context without changing the sample pack.

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

Framework, application, and integration tests belong to both platform Testing
schemes and the platform-specific `KitchenMemoryIOSTesting.xctestplan` and
`KitchenMemoryMacTesting.xctestplan` plans. Tests for starter content
and app composition live directly in `KitchenMemoryTests`; that shared source
folder belongs to the platform-specific `KitchenMemoryIOSTests` and
`KitchenMemoryMacTests` host targets. Framework tests remain grouped by their
corresponding module, including
`KitchenMemoryLogicTests` and the cloud-specific
`KitchenMemoryPersistenceTests/Cloud` group. The exact coverage gate currently
requires every executable line in the four internal frameworks to be covered by
the canonical macOS non-UI result. The iOS and macOS application-test lanes are
both correctness gates; using one platform's result for the shared-source metric
does not make the other platform optional.

The two platform Production schemes are the only schemes that reference
the platform-specific production plans and the shared UI target. Their
application-shell smoke tests compile under `ProductionTesting`, never under
ordinary Debug, Develop, Testing, or distributable Production actions. See
<doc:0007-business-logic-coverage-and-ui-smoke-tests>.
