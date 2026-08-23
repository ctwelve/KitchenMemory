# Personal iCloud synchronization

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

Kitchen Memory 1.0 synchronizes one person's local recipe library between their
iPhone, iPad, and Mac through the private CloudKit database. Local SwiftData
storage remains authoritative while offline; CloudKit transports changes when
the person's iCloud account and network are available.

This is deliberately narrower than a shared Kitchen. Multi-person membership,
invitations, permissions, attribution, and shared-database ownership remain a
post-1.0 product slice. The first integration must not erase those concepts or
make them SwiftData concerns.

## Architectural boundary

The application composition root asks `KitchenMemorySchema` for either a local
store or a private-CloudKit store. The choice and container identifier live in
`KitchenMemoryPersistence`. `KitchenMemoryDomain`, `KitchenMemoryLogic`, and
`RecipeRepository` expose no CloudKit types.

```text
RecipeLibraryModel
        │
KitchenMemoryLogic
        │ domain-facing RecipeRepository
        ▼
SwiftDataRecipeRepository
        │
local SwiftData store ⇄ private CloudKit database
```

This preserves two independent identities:

- `Kitchen.ID` is the durable product identity used by recipes and future
  cooking sessions.
- CloudKit record identity and database scope are transport details.

Fresh installations use the same deterministic personal `Kitchen.ID`. Because
each iCloud account has an isolated private database, this joins one person's
independently started devices without joining unrelated people. Existing
pre-sync development data keeps its Kitchen identity until the development
store is reset.

A future sharing adapter may map a Kitchen into CloudKit shared records or a
direct CloudKit hierarchy, then add membership and authorization operations at
the Logic boundary. Recipe ownership continues to point at `Kitchen.ID`; it
does not need to be rewritten merely because the transport scope changes.

## Runtime configuration

Production and ordinary development launches use the private database in
`iCloud.net.ctwelve.KitchenMemory`. The application target enables iCloud,
push notifications, and the remote-notification background mode. SwiftData
tests, previews, and UI smoke tests use explicit local or in-memory stores and
never require an iCloud account.

Managed CloudKit imports post a persistent-store remote-change notification.
The application adapter converts that notification into a
`RecipeLibraryModel` refresh after the model has completed its initial load.
This keeps notification mechanics out of the reusable frameworks and avoids an
early notification bypassing sample-onboarding state.

Settings reports the current iCloud account availability and the public managed
CloudKit setup, import, and export event state. It never equates “account
available” with “every record has synchronized”: an in-progress event says
syncing, a completed error says attention is required, and a successful event
returns to available. Account-change notifications trigger a fresh check.

## Schema rules

SwiftData's managed CloudKit integration requires persisted attributes to be
optional or have schema defaults and does not support unique constraints. The
V1 record defaults exist solely so CloudKit can instantiate records; domain
initializers still supply every meaningful value, and repository reconstruction
must never treat a schema placeholder as trusted product data.

Stable domain UUIDs remain the application's logical identity and idempotency
key. They support sample installation and later reconciliation without making
CloudKit's internal record names part of the domain contract. Before 1.0, the
development V1 store and development CloudKit environment may be reset when an
incompatible correction is necessary.

Because managed CloudKit synchronization cannot enforce SwiftData uniqueness,
two offline devices can still create separate storage rows carrying the same
domain UUID. Repository reads collapse those rows by logical identity throughout
the recipe graph. If concurrent edits point one recipe UUID at different
immutable revisions, the highest revision number wins; equal revision numbers
use the revision UUID as a stable tie-breaker. Both revisions remain in history.
This rule gives every device the same result without confusing an internal
CloudKit record name with product identity. Deletion conflicts and user-facing
revision recovery still require the multi-device acceptance exercises before
1.0.

After the first production schema is deployed:

- never remove, rename, or repurpose a published record type or field;
- add a new immutable SwiftData schema version and tested migration for local
  changes;
- add CloudKit record types and fields additively; and
- validate older app versions and offline data before promotion.

Cooking sessions therefore become a new aggregate and new additive records in
0.2. They do not require columns to be reserved in recipe records now.

## Development schema workflow

Schema administration is an explicit development operation, not application
startup behavior.

1. Build and sign a Debug application with the development iCloud container.
2. Launch it once with `--initialize-cloudkit-schema`.
3. Inspect record types, indexes, and security roles in CloudKit Console.
4. Exercise create, edit, delete, offline, reconnect, and concurrent-edit paths
   on at least two devices using the same development iCloud account.
5. Reset the development environment when a pre-release incompatible V1
   correction is intentional.
6. Deploy the schema to production only as a deliberate release operation.

The Debug argument temporarily hands the default store to
`NSPersistentCloudKitContainer`, asks it to initialize the development schema,
unloads that store, and then lets the ordinary SwiftData container open it.
Release builds do not contain this switch.

Production schema deployment is one-way in practical terms. It must never be a
routine build step, CI action, or automatic launch task.

## 1.0 validation boundary

Automated tests prove local repository behavior, CloudKit configuration
selection, deterministic Kitchen bootstrap, and remote-change refresh wiring.
Apple's service itself still requires device-level integration exercises:

- changes made on iPhone appear on iPad and Mac;
- local reading and editing work while offline and converge after reconnect;
- deletes and concurrent edits settle without corrupting revision ownership;
- sample installation remains idempotent across devices; and
- signed release-like builds report understandable account or sync failures.

Those exercises are release evidence, not substitutes for deterministic
business-logic tests.
