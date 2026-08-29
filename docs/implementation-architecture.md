# Implementation architecture

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

Kitchen Memory builds its presentation-independent business implementation as
one native Xcode framework and Swift module, `KitchenKit`. Separate iOS and
macOS application targets currently consume the same shared SwiftUI
presentation, composition, localization, and starter content.

## Target organization

`KitchenKit/` contains four responsibility folders:

- `Domain/` owns persistence-independent domain values.
- `Import/` owns deterministic Schema.org recipe discovery and normalization.
- `Persistence/` owns SwiftData records, domain-facing repositories,
  local/personal-cloud store configuration, and persistence runtime signals.
- `Logic/` owns product operations and presentation-independent workflow state.

These are architectural seams, not separately importable Swift submodules.
Both applications link one framework and write `import KitchenKit`. Import and
Persistence depend conceptually on Domain but not on one another; Logic
coordinates all three responsibilities without depending on the application or
SwiftUI.

```text
KitchenMemoryIOS ─────┐
                     ├──→ KitchenKit
KitchenMemoryMacOS ───┘

KitchenKit
├── Logic ────────┬──→ Import ───────┐
│                 └──→ Persistence ──┼──→ Domain
└────────────────────────────────────┘
```

This structure keeps technical responsibilities explicit without turning source
organization into independently linked products.

`KitchenMemory/` is the shared application layer. `KitchenMemoryIOS/` and
`KitchenMemoryMac/` contain resources and entitlements owned by only one app
target. `KitchenKit/` belongs only to the KitchenKit target. This direct target
membership replaces filename conventions and per-file platform filters.

The shared SwiftUI layer is an explicit 0.1 compromise, not a permanent promise.
The app-target boundary lets 0.2 replace either platform's presentation with
UIKit, AppKit, or platform-specific SwiftUI without moving product logic again.
See [ADR 0009](adr/0009-separate-native-app-targets.md).

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
launches use that storage only in a testing configuration. The automatic
`KitchenMemoryIOS` and `KitchenMemoryMacOS` schemes select `Develop`, `Testing`,
or `Production` at invocation time instead of duplicating schemes by
configuration. UI smoke runs select a `ProductionTesting` host explicitly.

Production retains automatic signing but does not pin an Apple Development
identity. Xcode therefore remains responsible for selecting the appropriate
distribution credentials during archive export.

## Import

KitchenKit's Import responsibility owns pure, fixture-testable discovery and normalization
of Schema.org `Recipe` JSON-LD, plus the bounded webpage fetcher. It produces
domain values and retained source evidence without saving recipes or presenting
review UI. Product logic coordinates those later steps.

## Product logic

KitchenKit's Logic responsibility owns recipe editing and library operations, import-result
interpretation, scaling selection, Kitchen bootstrap/reset operations, and pure
edit/import workflow state. SwiftUI views bind to those values and translate
typed failures into presentation strings. This boundary keeps current sheets
replaceable by future in-page editing without rewriting validation or losing
input, and lets complete product behavior run in fast framework tests.

`CookingSessions` is the Kitchen-scoped Logic interface for Cooking Session
work. Presentation supplies an explicit Start or a typed command with its
stable identity, then receives either an accepted projection, retained evidence
that needs attention, or a typed Logic error. The interface hides exact Recipe
Revision lookup, immutable snapshot creation, deterministic Session-owned
identities, causal-frontier selection, idempotency comparison, and repository
transaction choice. Classified Kitchen, Recipe, history, and single-Session
queries cross the same interface; a Recipe read alone never creates history.

Logic depends on `RecipeRepository` for the exact source Revision and on
`CookingSessionRepository` for complete retained evidence and atomic appends.
The repository does not decide command validity: Logic enforces lifecycle,
conflict, meaningful-draft, and continuation preconditions before selecting one
of the frozen persistence transactions. After an append, Logic reads the
durable classification back instead of treating a successful function return
as product success. This also makes a retry after an ambiguous post-write
failure converge on the caller's original evidence rather than append a new
fact.

The public failure contract distinguishes missing or foreign Recipes, missing
Revisions, insufficient snapshots, identity collisions, invalid intentions,
encoding failure, and repository read/write failure. Forward-incompatible or
competing retained evidence is not flattened into those errors: it remains a
typed `UnavailableSession` or `SessionRecovery` attention result for
presentation. Logic imports neither SwiftUI nor CloudKit.

## Deterministic Cooking Session engine

KitchenKit's Domain responsibility owns the Slice 11 Cooking Session evidence engine. Its
public seam accepts only persistence-independent retained evidence and returns a
complete `CookingSessionProjection`, `UnavailableSession`, or `SessionRecovery`.
The projector coalesces exact duplicates, validates identity membership,
digests, causal references, acyclicity, Closure consistency, continuation
provenance, and the independent deletion graph before deriving lifecycle,
progress, scale, entries, outcome, late evidence, and explicit conflicts.

Permanent V1 codecs provide canonical bytes for execution snapshots, causal
heads, fact payloads, outcomes, and closed projections. Causal heads use sorted
UUID bytes; JSON codecs use sorted keys and reject well-formed noncanonical
representations on read. SHA-256 digests therefore describe exact stable bytes,
not a decoder's best-effort interpretation. The engine imports Foundation and
CryptoKit only. It has no SwiftData, CloudKit, repository, actor, device, or UI
dependency, so later persistence and synchronization slices are adapters around
this domain contract rather than authorities over its merge behavior.

### Application composition and stitching points

The shared application layer contains a deliberately small set of stitching
points, compiled into both native app targets. They connect platform facilities
and replaceable SwiftUI presentation to the stable framework boundaries without
moving business rules back into the app.

```text
KitchenMemoryApp
└── AppRuntime
    ├── AppLaunchPlan
    └── PreparedApp
        ├── SwiftDataRecipeRepository
        ├── BundledSampleRecipeProvider
        ├── KitchenBootstrapService
        ├── KitchenPreferencesStoring
        │   ├── SampleRecipeOnboardingStoring
        │   └── CloudSyncPreferenceStoring
        ├── PersistentStoreChangeObserver
        ├── PersonalCloudStatusMonitor
        └── RecipeLibraryModel
            └── RecipeLibrary
                ├── RecipeEditor
                ├── RecipeImportService
                ├── SampleRecipeInstallService
                └── KitchenResetService
```

`AppRuntime` is the composition root. It translates process arguments, build
policy, the signed CloudKit container, test-host state, and the stored sync
choice into one `AppLaunchPlan`. The plan names a valid store mode, sample-fixture
policy, launch-time sync state, Settings availability, schema-administration
request, and privacy-safe failure simulation together rather than exposing
independent flags to callers.

The runtime then creates `PreparedApp`, which retains the model container,
observable library projection, remote-change observer, personal-cloud status
monitor, and optional sync settings for their complete lifetimes. Its
implementation creates the concrete SwiftData repository and asset-backed
sample provider, asks the bootstrap operation for the initial empty Kitchen,
selects durable or disposable preferences, and prepares the Recipe Library.
For a personal-cloud store it also starts and retains the persistence adapters
that feed external changes and account status back into the library projection.
`KitchenMemoryApp` sees only prepared or unavailable state and retry; tests use
one explicit disposable runtime configuration rather than constructing the
production graph through loosely related booleans and optionals.

`RecipeLibrary` is the deep Logic module for one Kitchen's recipe-library
intentions. Its interface loads durable content with current sample presence,
creates or revises through immutable recipe history, interprets imports, installs
samples, and resets after confirmation. Repository access and the smaller
editing, import, sample, and reset implementations remain behind that interface.

`RecipeLibraryModel` is the observable presentation projection. It owns the
loaded recipe list, current selection, sample-onboarding response, startup phase,
personal-cloud status, and typed presentation issue. Every durable library
intention crosses the `RecipeLibrary` seam; the model applies only presentation
consequences such as retaining or changing selection and choosing localized
failure categories. Its main-actor isolation and observation belong to the app
layer; recipe rules do not.

`BundledSampleRecipeProvider` adapts the application asset catalog to
`SampleRecipeProviding`. `SampleRecipeInstallService` adds only recipe UUIDs
that are not already present and derives none/partial/complete presence from
the current localized pack's stable identities. `KitchenResetService`
deliberately replaces the Kitchen after explicit destructive confirmation.
Bootstrap itself creates an empty Kitchen and never interprets emptiness as
permission. A future background-asset provider can replace the bundled adapter
without changing these use cases.

`KitchenPreferencesStoring` is the application preference boundary. Its
Defaults-backed implementation owns stable key names, typed defaults,
observation, and each key's synchronization scope. Consumers receive narrower
capabilities: the recipe-library state machine sees only
`SampleRecipeOnboardingStoring`, while cloud configuration sees only
`CloudSyncPreferenceStoring`. The onboarding value persists `undecided`,
`accepted`, or `declined` outside recipe storage, but it is not standing
authority to reinsert a deleted recipe: current presence comes from the
repository, and repair requires an explicit Settings action. The in-app startup
gate moves through loading, sample choice, and library states; the operating-
system launch screen remains static and does not perform product work.

Views own transient presentation and bind directly to pure workflow values such
as `RecipeEditSession`, `RecipeImportSession`, and `RecipeScalingState`. They ask
`RecipeLibraryModel` to cross the library seam rather than constructing
repositories or Logic operations themselves. `RecipeLibraryIssue` is the final
presentation seam: it converts typed failure categories into user-facing copy.
That copy now comes from String Catalogs without changing the underlying logic.

## Persistence

KitchenKit's Persistence responsibility is the app's persistence implementation behind the
domain boundary. It deliberately includes both the local SwiftData store and
the managed personal-CloudKit behavior of that same store. Its record types are
intentionally internal: application and interface code exchange `Kitchen`,
`Recipe`, and `RecipeRevision` values through `RecipeRepository`, and complete
classified Cooking Session evidence through `CookingSessionRepository`; neither
seam exposes or retains SwiftData models.

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

`SwiftDataCookingSessionRepository` is a separate main-actor adapter over the
same container. Its public transaction vocabulary encodes the smallest complete
V3 append boundaries: root, Fact, Closure, Closure plus Delete, Delete, observed
Restore set, Closure resolution, or continuation root. Reads query immutable
rows through scalar Kitchen Memory identities, retain physical duplicates and
collisions, reject declaration placeholders, then delegate all product meaning
to `SessionEvidenceProjector`. `InMemoryCookingSessionRepository` implements the
same seam for Logic tests without making SwiftData part of command behavior.

`KitchenMemorySchema.makeContainer()` selects either SwiftData's standard
permanent store with a named private CloudKit database or an explicit local-only
configuration. The application uses private synchronization for ordinary
launches. In-memory containers, hosted unit tests, and callers that provide an
explicit test URL remain local-only; they never require an iCloud entitlement or
account. Persistence-owned adapters translate Core Data and CloudKit callbacks
into plain status and refresh signals before the application connects them to
`RecipeLibraryModel`. Domain, Logic, and the repository protocol remain unaware
of the transport. See
[personal iCloud synchronization](personal-icloud-synchronization.md).

SwiftData continues to own synchronization. The framework imports Core Data
only for public managed-store notifications and development schema
initialization, and imports CloudKit for account availability. Those adapters
remain Swift: Objective-C would neither change their queue-delivery rules nor
add sharing capability. A distinct store framework should wait until a future
implementation has a genuinely different lifecycle, such as a versioned
document package or direct shared-Kitchen repository.

The released store begins at immutable `KitchenMemorySchemaV1` under
`KitchenMemoryMigrationPlan`. V2 adds durable recipe-deletion and observed-
restoration records through a lightweight migration; it does not alter a V1
record. V3 adds exactly `CookingSessionRecord`, `SessionFactRecord`,
`SessionClosureRecord`, `SessionDeletionRecord`, and
`SessionDeletionResolutionRecord`, with scalar UUID links and no relationships,
uniqueness constraints, external storage, or mutable projections. The complete
local chain is V1 to V2 to V3 through two lightweight stages; preserved fixture
stores prove Recipe history and V2 disposition evidence survive. The production
CloudKit schema follows the corresponding additive rule: later features may
introduce record types and fields but must not remove or redefine published
elements.

## Localization resources

String Catalogs, locale-aware presentation formatters, and localized bundled
content belong to the shared application layer and have membership in both app
targets. English-oriented display helpers have been removed from the domain;
KitchenKit returns semantic domain values and typed failures rather than
choosing interface language. This keeps formatting and pluralization replaceable
without making locale a hidden input to business rules.

Interface copy and authored recipe content use separate resources. String
Catalogs hold labels, actions, errors, and pluralized messages. Complete sample
recipe documents remain data assets so a translation preserves coherent
instructions, ingredients, attribution, and accessibility descriptions. See
[localization architecture](localization-architecture.md).

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

Framework tests belong to one standalone, unhosted `KitchenKitTests` target,
organized into Domain, Import, Persistence, Logic, and Support folders. The
minimal shared `KitchenKit` scheme associates that unhosted target, while Xcode
creates its test plan automatically and runs the suite once on macOS.
Property-test seeds and their generator live in `KitchenKitTests/Support/`.

Tests for starter content, presentation formatting, application composition,
resources, and hosted runtime behavior live in `KitchenMemoryTests`; that
folder belongs only to the platform-specific `KitchenMemoryIOSTests` and
`KitchenMemoryMacTests` host targets. Xcode's automatic plans derive their test
membership from those targets. The exact coverage gate requires every
executable business-logic line in KitchenKit to be covered by the core macOS
result. Both app lanes remain correctness gates; the shared-source metric does
not make either optional. See
[ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md) for the
business-logic-versus-UI testing investment boundary.
