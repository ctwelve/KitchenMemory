# Domain architecture

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


- Status: Accepted direction
- Date: 2026-08-10

## Purpose

Kitchen Memory separates cooking concepts from storage and synchronization.
The domain describes what the household means; persistence records describe how
that meaning is stored; synchronization describes how stored changes move among
devices and people.

```text
KitchenMemoryDomain
        ↓
KitchenMemoryLogic and domain-facing repository interfaces
        ↓
SwiftData persistence records and mapping
        ↓
CloudKit synchronization and sharing
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
│   └── CookingDeviation[]
├── SourceCapture[]
├── MediaAsset[]
├── Folder[]
└── Tag[]
```

Only the Kitchen, Recipe, and RecipeRevision portion is implemented today. The
remaining branches are accepted ownership direction for later product slices,
not claims about current source types or persistence tables.

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
| `CookingSession` | One actual performance, progress, deviations, and outcome |
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

## Persistence boundary

The first persistence implementation uses SwiftData records such as
`KitchenRecord`, `RecipeRecord`, and `RecipeRevisionRecord`. A repository maps
between those records and domain values.

Persistence records may differ structurally from the domain when required for
queries, migrations, performance, or CloudKit compatibility. In particular,
domain invariants should not be weakened merely because a storage framework
requires optional relationships or cannot enforce uniqueness.

The initial implemented slice is:

```text
Kitchen → Recipe → RecipeRevision
```

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

Use one `KitchenMemoryDomain` module, organized by feature. Separate modules for
recipes, kitchens, pantry, planning, and sessions would create dependencies among
concepts that intentionally share identities and rules. The app's internal
modules are native Xcode framework targets in root-level folders; they
are not separately distributed packages.

The implemented `KitchenMemoryDomain` module begins with the
`Kitchen → Recipe → RecipeRevision` slice. The shared `KitchenMemory/`
application layer owns deterministic starter resources and their loader, and
both native app targets compile that layer. This keeps Apple resource APIs out
of the domain module without creating a framework for app-specific data.

`KitchenMemoryPersistence` is the first SwiftData adapter behind that boundary.
It uses internal relational records with application-owned UUID foreign keys and
explicit ordering columns. A domain-facing repository performs all mapping, so
neither callers nor domain values depend on SwiftData model identity. The first
repository supports saving and loading a kitchen, a recipe's current revision,
and its saved revision history (newest first).

The initial store uses SwiftData's standard location. Slice 10 adds private
cross-device synchronization behind the same repository boundary after a
focused prototype selects the CloudKit integration and proves recovery behavior.
Shared-Kitchen collaboration remains a separate problem involving participants,
permissions, and shared database scope. The database is not the export format.
It is installed through an explicit V1 migration plan. Before first release V1
may change with a development-store reset; after release, later schema changes
add immutable versions and deliberate migration stages. Production CloudKit
evolution is additive: new feature aggregates may add types and fields, while
published schema elements keep their original meaning.

`KitchenMemoryLogic` supplies the product operations. `RecipeLibrary` is the
Kitchen-scoped module for loading library content, creating and revising recipes,
interpreting imports, managing bundled samples, and performing an explicitly
confirmed reset without exposing SwiftData records. Scaling state and bootstrap
remain separate because they have different lifecycles. The app's observable
model projects library outcomes into selection and presentation state; the
recipe view then reads the persistent current revision through ordered
ingredients and steps.
