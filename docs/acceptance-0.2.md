# Kitchen Memory 0.2 acceptance contract

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Accepted
- Decided: 2026-08-27
- Scope: Evidence required to complete each 0.2 implementation slice and the
  final 0.2.0 feature state

Kitchen Memory 0.2 protects a small but humanly important body of data. Its
acceptance burden is therefore proportional: prove durable rules rigorously,
attack paths that could destroy or silently misclassify data, and use concise
human walkthroughs to find logic holes or catastrophically poor interaction.
It does not seek certification, exhaustive visual proof, or a false guarantee
that Apple's asynchronous service has reached global completion.

This contract applies [ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md),
the frozen [Cooking Session V3 contract](cooking-session-v3-schema.md), and the
[managed CloudKit reconciliation evidence](research/managed-cloudkit-session-reconciliation.md).

## Evidence ladder

Every implementation slice earns evidence at two gates. Final acceptance then
combines the completed capabilities against the intended 0.2.0 commit.

### Gate A: implementation proof

A slice is not implementation-complete until it has:

- deterministic tests for every durable success, failure, boundary, retry,
  preservation, and invalid-state rule it introduces or changes;
- 100 percent Xcode line coverage for its executable Domain, Logic,
  persistence, and migration behavior in the canonical macOS coverage
  artifact;
- a required iOS application-test lane proving native composition, resources,
  build settings, and runtime integration independently of that shared metric;
- preserved migration fixtures and fresh-store tests whenever persistence
  changes;
- a small identifier-driven UI smoke only for behavior that must cross the
  application boundary; and
- clean builds, tests, strict lint, and documentation appropriate to the slice.

Coverage is evidence rather than a substitute for good tests. Generated code,
declarations without executable behavior, and genuinely unreachable framework
bridges may be excluded only through a narrow documented exception.

### Gate B: risk-shaped slice acceptance

Gate B is mandatory when a slice can delete, hide, overwrite, reassign,
migrate, finalize, deduplicate, or make authoritative data unreachable. It is
also mandatory when a failure could prevent Recovery from exposing intact
evidence. The slice issue records a bounded abuse plan tailored to that risk.

Fuzzing and property-based generation are reserved for data actions that could
destroy evidence or defeat Recovery. Useful targets include migration,
reconstruction, causal reduction, duplicate grouping, and command
idempotency. Generated cases vary permutations, duplication, omission,
malformed payloads, unsupported versions, and logical-identity collisions.
They do not attempt to fuzz SwiftUI or Apple's CloudKit scheduler.

Every generated destructive case uses these oracles:

- no authoritative evidence disappears;
- logical identity never silently changes ownership;
- invalid or conflicting evidence never enters an ordinary projection;
- Recovery retains enough evidence to explain or salvage the problem;
- retries remain idempotent; and
- rebuilding from the same retained evidence yields the same classification.

A controlled move into Recovery is a passing result.

### Final 0.2 acceptance

Final acceptance runs against the intended 0.2.0 release commit. It combines:

- all current Gate A results;
- the risk-shaped Gate B conclusions;
- the signed migration, physical-product, and multi-device exercises below;
- localization, accessibility, privacy, schema-review, archive, and signing
  evidence; and
- one human cooking-flow attestation.

A later code change reruns the affected Gate A and Gate B evidence. The final
physical walkthrough and archive run again against the new intended release
commit. Documentation-only corrections do not invalidate unrelated evidence.

## Deterministic behavior matrices

### Lifecycle and command durability

Domain, Logic, and repository tests exhaustively cover:

- crash or injected failure immediately before and after every durable command
  boundary;
- repeated Start, Stop, Resume, Finish, Delete, Restore, and accepted-intention
  delivery;
- repeated Active-to-Stopped cycling and Finish from either mutable state;
- Finished as immutable absorbing closure while competing evidence remains
  retained for Recovery;
- concurrent Stop and Resume deriving Active;
- several simultaneous Active Sessions without ownership crossover;
- relaunch through a device-local presentation pointer without changing
  authoritative state;
- incomplete synchronized snapshots remaining Unavailable and absent from
  ordinary presentation; and
- duplication through Session Continuation as the only way to cook further
  from Finished history.

Failure injection carries the exhaustive crash burden. Physical testing uses a
representative interruption, repeated tap, concurrent-Session, remote-Finish,
and continuation flow rather than manually killing the app at every boundary.

### Reconciliation and reconstruction

Deterministic tests prove that Fact-set union is associative, commutative, and
idempotent. Every supported projection is invariant under duplicated,
out-of-order, and reversed delivery. Tests also prove:

- independent contributions survive;
- identical logical duplicates coalesce while conflicting payloads require
  Recovery;
- concurrent Complete and Reopen intent remains explicit;
- Stop and Resume derive Active;
- Finish absorbs without erasing competing activity;
- incompatible working-scale changes require attention;
- Delete and Restore remain independent of lifecycle and cannot silently
  resurrect or cascade; and
- every disposable projection rebuilds exactly from authoritative evidence.

### Session Entry and Outcome

Logic tests cover empty local drafts, exact authored-text preservation, one
optional stable target, causal edit and retarget, withdrawal, concurrent edit
versus edit, concurrent edit versus withdrawal, approximate ordering,
withdrawn-evidence exclusion, and Finish while a meaningful draft remains
pending. Inferred structure and input modality never become authority.

Outcome tests cover selection, change, clear, concurrent values,
Finish-with-Outcome, and competing unseen Outcome evidence. UI smoke proves
submission, one edit or withdrawal, the pending-draft Finish choice, and the
explicit continuation, copy, and discard paths when remote Finish makes a
local draft ineligible for its source.

### Local draft and accepted-intention recovery

A meaningful local draft survives supported navigation, Stop, and process
relaunch. An accepted intention retains one stable identity and retries without
duplication. Remote Finish never silently discards a local draft. Deterministic
tests cover every branch; one physical interrupted-entry walkthrough is
sufficient.

Active and Stopped Sessions cannot authorize a durable derived object.
Finished derivation never mutates its source.

## Migration evidence

The repository preserves representative V1 and V2 fixture stores. Automated
tests open each fixture through the complete stepwise chain:

```text
KitchenMemorySchemaV1 -> KitchenMemorySchemaV2 -> KitchenMemorySchemaV3
```

Recipe ownership, revision history, authored content, source evidence, and V2
deletion/restoration evidence remain intact. Tests also cover a fresh V3 store,
placeholder rejection, and unsupported or invalid stored material entering
Unavailable or Recovery rather than an ordinary projection.

Final acceptance performs one signed in-place physical-device upgrade using
synthetic but realistic V2 Sample Kit data. The small current audience does not
weaken the migration contract.

## Signed managed CloudKit evidence

CloudKit exercises validate transport; they never replace deterministic domain
tests. Account availability, an ended successful framework event, or silence
in the logs does not prove synchronization. The receiving store must contain
and reconstruct the expected domain evidence.

The final 0.2 transport gate runs these research scenarios:

| Scenario | Required conclusion |
| --- | --- |
| E1 logical duplicate identity | Both physical inserts remain detectable; identical content coalesces and collisions require Recovery. |
| E2b independent immutable inserts | Both devices' contributions survive and deterministic projection ignores arrival order. |
| E3 notification and import visibility | Foreground, background, termination, and relaunch eventually refresh from retained store evidence without trusting notification grouping or timing. |
| E4a multi-record offline export | Every observed root, Fact, Closure, Delete, and Restore prefix remains retained and safely classified. |
| E4b local-only reconnection | Diverged local and cloud inserts converge without calling either copy an authoritative backup. |
| E5 deletion transport | Delete, offline activity, Restore, and repeated disposition evidence do not lose facts, cascade, or silently resurrect ordinary presentation. |
| E7 event observability | Operation success is reported only as operation success and never as global or remote-device receipt. |

E1, E2b, E4a, E4b, and E5 use both reconnect orders where order could expose
lost evidence or resurrection. E3 and E7 need one representative order because
timing is diagnostic rather than authoritative. E2a remains research because
V3 does not trust a flat last-writer-wins value. The generated-schema portion
of E6 was satisfied by the compact probe in
[issue #48](https://github.com/ctwelve/KitchenMemory/issues/48); implemented V3
models still receive normal Gate A compatibility inspection.

One clean receiving-device convergence is required for each scenario. A
timeout is inconclusive and may be rerun. Repeatable content mismatch, lost
evidence, silent resurrection, or an unreconstructable graph blocks release;
latency alone does not define a product promise.

After Delete and Restore convergence, one clean third store or freshly
installed Development harness imports server truth and rebuilds the same
ordinary, Deleted Items, and Recovery projections. No tester's ordinary
Kitchen Memory data is reset for acceptance.

Slice 18's deterministic Gate B runs 128 seeded delivery shapes over a complete
Delete, observed Restore, and later Delete frontier. Each shape duplicates and
reorders physical records, retries projection, and must rebuild the identical
deleted result. Scripted hostile cases separately cover concurrent Delete and
Restore, an orphan Restore, a Delete arriving before its root, and two different
payloads sharing one deletion identity. The oracle requires complete evidence
retention and either deterministic deletion, Waiting for Session Data, Needs
Attention, or Recovery—never silent ordinary presentation. All fixtures use
synthetic UUIDs and content; no person's Kitchen or private diagnostic artifact
is read, reset, or retained.

Slice 19's separate signed Development harness completed the Mac content-
convergence portion of E1, E2b, E3, E4a, E4b, E5, and E7 with genuinely
independent stores. E1, E2b, E4a, E4b, and E5 passed in both reconnect orders.
E4a first classified a scrambled prefix as Unavailable before reconstructing
the restored Finished Session; E5 retained its independent Fact through Deleted
and restored checkpoints; and E7 demonstrated that a later export operation can
follow an earlier successful one. The tightened oracle compares the complete
expected evidence multiset and row content. Phase-aware E3 and signed iPhone
conclusions belong in the evidence ledger before the slice closes.

## Product interaction evidence

### Automated UI smoke

UI automation proves only that the durable application seams work. Stable
identifiers drive launch, navigation, Start or Resume, one progress intention,
one Session Entry, Stop, Finish confirmation, history, Deleted Items, and
Recovery access where those surfaces exist. Tests do not encode exact copy,
layout, scrolling, screenshot appearance, or the platform accessibility tree.

### Physical products

A concise operator brief asks for thorough use rather than prescribing every
tap:

- **iPhone and iPad:** Start, progress, Session Entry, Stop, relaunch, Resume,
  Finish, history, Delete, Restore, and continuation, using narrow and wide or
  split layouts.
- **Mac:** Session discovery, switching among simultaneous Sessions, history,
  Recovery, keyboard operation, and narrow-window recomposition.
- **Cross-device:** independent evidence, delayed arrival, unfinished-state
  resumption, immutable Finish, deletion/restoration, and receiving-device
  reconstruction.

The brief has two passes. First, the operator uses the app normally, explores
freely, attests that the major flow was attempted, and records impressions.
Second, the operator uses only Sample Kit data and follows a more precise
bad-behavior script containing rapid repeats, interrupted commands,
cross-device conflicts, deletion around incomplete synchronization, relaunch,
and attempted continuation from Finished history.

The purpose is to catch logic holes, broken durable seams, and catastrophically
poor interaction. Subtle UI polish is not a release blocker.

## Localization and accessibility

Stable 0.2 surfaces have complete `en-US`, `fr-CA`, and `es-MX` String Catalog
values. Machine-assisted translation is acceptable without linguist review.
Automated validation blocks missing or stale values and regression to exposed
keys. A brief manual launch pass blocks reversed action meaning, translating
stored authored content, or truncation that prevents use. Nuanced copy and
minor layout roughness may move to 0.2.x.

The stable walkthrough requires native names, roles, values, sensible focus,
usable Dynamic Type, VoiceOver access to core actions, and Mac keyboard
operation. Stable identifiers support the small UI smoke suite. Exhaustive
accessibility-tree automation, screenshot matrices, exact-focus scripts, and
broad hardening remain deferred because the shared UI is still provisional and
the two native products construct materially different accessibility trees.

## Sample evidence and privacy

Normal acceptance starts from the bundled Sample Kit. Additional public
samples remain plausible, useful recipes while deliberately representing
ordinary incompleteness, imperfect wording, Unicode, sections, unusual
quantities, long instructions, and scaling extremes. Malformed envelopes,
identity collisions, unsupported formats, and large synthetic payloads remain
test-only resources.

Committed evidence contains only scenario names, toolchain and device versions,
counts, bounded synthetic identifiers, digests, conclusions, and human
attestation. Raw logs and result bundles remain local or short-lived CI
artifacts. Evidence never commits user-authored recipe or Session content,
account identifiers, local paths, or recoverable database dumps.

## `/Tools` boundary and retention

The root `/Tools` directory is a catch-all toolbox for testing, QA, deployment,
and other engineering utilities that do not fit product tests or standard CI.
Each tool uses the smallest natural form: script, fixture set, Swift package,
or separate signed Xcode harness when physical-device execution requires one.
Nothing joins ordinary product targets merely for organizational convenience.

A small Development-only Session acceptance harness belongs there when the
transport scenario cannot fit ordinary XCTest. It may stage synthetic phases
and print bounded evidence, while reusable deterministic correctness remains in
the product's tested Logic. It is absent from ordinary product schemes,
archives, and Production binaries.

Superseded harness implementations, obsolete scripts, and raw diagnostic
artifacts may later be pruned deliberately. Accepted ADRs, schema contracts,
release-evidence documents, and the minimum fixtures needed to prove the
supported migration chain remain.

## Release blockers and evidence ledger

The following block 0.2:

- lost, corrupted, silently reassigned, or unreachable authoritative evidence;
- an incorrect lifecycle, deletion, restoration, derivation, Unavailable, or
  Recovery classification;
- failed supported migration;
- a crash in the bounded flow;
- missing stable localization or a core action inaccessible through the agreed
  native semantics;
- a privacy-boundary violation; or
- interaction so catastrophically poor that the core flow is not reasonably
  usable.

Noncatastrophic visual, copy, and interaction refinements may defer only to a
linked 0.2.x issue. Data and state failures cannot be waived.

When evidence exists, `docs/release-evidence-0.2.md` records the exact commit,
toolchain, OS and device versions, fixture and schema versions, automated gate
results, coverage, migration, physical attestations, CloudKit conclusions,
localization, accessibility, privacy, schema review, archive, signing, and
linked follow-up issues. It contains conclusions rather than raw logs.

Feature completion requires clean Production builds, a successfully signed
archive, and reviewed additive schema fields, defaults, indexes, security
roles, encryption choices, and deployment runbook. Production schema promotion
is not part of feature completion. A dedicated publication task performs any
promotion, changes `RELEASE`, creates an immutable `release/0.2.0` tag, or
distributes through TestFlight or the App Store only after a separate deliberate
decision.
