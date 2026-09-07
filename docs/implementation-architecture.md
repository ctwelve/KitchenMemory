# Implementation architecture

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Kitchen Memory has one native multiplatform `KitchenMemory` application and one
presentation-independent `KitchenKit` framework. Both platform products consume
the same core; source folders are responsibility boundaries, not Swift modules.
For symbol entry points, use the [KitchenKit](../KitchenKit/KitchenKit.docc/KitchenKit.md)
and [application](../KitchenMemory/Documentation.docc/Documentation.md) DocC guides.

## Target organization

| Target | Product |
| --- | --- |
| `KitchenMemory` | native multiplatform application |
| `KitchenKit` | framework |
| `KitchenMemoryTests` | hosted unit tests |
| `KitchenMemoryUITests` | UI navigation tests |
| `KitchenKitTests` | unhosted unit tests |

### KitchenKit responsibilities

KitchenKit has four responsibility roots:

| Folder | Ownership |
| --- | --- |
| `Domain` | Values, identities, invariants, evidence projections |
| `Import` | Bounded webpage retrieval and deterministic Schema.org normalization |
| `Logic` | Product intentions, editing drafts, library and Session operations |
| `Persistence` | Domain-facing repository interfaces, SwiftData adapters, local stores, managed CloudKit |

The app imports KitchenKit; Domain has no presentation or storage-framework
identity. Import produces reviewable candidates and source evidence without
saving. Logic coordinates product operations; Persistence fulfills domain-facing
repository contracts. SwiftUI, UIKit, and AppKit remain outside KitchenKit.
Package choices and linkage exceptions live in [DEPENDENCIES.md](../DEPENDENCIES.md).

### Application presentation taxonomy


Application Swift sources use feature and responsibility homes inside the one
multiplatform `KitchenMemory` target:

```text
KitchenMemory/
├── Composition/             app entry point, launch policy, runtime, and shell
├── Features/
│   ├── RecipeLibrary/       browsing, editing, importing, and scaling
│   ├── CookingSession/      active work, history, recovery, and session outbox
│   ├── Settings/            preferences, privacy, sync, and destructive reset
│   └── Startup/             loading, failure, and sample-recipe decisions
├── SharedPresentation/      localization and cross-feature presentation help
├── Resources/               application-owned catalog models and providers
└── PlatformAdapters/        store refresh and platform identity bridges
```

The synchronized `KitchenMemory/` source root still owns all of these folders,
the String Catalogs, asset catalogs, privacy manifest, property lists,
entitlements, and localized launch resources. Folders express application
ownership; they are not new targets, modules, visibility boundaries, or
dependency seams. Hosted tests mirror feature or responsibility ownership under
`KitchenMemoryTests/`. The separate `KitchenMemoryUITests/` target remains one
small accessible top-level navigation suite rather than a second presentation
consumer.

The project-structure contract rejects application Swift files outside this
taxonomy, rejects new KitchenKit responsibility roots, and rejects SwiftUI,
UIKit, or AppKit imports in `KitchenKit`. A private `KitchenUI` framework should
be reconsidered only when evidence establishes at least one of these pressures:
a second real consumer, a distinct dependency footprint, a need for independent
evolution, or measured build cost that a separate module would improve. Folder
size or a desire for tidier navigation alone is not that evidence.

The shared SwiftUI interface remains provisional under
[ADR 0006](adr/0006-shared-ui-for-foundation-slices.md). Platform-specific
presentation may replace it without moving business rules into the app or
creating a target before a real independent consumer exists.

## Build environments


Project-level `.xcconfig` files define operational policy independently of
target implementation details:

| Configuration | Intended action | Personal CloudKit | Optimization |
| --- | --- | --- | --- |
| `Debug` | local diagnostics and previews | off | debug |
| `Develop` | ordinary developer runs and schema exercises | development | debug |
| `Testing` | deterministic business-logic and integration tests | off | debug |
| `Production` | profile, archive, and distribution | production | release |
| `ProductionTesting` | production UI-validation host only | off | release |

`ProductionTesting` is deliberately non-distributable. It retains production
compiler behavior while admitting disposable automated-test storage that is
disabled in the actual `Production` application. The saved `KitchenMemory`
scheme uses `Testing` for its default Test and Analyze actions, `Develop` for Run,
and `Production` for Profile and Archive. Its plan runs hosted tests and UI
smoke together on either native destination; the UI harness selects disposable
storage through its launch arguments. A release-equivalent UI validation run may
select `ProductionTesting` explicitly.

The project keeps `MERGED_BINARY_TYPE` at `automatic` so Xcode can optimize
framework linkage for the selected build. Because hosted test products may
then re-export `KitchenKit`, each test target's localization-catalog embedding
script must run before Sources, Frameworks, and Resources. Running it later can
make the script's test-bundle output and Xcode's re-export signing step depend
on one another. The project-structure checker freezes this ordering.

Production retains automatic signing but does not pin an Apple Development
identity. Xcode therefore remains responsible for selecting the appropriate
distribution credentials during archive export.

## Application composition and durable intentions

`KitchenMemoryApp` delegates preparation to `AppStartupCoordinator`, then
`AppRuntime`. One `AppLaunchPlan` combines store mode, sample fixtures, sync
status, Settings availability, and authorized development administration. The
runtime creates `PreparedApp`, which retains the container, repositories,
Recipe Library and Session projections, preferences, and external-change/cloud
observers for their full lifetimes. Startup exposes prepared or unavailable
state with retry; test hosts select explicit disposable storage.

`RecipeLibraryModel` crosses the deep `RecipeLibrary` seam for durable library
intentions. `RecipeDrafts` owns device-local Recipe Editing Draft membership,
contents, recovery, persistence, and frozen-command publication;
`FileRecipeEditingStore` owns atomic encoding and legacy restoration. The app's
`RecipeEditingModel` adapts bindings and discard presentation. Reset purges local
drafts before shared Kitchen contents. Recipe creation/editing is not a second
app-owned Save implementation.

`RecipeLibraryNavigation` is the single accepted destination owner. Editor,
Session, finished observation, history return scope, Drafts, Deleted Items, and
Recovery are mutually exclusive destinations. Leaving an editor requires the
local persistence check. Navigation never emits Stop or Finish. Compact native
navigation derives from the same accepted destination.

`CookingSessionPresentationModel` projects the separate `CookingSessions` Logic
interface. Queries use retained Session provenance rather than joins through
currently visible Recipes. Commands enter an ordered device-local outbox with
final identities before submission and leave after locally durable acceptance.
Progress and scale project optimistically over the immutable snapshot; relaunch
retries the same intentions. A definitively rejected command against an already
Finished Session clears its impossible identity while retaining exact Entry
text separately for explicit continuation, confirmed copy, or discard.
Unsubmitted Entry drafts and local visit/nudge timestamps do not create Facts,
prove synchronization, or authorize lifecycle. See [Cooking Sessions](cooking-sessions.md).

Views bind to projections and workflow values, localize typed failures, and own
transient presentation. They do not coordinate repository transactions or
reconstruct evidence. Container width selects Compact, Regular, or Wide Session
composition while stable snapshot row identities survive recomposition.

## Persistence

`SwiftDataRecipeRepository` and `SwiftDataCookingSessionRepository` are separate
main-actor adapters over the same container. Callers receive domain values and
classified evidence, never live SwiftData records. Each transaction uses its
actor-bound context; background work cannot move records between actors.
Immutable commands, exact retries, duplicate/collision handling, and partial
CloudKit delivery are resolved behind these interfaces.

Recipe authority adapters explicitly implement Save, Selection, head reads,
projection, and ownership convergence or reject unsupported operations. The
pair-based bulk/sample Save path uses the same authority writer; it is no
fallback for command Save. Retained V5 backfill and payload decoding are still
required. Session repository transactions preserve the complete V3 append
boundaries and delegate product meaning to the evidence projector.

The store's current schema is `KitchenMemorySchemaV7`. Earlier declarations
remain frozen: V2 adds Recipe disposition, V3 Session evidence, V4 ownership,
V5 Recipe authority, V6 private image payloads, and V7 organization evidence.
See [V5 authority](recipe-authority-v5-schema.md), [V3 Sessions](cooking-session-v3-schema.md),
[media](recipe-media.md), [Folders](folders.md), [Tags](tags.md), and
[maintenance](records-maintenance.md). Schema membership does not prove that an
arbitrary alpha store can migrate; retained fixtures and ADR 0016 define that
boundary.

SwiftData owns transport. Persistence uses Core Data for public managed-store
notifications/development schema initialization and CloudKit for account status.
The app consumes plain refresh and status signals. V4 ownership convergence
claims only eligible unowned legacy Kitchens; an explicitly different owner
stops mutation. Ordinary personal-cloud launches and explicit local-only/test
stores follow [personal iCloud synchronization](personal-icloud-synchronization.md).

<a id="localization-resources"></a>
<a id="sample-resources"></a>
<a id="sample-image-specifications"></a>
<a id="tests"></a>

## Resources and tests

The synchronized `KitchenMemory/` root owns catalogs, starter documents,
preferences, privacy and license resources. SDK-qualified settings choose iOS
and macOS property lists and ordinary/testing entitlements; platform filters
exclude launch resources from Mac products. Resource language, sample identity,
onboarding, and photo specifications have one owner in
[localization architecture](localization-architecture.md).

Hosted tests mirror application ownership. KitchenKit tests cover Domain,
Import, Logic, Persistence, and Support; deterministic entropy seeds live in
`KitchenKitTests/Support/`. The [CI contract](continuous-integration.md) owns
scheme/plan membership, destination requirements, and exact durable coverage.
