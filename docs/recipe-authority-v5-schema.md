# Recipe authority V5 persistence contract

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Decision-frozen; logic and Development-schema smokes passed
- Decided: 2026-09-03
- Scope: Additive SwiftData and managed-CloudKit authority for Recipe creation,
  revision ancestry, current selection, deletion, restoration, and pruning

This document freezes the smallest additive authority model selected by
[issue #104](https://github.com/ctwelve/KitchenMemory/issues/104). It does not
implement V5, initialize a CloudKit schema, deploy Production changes, or
authorize physical pruning. The throwaway
[prototype branch](https://github.com/ctwelve/KitchenMemory/tree/e04dbaf)
did not falsify the representation and is intentionally absent from the
production branch.

The contract applies the domain/persistence boundary in
[ADR 0003](adr/0003-domain-persistence-boundary.md), the additive CloudKit
policy in [ADR 0004](adr/0004-apple-persistence-and-portability.md), and the
alpha-to-beta boundary in
[ADR 0016](adr/0016-alpha-data-contract-and-beta-stabilization.md). The
authority decision itself is recorded in
[ADR 0017](adr/0017-use-additive-recipe-authority-evidence.md).

## Governing invariants

- A Recipe is born only when its first Save Revision operation succeeds.
- A Recipe Revision is immutable maintained intent. Every accepted Save names
  exactly zero, one, or many parent Revision identities.
- Save Revision is an explicit idempotent operation with a caller-supplied
  command identity and preallocated Recipe and Revision identities.
- Currentness comes only from immutable Recipe Selection evidence. Clocks,
  devices, delivery order, revision numbers, and mutable pointers are never
  authority.
- Choosing an existing Revision writes Selection evidence; it does not copy or
  renumber the Revision. Granular reconciliation writes a new multi-parent
  Revision.
- Deletion is reversible disposition evidence independent of Revision
  ancestry and selection. Restoration resolves only deletions it observed.
- Pruning removes payload only after the retention policy permits it and leaves
  compact evidence that prevents a disconnected device from resurrecting the
  item.
- Exact physical duplicates converge. Conflicting reuse of a logical identity
  requires recovery and never silently overwrites accepted evidence.
- A Recipe projector returns an available Recipe, a deliberately deleted Recipe,
  a compact pruned tombstone, an unavailable result for insufficient retained
  evidence, or a recovery result for evidence that positively violates an
  invariant. It never invents a plausible Recipe.
- Existing Recipe and Cooking Session snapshot payloads remain readable and
  keep their identities.

## Shapes considered

### Mutate the V1 Recipe row

Making `RecipeRecord.currentRevisionID` authoritative is compact but lets
last-writer-wins transport erase a concurrent selection. It also repurposes a
published field and cannot preserve explicit selection ancestry. Rejected.

### Store one row per graph edge

Separate parent and selection-edge rows are easy to query, but CloudKit may
deliver a logical operation one edge at a time. A reader then cannot distinguish
an incomplete parent set from the complete operation the author intended.
Rejected.

### Store immutable authority envelopes

One small immutable row carries each accepted operation and its complete set of
observed heads or parents. Existing Recipe payload rows remain unchanged. This
shape preserves concurrency, makes partial delivery classifiable, and stays
within managed-CloudKit's additive scalar-attribute constraints. Selected.

## Authoritative record family

V5 adds exactly three SwiftData model types and extends the two existing V2
disposition types with optional/defaulted scalar attributes. The authority
family has no SwiftData relationships, uniqueness constraints, cascade rules,
ordered relationships, or mutable authoritative projection fields. All
associations use scalar Kitchen Memory UUIDs. Required attributes have
declaration defaults solely so managed CloudKit can instantiate records;
repository validation never treats a default as valid domain evidence.

### `RecipeSaveRecord`

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `UUID` | Stable Save command identity and retry key. |
| `kitchenID` | `UUID` | Owning Kitchen identity and query routing. |
| `recipeID` | `UUID` | Recipe created or extended by the Save. |
| `revisionID` | `UUID` | Exact immutable Revision accepted by the Save. |
| `savedAt` | `Date` | Descriptive chronology only; never authority. |
| `ancestryFormatVersion` | `Int` | Parent-set codec contract. |
| `parentRevisionIDsData` | `Data` | Complete canonical set of zero, one, or many parent Revision identities. |
| `payloadManifestFormatVersion` | `Int` | Revision-payload manifest codec contract. |
| `payloadManifestData` | `Data` | Complete canonical inventory and ordering of rows required to reconstruct the Revision. |
| `revisionFormatVersion` | `Int` | Canonical Recipe Revision digest codec contract. |
| `revisionDigest` | `Data` | SHA-256 of the complete canonical Recipe Revision value. |

The payload manifest names the root Revision row and every ordered media,
equipment, ingredient-section, ingredient, instruction-section, and step row
that belongs to it. It does not duplicate authored recipe content. A reader can
therefore recognize a partially delivered payload as unavailable. Once every
manifest entry is present, the digest proves that the reconstructed value is
the exact Revision the Save accepted.

For the first Save, `parentRevisionIDsData` is empty. A normal edit names one
parent. A granular reconciliation names every Revision whose maintained intent
the new Revision reconciles. A Save may not name its own Revision as a parent.

### `RecipeSelectionRecord`

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `UUID` | Stable Select command identity and retry key. |
| `kitchenID` | `UUID` | Owning Kitchen identity and query routing. |
| `recipeID` | `UUID` | Recipe whose presentation is selected. |
| `selectedRevisionID` | `UUID` | Existing accepted Revision chosen for presentation. |
| `selectedAt` | `Date` | Descriptive chronology only; never authority. |
| `frontierFormatVersion` | `Int` | Observed-selection frontier codec contract. |
| `observedSelectionIDsData` | `Data` | Complete canonical set of maximal Selection identities observed by this command. |

The first Selection observes an empty frontier and is written with the first
Save. A later Selection resolves only the maximal Selection evidence it names.
Concurrent selections therefore remain visible until a new selection observes
all competing heads. Several maximal Selection records are not a conflict when
they all select the same Revision.

### Extended `RecipeDeletionRecord`

| Field | Type | Meaning |
| --- | --- | --- |
| existing `id` | `UUID` | Stable Delete command identity and retry key. |
| existing `kitchenID` | `UUID` | Owning Kitchen identity and query routing. |
| existing `recipeID` | `UUID` | Recipe removed from ordinary presentation. |
| new `deletedAt` | `Date?` | Descriptive retention input when known; never reconciliation authority. |

The new optional date preserves every legacy row without manufacturing
chronology. New Delete commands always supply it.

### Extended `RecipeDeletionResolutionRecord`

| Field | Type | Meaning |
| --- | --- | --- |
| existing `id` | `UUID` | Stable Restore command identity and retry key. |
| new `kitchenID` | `UUID?` | Owning Kitchen identity and query routing; absent only on an unbackfilled legacy row. |
| existing `recipeID` | `UUID` | Recipe returned to ordinary presentation. |
| existing `deletionID` | `UUID` | Exact observed Deletion evidence this row resolves. |
| new `restoredAt` | `Date?` | Descriptive chronology when known; never authority. |

One Restore operation writes one Restoration row for every unresolved Deletion
the initiating device has observed. The rows are committed atomically locally.
A concurrent unobserved Deletion remains unresolved after synchronization. V5
backfill derives `kitchenID` from the validated owning Recipe; new Restore
commands always supply both new attributes. Projection accepts an absent Kitchen
identity only through the bounded legacy adapter until that backfill completes.

### `RecipePruneRecord`

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `UUID` | Stable Prune command identity and retry key. |
| `kitchenID` | `UUID` | Owning Kitchen identity and query routing. |
| `recipeID` | `UUID` | Recipe whose reconstructable payload was removed. |
| `prunedAt` | `Date` | Descriptive time physical removal completed locally. |
| `antiResurrectionUntil` | `Date` | Earliest policy date at which this compact evidence may be reconsidered for removal. |
| `frontierFormatVersion` | `Int` | Authority-frontier envelope codec contract. |
| `frontierData` | `Data` | Complete canonical Revision, Selection, and disposition frontier observed by the Prune. |
| `frontierDigest` | `Data` | SHA-256 of the exact stored frontier bytes. |

The frontier records maximal Revision and Selection identities plus the
Deletion and Restoration identities needed to explain disposition. It carries
no authored recipe content. Multiple valid Prune records converge by union; no
clock chooses a winner. V5 policy retains anti-resurrection evidence for five
years after pruning. A later contract may extend retention but may not shorten
evidence already promised by a stored record.

## Canonical envelopes

Format version 1 identifier sets are sorted ascending by the 16 raw UUID bytes,
contain no duplicates, and concatenate those bytes without delimiters. The
empty set is zero bytes. Decoders reject malformed length, duplicates, and
non-canonical ordering.

Payload-manifest format 1 is a canonical binary document containing the root
Revision identity and the ordered logical identities for every supported child
family. Authority-frontier format 1 is a canonical binary document containing
named canonical identifier sets for Revision heads, Selection heads, Deletions,
and Restorations. Their exact byte layouts and golden fixtures are part of the
V5 implementation in #105; changing a frozen layout requires a new format
version, never an in-place reinterpretation.

`revisionDigest` is SHA-256 of a canonical, persistence-independent encoding of
the complete `RecipeRevision` value. The encoding includes authored order and
all optional-value presence. It excludes storage-row identity, CloudKit
metadata, and the descriptive `savedAt` value.

## Identity and duplicate rules

The application mints every command and domain identity before persistence.
Rows sharing a logical `id` are grouped before projection:

- byte-for-byte equivalent authoritative fields are exact physical duplicates
  and coalesce;
- a mismatch under one logical identity is a command collision and yields
  recovery; and
- a retry succeeds only when its complete command envelope, manifest, digest,
  and reconstructed payload match the accepted operation.

No CloudKit record name or SwiftData object identity enters these comparisons.
Every referenced row must carry the same `kitchenID` and correct Recipe or
Revision ownership. Cross-owner evidence is rejected, never claimed or merged.

## Local transaction boundaries

Each user intention is one local SwiftData transaction:

| Intention | Atomically committed records |
| --- | --- |
| First Save Revision | Existing V1 Recipe payload graph, `RecipeSaveRecord`, and initial `RecipeSelectionRecord` |
| Later Save Revision | Complete new Revision payload graph, `RecipeSaveRecord`, and `RecipeSelectionRecord` |
| Choose existing Revision | One `RecipeSelectionRecord` |
| Delete | One extended `RecipeDeletionRecord` |
| Restore | One extended `RecipeDeletionResolutionRecord` per observed unresolved Deletion |
| Prune | One `RecipePruneRecord` plus physical removal of reconstructable Recipe payload and covered authority rows |

The first transaction is the birth boundary: failure leaves neither a Recipe
nub nor authoritative Save/Selection evidence. Local atomicity does not imply
atomic CloudKit transport. Every prefix and permutation of synchronized rows is
therefore valid projector input.

## Projection and partial delivery

The authority projector is a pure repository-side function. It validates
logical duplicates, ownership, codecs, manifests, digests, references, and
acyclic Revision and Selection graphs before returning one of five classes:

1. **Available** — all required payload exists, no Deletion is unresolved, and
   one unambiguous selected Revision can be reconstructed.
2. **Deleted** — all authority and payload needed for inspection or restoration
   is valid, but at least one Deletion remains unresolved. It is hidden from the
   ordinary library.
3. **Pruned** — one or more valid Prune records remain while the payload and
   authority they cover are absent. The compact tombstone is hidden and is not
   mistaken for incomplete synchronization.
4. **Unavailable** — recognized evidence lacks a referenced Save, Selection,
   parent, or manifest row, or the reader does not support a declared format.
   More synchronization or a newer reader may complete it.
5. **Recovery** — complete retained evidence collides, crosses ownership,
   violates a manifest or digest, forms a cycle, selects a non-member Revision,
   contains competing maximal selections, or arrives behind retained Prune
   evidence.

Revision heads are the accepted Saves that are not parents of another accepted
Save. They preserve concurrent branches but do not independently decide
currentness. Selection heads are accepted Selections not named by another
Selection's observed frontier. One selected Revision is ordinary currentness;
different selected Revisions require an explicit choice or reconciliation.

Any unresolved Deletion hides the Recipe independently of Revision and
Selection state. A Restoration resolves only its named Deletion. A late payload
or authority row for a Recipe carrying retained Prune evidence is withheld and
routed to recovery; it never recreates an ordinary Recipe merely because its
CloudKit row arrived later.

`RecipeRecord.currentRevisionID` remains a deployed V1 compatibility field. It
may be maintained as a disposable local index while older builds exist, but V5
projection, retry, conflict, deletion, restoration, and pruning decisions must
not read it as authority.

## Migration from V4

V4-to-V5 is an additive lightweight schema stage followed by an
application-owned, retry-safe backfill ledger. The schema stage introduces the
three new model types, adds optional `deletedAt` to `RecipeDeletionRecord`, and
adds optional `kitchenID` plus optional `restoredAt` to
`RecipeDeletionResolutionRecord`. The backfill does not replace existing
Recipe, Revision, child-payload, disposition, or Cooking Session records.

For each valid legacy Recipe graph, backfill:

1. writes one deterministic `RecipeSaveRecord` per legacy Revision, using that
   Revision identity as the Save identity and an empty parent set because legacy
   data does not prove ancestry;
2. builds that Save's manifest and digest from the existing complete payload;
3. writes root Selection evidence using the selected Revision identity as the
   Selection identity for every distinct valid `currentRevisionID` found among
   physical Recipe rows, preserving competing pointers as concurrency rather
   than choosing by arrival order;
4. fills the owning Kitchen identity on legacy
   `RecipeDeletionResolutionRecord` rows while leaving unknown deletion and
   restoration dates absent; and
5. marks the backfill complete only after all records for that Kitchen commit.

Two devices backfilling the same valid legacy graph therefore produce exact
logical duplicates. A disagreement beneath an existing domain identity becomes
recovery. Legacy records with unknown deletion dates are not automatically
eligible for time-based pruning.

Existing Recipe and Revision identities, payload rows, and authored ordering do
not change. A Cooking Session's self-contained Execution Snapshot and its Recipe
and Revision provenance remain readable without V5 authority evidence. Alpha
reset freedom from ADR 0016 does not weaken these ownership or recovery rules.

## Falsification result

The throwaway logic prototype compared the three shapes above and exercised
eight guided scenarios: first birth and exact retry, concurrent edits, choosing
an existing Revision, delete/restore with a concurrent delete, prune followed
by late payload, scrambled delivery, legacy migration, and logical identity
collision. It also exposed every retained authority row and accepted arbitrary
delivery permutations.

All scenarios preserved their expected classification. In particular:

- retry did not create a second Recipe or Revision;
- concurrent branches survived and a later multi-parent Save reconciled them;
- selection changed currentness without copying payload;
- an unobserved concurrent Deletion remained unresolved;
- late payload behind a Prune entered recovery rather than ordinary display;
- permutation did not change the final projection;
- legacy payload and snapshot identities remained intact; and
- conflicting command reuse entered recovery.

A second, deliberately small physical probe extended the signed Development
harness with the exact candidate fields. On Xcode 26.6 (17F113), macOS 26.6.2,
and the macOS/iOS 26.5 SDKs, generated-schema inspection found the three new
entities and the two extended V2 entities with the declared attributes, zero
relationships, zero indexes, and zero uniqueness constraints. Binary attributes
were not marked for external storage.

One in-memory V5 transaction saved and read one row from every authority family
while retaining a representative V4 Recipe, Recipe Revision, and self-contained
Cooking Session snapshot. The resettable
`iCloud.net.ctwelve.dev.KitchenMemory` Development schema then initialized
successfully with the additive shape. Production was neither initialized nor
deployed. This smoke proves generated shape and basic persistence only; it does
not claim multi-device transport or beta-grade migration coverage.

The selected shape would have been falsified if any result depended on a
timestamp, device, arrival order, revision number, mutable pointer, or partially
delivered edge set. None did. #105 must still implement the frozen codecs,
models, application backfill, and production tests before V5 is shipped.

## Implementation seam

The authority model belongs behind `RecipeRepository`. Domain and UI clients
ask for Recipe projections and issue typed Save, Select, Delete, Restore, and
Prune commands; they do not assemble persistence records or interpret partial
CloudKit delivery. The repository adapter owns codecs, transactions, duplicate
coalescing, migration, and the five-way authority result.

That narrow interface keeps synchronization mechanics local while leaving the
immutable Recipe Revision and Cooking Session snapshot models independent of
SwiftData and CloudKit. Its five-way result keeps ordinary presentation simple
without collapsing deleted, pruned, incomplete, and contradictory evidence into
one ambiguous failure.
