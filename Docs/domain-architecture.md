<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# Domain architecture

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
Application use cases and repository interfaces
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

## Package organization

Use one `KitchenMemoryDomain` Swift package, organized by feature. Separate
packages for recipes, kitchens, pantry, planning, and sessions would create
dependencies among concepts that intentionally share identities and rules.

The implemented `KitchenMemoryDomain` package begins with the
`Kitchen → Recipe → RecipeRevision` slice. Its sibling
`KitchenMemorySampleData` target owns deterministic sample resources without
introducing Apple resource APIs into the domain target.
