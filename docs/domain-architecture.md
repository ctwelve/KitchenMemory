# Domain architecture

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->


- Status: Accepted direction
- Date: 2026-08-10

## Purpose

Kitchen Memory separates cooking concepts from storage and synchronization.
The domain describes what the household means; persistence records describe how
that meaning is stored; synchronization describes how stored changes move among
devices and people.

```text
KitchenKit — Domain responsibility
        ↓
KitchenKit — Logic and domain-facing repository seams
        ↓
KitchenKit — Persistence adapters
        ↓
SwiftData and CloudKit
```

Domain values never expose SwiftData object identity, `CKRecord.ID`, database
scope, or merge bookkeeping. Every durable domain entity has an application-
owned stable identifier that survives export, import, storage migration, and
synchronization changes.

## Kitchen boundary

`Kitchen` is the ownership and collaboration boundary. Recipes, ingredient
vocabulary, pantry knowledge, organization, plans, sessions, sources, and media
belong to a kitchen.

A kitchen is not one large in-memory or persisted object containing all of that
data. Top-level aggregates are loaded and saved independently and carry a stable
`kitchenID`. This prevents one edit from making the entire kitchen a conflict or
serialization boundary.

```text
Kitchen
├── KitchenMember[]
├── Recipe[]
│   └── RecipeRevision[]
│       ├── RecipeIngredient[]
│       └── InstructionStep[]
├── Ingredient[]
│   └── PantryItem
│       └── PantryHolding[]
├── PlannedCook[]
│   └── IngredientDecision[]
├── CookingSession[]
│   ├── ExecutionSnapshot
│   ├── SessionFact[]
│   └── SessionClosure?
├── SourceCapture[]
├── MediaAsset[]
├── Folder[]
└── Tag[]
```

Kitchen, Recipe, RecipeRevision, and the persistence-independent Cooking Session
evidence model are implemented today. The remaining branches are accepted
ownership direction for later product slices, not claims about current source
types or persistence tables. Cooking Session persistence is intentionally still
outside the implemented storage schema.

`KitchenMember` represents product-level attribution and household behavior.
CloudKit share participation and permission remain authoritative in the sync
layer; the domain must not copy framework participants indiscriminately.

## Aggregate boundaries

| Aggregate | Responsibility |
| --- | --- |
| `Kitchen` | Stable household identity, name, and kitchen-wide policy |
| `Recipe` | Durable identity of a maintained dish and its revision history |
| `RecipeRevision` | One intended recipe representation: metadata, yield, ingredients, instructions, and attachments |
| `Ingredient` | Kitchen-scoped normalized ingredient concept and aliases |
| `PantryItem` | Kitchen knowledge about one ingredient and its holdings |
| `PlannedCook` | One intention, scale, readiness decisions, and advance preparation |
| `CookingSession` | One actual performance, immutable context, accepted activity, and optional outcome |
| `SourceCapture` | Preserved source evidence and provenance |
| `MediaAsset` | Stable media identity and managed content |
| `Folder` and `Tag` | Recipe-library organization |

References across aggregates use stable domain identifiers. Child values that
only make sense within one parent, such as an instruction step or pantry
holding, may be owned and mutated through that aggregate.

## Recipe identity and history

`Recipe` is the durable identity people organize, search for, and refer to.
`RecipeRevision` contains the maintained content at a point in time. Planned
cooks and cooking sessions retain the specific revision they used so that
history remains intelligible after later edits.

The authored language of that content belongs to the revision, not to the
application's current locale. `RecipeRevision.contentLanguage` is an optional
canonical BCP 47 language tag so existing content may remain explicitly unknown,
imports can preserve source language when available, and localized bundled
recipes do not lose their language after persistence. Display-language selection
and localized interface strings remain outside the domain.

Creating a revision is an intentional domain action. SwiftData save history and
CloudKit conflict metadata are implementation details and do not substitute for
recipe revisions.

A Recipe is born only when its first explicit Save Revision operation succeeds.
Each immutable Revision names zero, one, or many parent Revisions. Immutable
Selection evidence, not a clock, revision number, device, delivery order, or
mutable pointer, determines which existing Revision is presented as current.
Concurrent branches survive until a person chooses one existing Revision or
saves a multi-parent reconciliation. Deletion and restoration form a separate
disposition history, and pruning leaves compact anti-resurrection evidence.
The additive physical representation and legacy migration are frozen in the
[Recipe authority V5 persistence contract](recipe-authority-v5-schema.md).

## Cooking Session evidence

A `CookingSession` is one device-independent performance of one retained recipe
revision. Its root captures a canonical `ExecutionSnapshot` containing the
material needed to understand that performance even when the recipe changes
later. Snapshot ingredient and instruction identities belong to the Session;
optional source identities preserve provenance without making the mutable recipe
the authority for historical meaning.

Accepted activity is an unordered retained evidence set: immutable `SessionFact`
values form a causal graph rooted at the Session, and an optional
`SessionClosure` commits the exact snapshot digest, causal heads, closed
projection digest, and outcome. Delivery order and exact physical duplicates do
not affect reconstruction. Concurrent facts preserve independent work and expose
competing values as typed conflicts. Stop and Resume are activity facts;
Finished is absorbing and comes only from a valid Closure. Evidence arriving
outside that Closure remains retained as late evidence and cannot silently alter
the finished projection. Continuing begins a new Session with paired source
provenance and a copied, explicitly mapped baseline.

Deletion is a separate disposition graph. It hides neither Session evidence nor
conflict state, restoration must explicitly descend from the deletion it
resolves, and concurrent deletion/restoration is surfaced as needing attention.
The projector has exactly three result classes: a complete Session projection,
`UnavailableSession` for retained evidence the current reader cannot yet
reconstruct, or `SessionRecovery` for invalid or contradictory evidence. It does
not synthesize a plausible partial Session.

## Persistence boundary

The first persistence implementation uses SwiftData records such as
`KitchenRecord`, `RecipeRecord`, and `RecipeRevisionRecord`. A repository maps
between those records and domain values.

Persistence records may differ structurally from the domain when required for
queries, migrations, performance, or CloudKit compatibility. In particular,
domain invariants should not be weakened merely because a storage framework
requires optional relationships or cannot enforce uniqueness.

The implemented persistence slice remains:

```text
Kitchen → Recipe → RecipeRevision
```

The current repository still uses that payload graph and its legacy mutable
current pointer. V5 registers the additive authority record families and
migration stage, but repository commands and projection remain a later
implementation slice.

The remaining aggregates establish ownership and identity seams now but are
implemented only as their product workflows arrive.

## Synchronization boundary

CloudKit is the selected Apple-native synchronization and collaboration
platform. SwiftData managed CloudKit synchronization may serve private data
across one person's devices. A shared Kitchen additionally requires participant
invitations, permissions, private and shared database scopes, acceptance and
leaving, and collaboration conflict behavior.

The exact CloudKit integration remains behind the repository and sync boundary.
It may use managed SwiftData synchronization, Core Data CloudKit integration,
direct CloudKit APIs, or a composition as platform capabilities require.

## Content portability

Import and export provide content sovereignty. Export is a documented,
versioned domain representation rather than a copy of the SwiftData store. It
preserves stable identifiers, meaningful recipe content, source evidence,
provenance, and media needed to reconstruct the exported scope.

Storage migrations and CloudKit schema changes therefore do not define the
portable format.

## Module organization

Use one `KitchenKit` Swift module, organized into Domain, Import, Logic, and
Persistence responsibility folders. Separate compiler modules for recipes,
kitchens, pantry, planning, sessions, importing, and storage would expose
dependencies among capabilities that every store client consumes together.
Architectural seams remain explicit in interfaces and source organization
without becoming separately linked products.

The implemented Domain responsibility begins with the
`Kitchen → Recipe → RecipeRevision` slice. The shared `KitchenMemory/`
application layer owns deterministic starter resources and their loader, and
the native multiplatform app target compiles that layer for iOS and Mac. This keeps Apple resource APIs out
of Domain without creating a framework for app-specific data.

The Persistence responsibility supplies SwiftData adapters behind that seam.
Recipe rows use application-owned UUID foreign keys and explicit ordering
columns behind `RecipeRepository`. Cooking Sessions use a separate
`CookingSessionRepository`: five immutable document-evidence record families,
scalar UUID associations, complete append transactions, and classified reads
through the deterministic evidence projector. Neither callers nor domain values
depend on SwiftData model identity or CloudKit metadata.

The initial store uses SwiftData's standard location. Slice 10 adds private
cross-device synchronization behind the same repository boundary after a
focused prototype selects the CloudKit integration and proves recovery behavior.
Shared-Kitchen collaboration remains a separate problem involving participants,
permissions, and shared database scope. The database is not the export format.
The store evolves through immutable schema definitions and an ordered migration
plan. Released V1 remains unchanged, V2 adds recipe deletion disposition, and V3
adds Cooking Session evidence through a second lightweight stage. Production
CloudKit evolution is additive: new feature aggregates may add types and fields,
while published schema elements keep their original meaning.

The Logic responsibility supplies the product operations. `RecipeLibrary` is the
Kitchen-scoped service for loading library content, creating and revising recipes,
interpreting imports, managing bundled samples, and performing an explicitly
confirmed reset without exposing SwiftData records. Scaling state and bootstrap
remain separate because they have different lifecycles. The app's observable
model projects library outcomes into selection and presentation state; the
recipe view then reads the persistent current revision through ordered
ingredients and steps.
