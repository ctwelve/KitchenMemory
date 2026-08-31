# Cooking Session V3 persistence contract

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Decision-frozen; compact physical schema smoke passed
- Decided: 2026-08-27
- Scope: Additive SwiftData and private managed-CloudKit representation for
  Kitchen Memory 0.2 Cooking Sessions

This document freezes the meaning and shape of V3. It does not
implement the models, initialize a CloudKit schema, deploy Production changes,
or authorize physical pruning. The bounded Development smoke recorded in
[issue #48](https://github.com/ctwelve/KitchenMemory/issues/48) did not falsify
the representation.

It applies the domain/persistence boundary in [ADR 0003](adr/0003-domain-persistence-boundary.md),
the additive CloudKit policy in [ADR 0004](adr/0004-apple-persistence-and-portability.md),
the distinct module seam in [ADR 0010](adr/0010-distinct-cooking-session-module.md),
and the document-envelope choice in
[ADR 0011](adr/0011-use-document-envelopes-for-cooking-sessions.md). Apple
transport constraints and the container escape hatch are recorded in
[managed CloudKit reconciliation](research/managed-cloudkit-session-reconciliation.md)
and [CloudKit schema evolution](research/cloudkit-production-schema-evolution.md).

## Governing invariants

- A Cooking Session is one device-independent performance with one stable
  application-owned identity minted at explicit Start.
- A sufficient Execution Snapshot is one immutable, self-contained document
  envelope. Recipe references explain provenance but are never runtime
  dependencies.
- Accepted activity is represented by causal immutable Facts. Replica merge is
  set union by logical identity; projections are deterministic and disposable.
- Start is embodied by the immutable root record. Finish is embodied by an
  immutable Closure record. Neither is a generic Fact kind.
- Finished is absorbing and immutable. Later competing evidence remains
  recoverable and may enter a new Session Continuation, never the source.
- Session Deletion is reversible disposition evidence independent of lifecycle.
  V3 never physically deletes authoritative Session evidence.
- No placeholder value, clock, device identity, arrival order, CloudKit record
  identity, relationship, or cached projection becomes domain authority.

## Authoritative record family

V3 adds exactly five SwiftData model types. They have no SwiftData
relationships, uniqueness constraints, cascade rules, or authoritative
projection fields. All associations use scalar Kitchen Memory UUIDs.

### `CookingSessionRecord`

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `UUID` | Logical Cooking Session identity and Start retry identity. |
| `kitchenID` | `UUID` | Owning Kitchen identity. |
| `recipeID` | `UUID` | Immutable Recipe provenance. |
| `recipeRevisionID` | `UUID` | Exact source Recipe Revision provenance. |
| `startedAt` | `Date` | Descriptive Start time; never ordering authority. |
| `snapshotFormatVersion` | `Int` | Execution Snapshot codec contract. |
| `snapshotData` | `Data` | Complete Execution Snapshot or continuation baseline envelope. |
| `snapshotDigest` | `Data` | SHA-256 of the exact stored snapshot bytes for this format. |
| `sourceSessionID` | `UUID?` | Immediate source Session for a continuation. |
| `sourceClosureID` | `UUID?` | Exact source Closure for a continuation. |

The two source fields are either both absent or both present. Root creation is
the immutable Start evidence; V3 has no separate Start record or Start Fact.

### `SessionFactRecord`

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `UUID` | Logical Fact identity and accepted-intention retry identity. |
| `sessionID` | `UUID` | Owning Cooking Session identity. |
| `kitchenID` | `UUID` | Owning Kitchen identity and query routing. |
| `kind` | `String` | Permanent broad Fact kind. |
| `targetSnapshotElementID` | `UUID?` | Complete resulting ingredient or step target where applicable. |
| `authoredAt` | `Date` | Descriptive human chronology only. |
| `causalHeadsFormatVersion` | `Int` | Codec for observed Session evidence heads. |
| `causalHeadsData` | `Data` | Canonical maximal observed Session head IDs. |
| `payloadFormatVersion` | `Int` | Codec for the kind-specific payload. |
| `payloadData` | `Data` | Complete resulting intention payload. |
| `payloadDigest` | `Data` | SHA-256 of the exact stored payload bytes. |

### `SessionClosureRecord`

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `UUID` | Logical Closure identity and Finish retry identity. |
| `sessionID` | `UUID` | Closed Cooking Session identity. |
| `kitchenID` | `UUID` | Owning Kitchen identity and query routing. |
| `finishedAt` | `Date` | Descriptive Finish time; never conflict authority. |
| `causalHeadsFormatVersion` | `Int` | Codec for the exact observed frontier being closed. |
| `causalHeadsData` | `Data` | Canonical maximal root/Fact heads in the closed frontier. |
| `snapshotFormatVersion` | `Int` | Expected root snapshot format. |
| `snapshotDigest` | `Data` | Expected root snapshot digest. |
| `projectionFormatVersion` | `Int` | Canonical closed-projection digest contract. |
| `projectionDigest` | `Data` | SHA-256 of the canonical closed projection. |
| `outcomeFormatVersion` | `Int?` | Final Outcome value format when one exists. |
| `outcomeData` | `Data?` | Final optional Outcome value. |

Outcome format and data are either both absent or both present. The Closure is
the immutable Finish evidence. It is not a mutable status row and does not list
every transitive Fact.

### `SessionDeletionRecord`

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `UUID` | Logical deletion-marker and Delete retry identity. |
| `sessionID` | `UUID` | Affected Session, even when its root is absent or invalid. |
| `kitchenID` | `UUID` | Owning Kitchen identity and Deleted Items routing. |
| `deletedAt` | `Date` | Descriptive Delete time. |
| `sessionHeadsFormatVersion` | `Int` | Codec for Session evidence observed by Delete. |
| `sessionHeadsData` | `Data` | Observed Session heads, used to identify unseen activity. |
| `dispositionHeadsFormatVersion` | `Int` | Codec for observed deletion-disposition heads. |
| `dispositionHeadsData` | `Data` | Observed Delete/Restore frontier. |

### `SessionDeletionResolutionRecord`

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | `UUID` | Logical Restore-resolution identity. |
| `deletionID` | `UUID` | The one observed deletion marker being resolved. |
| `sessionID` | `UUID` | Affected Session identity. |
| `kitchenID` | `UUID` | Owning Kitchen identity and query routing. |
| `restoredAt` | `Date` | Descriptive Restore time. |
| `dispositionHeadsFormatVersion` | `Int` | Codec for observed deletion-disposition heads. |
| `dispositionHeadsData` | `Data` | Frontier that proves causal Restore versus concurrency. |

A Restore that observes several unresolved deletion markers writes one
resolution per marker in one local transaction. Each record remains meaningful
when managed CloudKit imports only part of that transaction.

## Physical attribute rules

- Required SwiftData attributes receive schema-compatible declaration defaults.
  Those defaults are persistence placeholders, never domain values.
- Optionality exists only where absence is semantic: the paired continuation
  source, optional Fact target, and paired final Outcome.
- Recognizable impossible UUID, version, date, string, and data sentinels are
  preferred where the framework accepts them. Repository validation rejects
  every incomplete or placeholder-bearing record.
- V3 deliberately does not use `@Attribute(.unique)`, relationships, ordered
  relationships, delete rules, mutable projection records, or persistent device
  identity.
- V3 deliberately does not request optional CloudKit field-level encryption.
  The private database's ordinary access protections fit cookbook data, while
  unencrypted managed fields keep future user-authorized raw recovery possible.
  This is an at-introduction decision: changing it later requires additive
  replacement fields, record types, or a new container generation.
- `snapshotData` remains an ordinary `Data` attribute without
  `@Attribute(.externalStorage)` in V3. The generated model reported inline
  storage, and a 2 MiB synthetic envelope saved, synchronized, and cold-read
  intact on both smoke devices. A future measured failure may introduce an
  additive format or record type; it does not reopen this frozen field.

## Envelope formats

- Snapshot, Fact payload, Outcome value, and closed projection use independent
  deterministic JSON formats.
- Exact authored Unicode content round-trips without normalization or inferred
  structure. JSON escaping is persistence representation, not authored truth.
- Canonical projection collections sort by stable domain identity. Numeric
  cooking values use the existing semantic quantity representations rather
  than lossy display strings.
- Causal-head format V1 is a sorted sequence of consecutive 16-byte UUID values.
  Empty is valid where no prior disposition exists; a nonmultiple-of-16 payload
  is malformed.
- Snapshot and payload digests cover their exact stored bytes. Projection
  digests cover the canonical projection bytes defined by their format version.
- V3 adds no application compression. A future codec version may change byte
  representation without redefining the CloudKit field.

## Execution Snapshot V1

The initial envelope contains:

- title, optional summary, and authored content language;
- optional author name and compact Recipe source attribution;
- base yield, initial working yield or exact scale, and structured working
  quantities;
- prep, cook, and total durations;
- equipment;
- complete ordered ingredient sections and ingredient values;
- complete ordered instruction sections and step values;
- immutable Session-owned identities plus optional source-child provenance for
  every targetable ingredient and instruction step; and
- optional lightweight media identity, role, and accessibility-description
  references, without media assets.

JSON arrays safely retain authored order inside the one immutable envelope.
Cuisine, category, keyword, raw import capture, current Recipe content, Session
activity, and media assets remain outside the snapshot. Sparse authored content
is valid; missing required envelope material is not.

### Continuation baseline

A Session Continuation creates one new root and no copied Facts. Its snapshot
contains an optional inherited baseline with:

- final working scale and structured quantities;
- final progress mapped to newly owned snapshot-element identities;
- current nonwithdrawn Entries with new Entry identities and optional source
  Entry provenance; and
- mappings from new target identities to source identities.

The source Outcome is cleared. The new root is the initial causal head.
`sourceSessionID` and `sourceClosureID` preserve immediate lineage but are never
runtime dependencies or shared ownership.

## Session evidence graph

The Session DAG contains the root, ordinary Facts, Closures, and the one narrow
Closure-resolution Fact. Deletion evidence forms a separate disposition graph.

- Each ordinary Fact names the maximal Session heads observed by the accepted
  intention.
- A Closure names the complete observed root/Fact frontier it seals.
- Ordinary Facts may not causally descend from a Closure. Offline evidence that
  did not observe Finish remains a concurrent branch.
- A Closure-resolution Fact may observe competing Closures and select among
  them without changing either Closure.
- Missing heads are ordinary partial synchronization. Present heads must belong
  to the same Session, and a complete graph must be acyclic.
- Root identity is also Session identity. A second nonidentical root bearing the
  same ID is a logical collision, not another version.

## Fact kinds and payloads

The initial permanent `kind` values are:

```text
stop
resume
progress
workingScale
sessionEntry
sessionOutcome
conflictResolution
```

Unknown kinds are retained and never interpreted through a fallback case.

### Lifecycle

`stop` and `resume` carry valid versioned empty payloads. Their meaning comes
from kind, causal context, identity, and descriptive time. They do not store a
reason, proposed status, device, or inactivity duration. Concurrent Stop and
Resume derives Active, preserving both Facts.

### Progress

A Progress Fact stores resulting state, never a toggle or delta:

- ingredient target: `accounted` or `open`;
- instruction target: `completed`, `skipped`, or `open`.

The target is required and must match the snapshot element kind. Concurrent
identical resulting states agree semantically. Differing heads remain explicit;
ordinary presentation uses the nonhiding open state until resolved. Progress
contains no pantry deduction, percentage, device, or elapsed duration.

### Working scale

A Working Scale Fact stores the complete resulting working yield or exact scale
and resulting structured quantities keyed by Session-owned ingredient identity.
It is never an order-dependent multiplier. Unknown and imprecise quantities
remain honest. Concurrent equivalent results agree; materially different heads
need attention.

### Session Entry

The first Entry Fact uses its Fact ID as the new stable Entry ID. Later
revisions and withdrawal receive new Fact IDs while retaining that Entry ID.

- Submit and revise store the operation, Entry ID, and complete resulting exact
  authored text.
- The optional common target is the complete resulting target; absence means
  session-level. A retargeting revision repeats the current text.
- Withdrawal stores the Entry ID and withdrawal operation without deleting
  earlier wording.
- Empty submitted or revised text is invalid.
- Causal heads establish observed supersession; there is no second generic
  supersession field.

### Session Outcome

Outcome is a versioned tagged value. V1 permits:

```text
set { type: coarse, value: great | okay | unsuccessful }
clear
```

Future versions may add value types without redefining `coarse`. The target is
always absent. Concurrent equal values agree; differing values or Set/Clear
require attention. Finish copies the final optional value into the Closure.

### Conflict resolution

V3 permits this kind only to select one Closure from a complete set of observed
competing Closure IDs. The selected ID must belong to that set. Progress, scale,
Entry, and Outcome conflicts resolve through a new corresponding typed Fact
that observes all competing heads. Malformed evidence and logical collisions
cannot be resolved by injecting projected state.

## Closure and late evidence

Finish may begin from Active or Stopped after all locally known conflicts and
meaningful local drafts have been addressed. The Closure seals the complete
locally observed frontier and atomically records the final optional Outcome.

The projection digest covers the immutable snapshot, inherited baseline,
accepted progress, working scale, current nonwithdrawn Entries, lifecycle, and
Outcome. It excludes deletion disposition. A valid Finished Session is
self-contained as its retained root-plus-Facts-plus-Closure aggregate, not as
one physical record.

One Closure plus evidence it did not observe remains Finished. The extra
evidence is retained for review, copy, or explicit Session Continuation and
never mutates the closed projection. Competing Closures place the Session into
Recovery until a person explicitly selects from every observed Closure; a
later unseen Closure requires attention again. Timestamps may explain a
recommendation but never select.

Finishing with no Session Entries or Outcome remains useful evidence. The
interface may say “No notes or changes recorded,” but V3 stores no
`followedRecipe`, `unchanged`, or quality conclusion.

## Deletion disposition

Deletion is independent of Active, Stopped, and Finished. Any lifecycle may be
deleted; ordinary Delete never Stops or Finishes. An end-of-cook Delete or Throw
Away action may write the Closure and deletion marker together locally without
exposing that bookkeeping in interface copy.

- Any complete unresolved deletion marker withholds the Session from ordinary
  presentation.
- A Delete causally following every observed Restore is an ordinary later
  deletion.
- An unresolved Delete concurrent with Restore remains in Deleted Items with
  Needs Attention.
- Once every maximal Delete is causally resolved, the preserved lifecycle is
  visible again.
- Missing deletion dependencies withhold ordinary presentation as Waiting for
  Session Data rather than risk transient resurrection.
- Delete may arrive before the root and remains queryable in Deleted Items.
- Delete never cascades to Recipes, source Sessions, continuations, or Facts.

V3 contains no Empty Deleted Items, expiry, physical Session pruning,
authoritative compaction, or enumeration of devices.

## Duplicate and reconstruction rules

Physical duplicates coalesce only when every authoritative field is identical.
A digest is not equality. Any disagreement under one logical identity,
including routing, time, kind, target, versions, causal bytes, payload bytes, or
digest, is a collision requiring Recovery. SwiftData object identity and
CloudKit metadata are ignored.

The repository:

1. fetches every physical row relevant to the requested logical Session;
2. groups by record family and logical identity;
3. coalesces completely identical duplicates;
4. retains unsupported and incomplete envelopes without defaulting them;
5. validates membership, paired fields, digests, causal references, cycles,
   snapshot sufficiency, deletion disposition, and Closure integrity; and
6. returns complete stored evidence, Unavailable evidence, or Recovery evidence
   to Logic without constructing a partial domain Session.

Missing roots or causal predecessors and well-formed unsupported formats or
kinds derive Unavailable. Recognized malformed encoding, digest mismatch,
collision, cycle, cross-Session reference, or inconsistent Closure derives
Recovery. Unknown late evidence outside a valid Closure remains retained and
does not mutate the Finished projection.

## Transactions and read paths

Each user intention uses the smallest complete local transaction:

- Start: one complete root;
- ordinary activity or lifecycle: one immutable Fact;
- Finish: one Closure;
- Finish-and-Delete: Closure plus deletion marker;
- ordinary Delete: one deletion marker;
- Restore: one resolution per observed unresolved marker;
- competing-Closure resolution: one narrow resolution Fact; and
- Continue: one complete new root.

Success means local durability only. Managed CloudKit may export and import any
remote prefix.

V3 adds no authoritative summary, mutable lifecycle, `isDeleted`, last-activity,
or search record. Required reads are root by identity; roots by Kitchen or
Recipe provenance; Facts and Closures by Session; bounded Finished ordering by
descriptive Finish time; and deletion evidence by Kitchen, Session, or marker.
Indexes are operational and mutable, never correctness authority. Initial custom
indexes require measured need; generated CloudKit indexes receive deployment
review.

## Migration and schema evolution

The local sequence is strictly:

```text
KitchenMemorySchemaV1 -> KitchenMemorySchemaV2 -> KitchenMemorySchemaV3
```

V3 contains every unchanged V2 type plus the five new Session types and one
lightweight V2-to-V3 migration stage. Historical V1 and V2 definitions and
model fields remain untouched. Tests open preserved V1 and V2 fixture stores
and prove Recipe data and V2 deletion evidence unchanged after sequential
migration.

Within the current production CloudKit container, record types and fields are
append-only. A deployed name, type, meaning, or encryption state is never
deleted, renamed, retyped, or repurposed. Indexes remain deliberately mutable.
Longer String or Data content is not a schema-width change; record and asset
limits remain physical constraints.

A future container replacement is an exceptional migration product, not an
ordinary schema version. It requires resumable idempotent application-owned
copying, stable domain identity, rebuilt relationships and shares, verified
cutover, and prolonged access to both containers. The old container is never
automatically destroyed.

## Freeze evidence

The compact signed Development experiment in
[issue #48](https://github.com/ctwelve/KitchenMemory/issues/48) passed:

1. The five exact model types generated with the expected fields and
   optionality, no relationships, no uniqueness constraints, no local indexes,
   and no external-storage flags.
2. Separate Mac and iPhone stores preserved each device's independently
   authored immutable Facts through convergence.
3. An incomplete scrambled prefix remained Unavailable; root, Fact, Closure,
   Delete, and Restore evidence eventually reconstructed as Restored.
4. Identical physical duplicates produced one logical fingerprint and
   coalesced; conflicting duplicates produced two fingerprints and Recovery.
5. A 2 MiB synthetic Execution Snapshot synchronized and cold-read intact on
   both devices as inline model data.

The probe used only synthetic nonprivate content and bounded identifiers in the
Development container. The radios were not manually forced offline; separate
stores and pre-convergence insertion supplied independence for this alpha gate.
Deterministic Logic tests still exhaust delivery permutations.

Slice 19's separate signed Development harness then exercised the broader E1,
E2b, E3, E4a, E4b, E5, and E7 transport matrix. Corrected independent store
URLs proved both reconnect orders for every order-sensitive scenario. Clean
receivers rebuilt ordinary, Unavailable, Deleted, Restored, and Recovery
classifications from retained V3 evidence; operation events remained bounded
diagnostics and never supplied the pass conclusion. The same harness initialized
the additive Development schema and inspected the generated five-entity model.

CloudKit Console review of server indexes, standard security roles, and
encryption remains a release-evidence task before any later Production
promotion. Production schema initialization and deployment are explicitly
outside this decision and ordinary application launch.
