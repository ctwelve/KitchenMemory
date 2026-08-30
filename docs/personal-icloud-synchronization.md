# Personal iCloud synchronization

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
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
KitchenKit's Persistence responsibility. Its Domain and Logic responsibilities,
`RecipeRepository`, and `CookingSessionRepository` expose no CloudKit types.

```text
RecipeLibraryModel
        │
KitchenKit Logic
        │ domain-facing RecipeRepository
        ▼
SwiftDataRecipeRepository
        │
local SwiftData store ⇄ private CloudKit database
```

Cooking Sessions use a parallel `SwiftDataCookingSessionRepository` over that
same store. It reconstructs and classifies immutable V3 evidence before Logic
sees a Session; managed CloudKit delivery order and physical identity never
cross the seam.

`AppRuntime` retains that repository, the Kitchen-scoped `CookingSessions`
Logic module, and its observable application projection beside the Recipe
Library for the process lifetime. Cooking Session composition remains separate
from `RecipeLibrary` and `RecipeRepository`; they share the configured model
container without collapsing their responsibility seams.

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

`Develop` launches use the private database in
`iCloud.net.ctwelve.dev.KitchenMemory`; `Production` uses
`iCloud.net.ctwelve.KitchenMemory`. They select the Development and Production
CloudKit environments respectively. The multiplatform `KitchenMemory` target
selects separate iOS and macOS entitlement files while retaining those
environment-specific containers. SDK-qualified settings select separate iOS
and macOS property lists, so the iOS remote-notification background declaration
is not carried into the Mac product. `Debug`, `Testing`, and the non-distributable
`ProductionTesting` UI-smoke hosts use explicit local or in-memory stores and
never require an iCloud account.

Develop and Production preserve the pre-0.1.2 synchronization behavior by
default, but Settings lets a person opt this device out. The shared application
preferences store gives that key device-local scope rather than iCloud scope:
disabling sync on a travel Mac must not silently disable it on an iPhone at
home. The same named durable store changes between SwiftData's explicit
`.private` and `.none` CloudKit configurations; recipe content never moves into
an alternate store. Because a `ModelContainer` selects its CloudKit database
when constructed, a change is recorded immediately but takes effect on the next
clean app launch.
SwiftData history remains in that durable store during local-only launches; a
repository test reopens the store and verifies those transactions are still
available for reconnection. The signed multi-device acceptance exercise remains
the authority for confirming that managed CloudKit exports that retained work.

The sample-recipe onboarding answer is a small cross-device preference, not
recipe content. Cloud-enabled builds mirror it in `UserDefaults` for offline
startup and synchronize it through `NSUbiquitousKeyValueStore`. Incoming iCloud
changes update the visible startup state, but the app never assumes that the
preference arrives immediately. A Kitchen already present before local
bootstrap, or recipe content arriving through CloudKit, independently proves
that the Kitchen is established and suppresses an inapplicable first-run prompt.
The answer remains authorization for one requested sample installation; it is
not authority to restore or download samples automatically on another device.

The current Cooking Session pointer and the single pending lifecycle-command
outbox use ordinary device-local `UserDefaults`. They are never mirrored into
`NSUbiquitousKeyValueStore`: selection is not shared lifecycle authority, and a
stable intention must remain on the device that accepted it until local
durability is confirmed. CloudKit synchronizes only retained Cooking Session
evidence in the SwiftData store.

Managed CloudKit imports post a persistent-store remote-change notification.
KitchenKit's Persistence responsibility converts that callback into a concurrency-safe
refresh signal; the application composition root connects it to
`RecipeLibraryModel` and `CookingSessionPresentationModel` after each model has
completed its initial load. Each projection then reloads retained repository
evidence and lets Domain and Logic classify it. This keeps Core Data and
CloudKit callback mechanics out of Domain and Logic while avoiding an early
notification bypassing sample-onboarding state. A notification, account state,
or successful framework event requests a refresh; none proves that a Session
Fact arrived or that synchronization is globally complete.

Settings reports the current iCloud account availability and the public managed
CloudKit setup, import, and export event state. It never equates “account
available” with “every record has synchronized”: an in-progress event says
syncing, a completed error says attention is required, and a successful event
returns to available. Account-change notifications trigger a fresh check.

Re-enabling synchronization after a local-only launch is a reconnection, not a
simple inverse toggle. The app requires explicit confirmation before recording
that choice and explains that this device's recipes and revision history will
merge with the iCloud copy on the next launch. Managed CloudKit then imports and
exports changes accumulated while the copies were disconnected. The person is
asked to review the combined library after sync completes rather than treating
either copy as an unquestionable backup.

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
the recipe graph. The mutable `RecipeRecord.currentRevisionID` is not allowed to
erase a competing branch merely because CloudKit resolves that pointer with
last-writer-wins: the repository considers every immutable revision carrying the
recipe UUID. The highest revision number wins; equal revision numbers use the
revision UUID as a stable tie-breaker. Every revision remains in history.

V2 makes deletion equally explicit. A reset writes an append-only deletion
marker before physically removing recipe content. Any unresolved marker hides
stale recipe rows that later return from a disconnected device. An explicit
restore writes a resolution for each deletion marker that device has actually
observed; deleting a marker is never used as distributed restoration intent.
Markers and resolutions may arrive in any order or be duplicated without
changing the eventual result. This is a repository reconciliation rule, not a
CloudKit type exposed to Domain or Logic.

Together these rules make edit, delete, and observed-restore outcomes converge
without confusing an internal CloudKit record name with product identity. The
signed multi-device acceptance matrix still verifies Apple's transport and the
person-facing recovery sequence before release.

After the first production schema is deployed:

- never remove, rename, or repurpose a published record type or field;
- add a new immutable SwiftData schema version and tested migration for local
  changes;
- add CloudKit record types and fields additively; and
- validate older app versions and offline data before promotion.

Kitchen Memory 0.1.2 introduced `KitchenMemorySchemaV2` through a lightweight
local migration and two additive CloudKit record types for recipe deletion and
deletion resolution. The V1 record types and fields remain unchanged. Those new
types must be initialized, reviewed, and deployed to the production container
before a V2 build is distributed.

Kitchen Memory 0.2 implements `KitchenMemorySchemaV3` as a second lightweight
stage. It adds exactly the five generated entities `CookingSessionRecord`,
`SessionFactRecord`, `SessionClosureRecord`, `SessionDeletionRecord`, and
`SessionDeletionResolutionRecord`; their generated names match the frozen
contract. They use scalar UUID attributes, schema-compatible placeholders,
ordinary inline `Data`, and no relationships, uniqueness constraints, or local
indexes. Repository validation prevents placeholders or partial evidence from
becoming ordinary state. V1 and V2 model definitions remain unchanged.

V3 Session deletion uses the same explicit causal principle without reusing the
Recipe-reset mechanism. Delete appends a `SessionDeletionRecord`; Restore appends
one `SessionDeletionResolutionRecord` for each unresolved deletion marker the
device has actually observed. CloudKit may deliver roots, Facts, Closures,
deletions, and resolutions in any order. Missing dependencies therefore wait
for more Session data, while collisions and invariant violations remain in the
separate Recovery destination. Neither a successful CloudKit event nor absence
of a row authorizes restoration, and no relationship cascade removes a Recipe,
source Session, continuation, Fact, Closure, or snapshot.

Deleted Session evidence has no automatic expiry or pruning in 0.2. It remains
in the person's private local store and, when enabled, private iCloud database
so Restore and deterministic reconstruction remain possible. Empty Deleted
Items and permanent erasure require a later contract that can prove dependency
safety across asynchronously participating devices.

## Migration authority

Kitchen Memory does not infer whether a migration ran by repeatedly examining
recipe content. SwiftData structural changes are declared through immutable
`VersionedSchema` types and `KitchenMemoryMigrationPlan`; the persistent store's
schema metadata is the authority for which structural stages remain.

Version 0.1.1 makes a direct cutover from the released
`sampleRecipes.consent` key to the typed `sampleRecipesConsent` key in both
UserDefaults and iCloud key-value storage. `DefaultsKitchenPreferencesStore`
centralizes typed serialization, stable key names, defaults, and observation.
The Defaults package provides timestamp conflict resolution and transport
through `NSUbiquitousKeyValueStore`; Kitchen Memory still assigns each key's
scope and clears the onboarding answer when the iCloud account changes. It does
not migrate or dual-write the old preference. An alpha user may therefore be
asked for the sample-recipe choice again after updating; recipe content is not
changed or removed.

Future data rewrites that do not change the SwiftData schema need an equally
explicit, durable migration ledger. They must not become content probes that
scan a person's Kitchen on every launch, and they must not rely on private Core
Data metadata.

## 0.1 production deployment record

The first production schema for `iCloud.net.ctwelve.KitchenMemory` was deployed
on 2026-08-24 for accepted source commit `98038e9`. The deployment preview
contained nine Kitchen Memory record types, the expected indexes, and the
standard `_world`, `_icloud`, and `_creator` security roles. No record type,
field, index, or role deletion appeared in the preview.

Final comparison against the frozen V1 model found four fields missing from the
production container's Development schema. They were added and reviewed before
deployment:

- `CD_prepSeconds`, `CD_cookSeconds`, and `CD_totalSeconds` on
  `CD_RecipeRevisionRecord` as queryable and sortable integer fields; and
- `CD_customDisplayText` on `CD_RecipeIngredientRecord` as a queryable,
  searchable, and sortable string field.

After deployment, Production was inspected directly: all nine application
record types were present, both affected record types contained 22 fields, and
the expected custom-display and duration indexes were visible. This deployment
freezes the published V1 names and meanings under the additive-evolution rules
above. It does not substitute for the still-open two-device production recovery
matrix in [0.1 release evidence](release-evidence-0.1.md).

## Development schema workflow

Schema administration is an explicit development operation, not application
startup behavior.

1. Build and sign the `KitchenMemory` scheme with the `Develop` configuration
   for My Mac. Its distinct app identifier gives the Development store its own sandbox,
   while its entitlements select the separate
   `iCloud.net.ctwelve.dev.KitchenMemory` container.
2. Launch that Mac app once with `--initialize-cloudkit-schema`.
3. Inspect record types, indexes, and security roles in CloudKit Console.
4. Exercise create, edit, delete, offline, reconnect, and concurrent-edit paths
   on at least two devices using the same development iCloud account.
5. Reset the development environment only when a deliberate pre-release
   incompatible correction is authorized.
6. Deploy the schema to production only as a deliberate release operation.

The Develop-and-macOS-only argument temporarily hands the Development app's
default store to
`NSPersistentCloudKitContainer`, asks it to initialize the development schema,
unloads that store, and then lets the ordinary SwiftData container open it.
The initializer builds the complete V3 managed model; it remains an explicit
one-shot operation and does not imply Production promotion.
The initializer lives with the rest of the store implementation in
`Persistence/Cloud`. iOS, Debug, Testing, ProductionTesting, and
Production builds do not contain this switch. Ordinary Development and
Production launches still create their initial local Kitchen without schema
administration; the one-shot operation publishes server schema, not user data.

Production schema deployment is one-way in practical terms. It must never be a
routine build step, CI action, or automatic launch task.

Development and Production intentionally use different CloudKit containers as
well as different app identifiers. Before a release schema is promoted, its
additive definition must be initialized and reviewed in the production
container's Development environment, then deliberately deployed to that
container's Production environment. The ordinary Development app never receives
the production container entitlement.

No current shared scheme performs that production-container administration.
Adding one is release-engineering work: it must use an explicitly reviewed,
Mac-only configuration and must not turn schema initialization or deployment
into an ordinary build, archive, or application-launch side effect.

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
