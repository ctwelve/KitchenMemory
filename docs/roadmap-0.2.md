# 0.2 roadmap — Cooking Sessions

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Decision-complete implementation route
- Planned: 2026-08-25
- Recut: 2026-08-27
- Target release: 0.2.0

Version 0.2 makes one performance of a recipe a first-class, durable product
concept without confusing cooking reality with the maintained recipe. The
release is complete when a person can start from a particular Recipe Revision
and working yield, make lightweight progress, record Session Entries, recover
after interruption, Stop or Finish explicitly, and later understand what
happened without reopening immutable history.

The complete loop is:

```text
Recipe Revision and working yield
                ↓
          Start cooking
                ↓
   Ingredient and step progress
                ↓
    Session Entries and Outcome
                ↓
     Resume after interruption
                ↓
           Stop or Finish
                ↓
 History, Deleted Items, and Recovery
```

## Architecture preparation

Three independently reviewable architecture revisions prepared the existing
modules for this route. They are source-history checkpoints rather than
marketing-version allocations:

1. protect Cooking Sessions behind a distinct Logic and persistence seam;
2. deepen the Recipe Library module so presentation does not forward shallow
   repository operations; and
3. deepen application runtime composition around coherent launch modes and
   long-lived adapters.

The accepted Session decisions now live in ADRs 0010 and 0011,
`CONTEXT.md`, the [V3 persistence contract](cooking-session-v3-schema.md), and
the [0.2 acceptance contract](acceptance-0.2.md). These contracts replace the
earlier hybrid-snapshot and mutable-progress hypotheses.

## Prelude — 0.1.2 alpha polish

Version 0.1.2 is the bounded polish pass immediately before Cooking Session
implementation. Its additive V2 persistence schema records Recipe deletion and
observed restoration so a long-disconnected device cannot silently revive a
deleted Recipe. It does not introduce a Cooking Session aggregate or speculative
0.2 infrastructure.

## Implementation sequence

The original four broad slices were planning hypotheses. Wayfinding replaced
them with ten issues cut at stable module interfaces. GitHub's native dependency
edges are canonical; the linear route keeps one implementation frontier obvious
and avoids simultaneous edits to the same young seams.

| Slice | Implementation outcome | Working-version checkpoint | Blocked by |
| --- | --- | --- | --- |
| [11](https://github.com/ctwelve/KitchenMemory/issues/49) | Deterministic Session evidence engine | no version allocation | — |
| [12](https://github.com/ctwelve/KitchenMemory/issues/50) | Immutable V3 repository and migration | no version allocation | Slice 11 |
| [13](https://github.com/ctwelve/KitchenMemory/issues/51) | Session commands and snapshot creation | no version allocation | Slice 12 |
| [14](https://github.com/ctwelve/KitchenMemory/issues/52) | Runtime integration and lifecycle shell | 0.1.3 | Slice 13 |
| [15](https://github.com/ctwelve/KitchenMemory/issues/53) | Adaptive cooking progress | 0.1.4 | Slice 14 |
| [16](https://github.com/ctwelve/KitchenMemory/issues/54) | Session Entries and Outcome | 0.1.5 | Slice 15 |
| [17](https://github.com/ctwelve/KitchenMemory/issues/55) | History and immutable continuation | begin 0.2.0 | Slice 16 |
| [18](https://github.com/ctwelve/KitchenMemory/issues/56) | Deleted Items and Recovery | 0.2.0 | Slice 17 |
| [19](https://github.com/ctwelve/KitchenMemory/issues/57) | Managed CloudKit convergence | 0.2.0 | Slice 18 |
| [20](https://github.com/ctwelve/KitchenMemory/issues/58) | Feature acceptance and release evidence | 0.2.0 | Slice 19 |

Advancing `MARKETING_VERSION` at a checkpoint does not publish it. The root
`RELEASE` marker, Production CloudKit promotion, release tag, and distribution
remain separate deliberate acts.

### Slice 11 — deterministic evidence engine

[Implement the deterministic Cooking Session evidence engine](https://github.com/ctwelve/KitchenMemory/issues/49)
adds persistence-independent Session values, canonical versioned evidence
codecs, and one deep projection interface. It proves reconciliation algebra,
causal lifecycle, progress, working scale, Entries, Outcome, immutable Closure,
deletion disposition, continuation, duplicate handling, Unavailable, and
Recovery without SwiftData, CloudKit, or UI.

The interface is the exhaustive test surface. Delivery order, clocks, device
identity, and cached projections never become authority.

### Slice 12 — immutable V3 repository and migration

[Add the immutable V3 Cooking Session repository and migration](https://github.com/ctwelve/KitchenMemory/issues/50)
adds exactly the five frozen scalar-linked SwiftData record families, a separate
`CookingSessionRepository` seam, the SwiftData adapter, and the complete
V1-to-V2-to-V3 migration. It preserves historical schema definitions and Recipe
meaning while grouping, validating, and classifying every retained physical row
before exposing a Session.

Development schema initialization is explicit. Production promotion, physical
pruning, and relationship-backed authority remain out of scope.

### Slice 13 — Session commands and snapshot creation

[Implement Cooking Session commands and snapshot creation](https://github.com/ctwelve/KitchenMemory/issues/51)
adds the deep Logic module. Explicit Start atomically captures a sufficient
Execution Snapshot from one Recipe Revision; typed intentions carry stable retry
identities through Stop, Resume, progress, scale, Entries, Outcome, Finish,
Delete, Restore, Closure selection, and Continue.

Only Active Sessions accept cooking evidence. Finished is immutable, and every
successful command means local durability rather than global synchronization.

### Slice 14 — 0.1.3 lifecycle shell

[Wire Cooking Session runtime and lifecycle shell](https://github.com/ctwelve/KitchenMemory/issues/52)
composes the new module and repository, adds one observable application
projection, a device-local current-Session pointer, and a durable local command
outbox. It ships the deliberately small Start, discover, Resume, Stop, and
carefully confirmed Finish flow on both native products.

Process lifecycle never changes Session lifecycle. Several Active Sessions may
coexist, and neither a device nor its clock owns one.

### Slice 15 — 0.1.4 adaptive cooking progress

[Build the adaptive Cooking Session progress experience](https://github.com/ctwelve/KitchenMemory/issues/53)
now presents the captured snapshot, resulting-state ingredient and instruction
progress, and complete working-scale changes. One semantic interaction
recomposes as Compact, Regular, or Wide from available container space rather
than platform identity, with Compact reading order retained for accessibility
text sizes.

Rapid intentions remain responsive and retryable through the ordered durable
outbox, including migration from Slice 14's one-item representation. Progress
targets Session-owned row identities, working scale always recalculates from the
snapshot base, and neither interaction edits the Recipe or claims pantry
consumption.

### Slice 16 — 0.1.5 cooking reality

[Add text-first Session Entries and optional Outcome](https://github.com/ctwelve/KitchenMemory/issues/54)
replaces deviation categories with exact authored text, one optional
user-confirmed snapshot target, causal revision/retargeting/withdrawal, and one
optional coarse Outcome. A meaningful local draft survives navigation, Stop,
and relaunch.

Finish and remote Finish must surface explicit submit, copy, continuation,
discard, cancel, or other applicable choices. The app never manufactures
structure, meaning, or Recipe edits from input modality or absence of notes.

Implemented at the 0.1.5 checkpoint: the shared interaction now captures,
revises, retargets, and withdraws exact text; keeps drafts device-local until
accepted; records the optional coarse Outcome independently; and resolves local
drafts explicitly across Finish and remote Finish.

### Slice 17 — 0.2.0 history and continuation

[Add Cooking Session history and immutable continuation](https://github.com/ctwelve/KitchenMemory/issues/55)
makes Sessions independently discoverable, presents current and recent work,
opens Finished history observationally, and creates a new Active Session through
self-contained continuation rather than reopening its source.

The navigation leaves room for future search, folders, and tags without adding
their schema. A long-idle nudge is device-local presentation and never changes
authoritative state.

Implemented at the 0.2.0 checkpoint: Sessions now has an independent destination
and Recipe-context history; Active and Stopped work remains deliberately
switchable; Finished projections open observationally; continuation creates a
new self-contained Active root with inspectable immediate lineage; and the
three-day stale nudge retains only device-local visit and dismissal state.

### Slice 18 — Deleted Items and Recovery

[Add Deleted Items and Cooking Session Recovery](https://github.com/ctwelve/KitchenMemory/issues/56)
ships explicit reversible deletion, causal restoration, descendant warnings,
Waiting for Session Data, and a separate Recovery destination. Any lifecycle
may be deleted; Delete never implies Stop or Finish and never cascades through
Recipe or Session history.

Physical erasure, Empty Deleted Items, expiry, and pruning remain later work.
Destructive classification receives the acceptance contract's mandatory abuse
and fuzz evidence.

Implemented at the 0.2.0 checkpoint: Active, Stopped, and Finished Sessions can
be deleted with descendant-aware confirmation; Deleted Items preserves their
lifecycle and distinguishes Needs Attention from Waiting for Session Data;
Restore resolves only observed markers; and Recovery exposes complete competing
Closure choices without discarding evidence. The deterministic Gate B suite
replays duplicated and reordered delivery, partial arrival, retry, concurrent
Delete/Restore, missing roots, and logical-identity collision against retained
evidence and rebuild invariants.

### Slice 19 — managed CloudKit convergence

[Harden managed CloudKit Session convergence](https://github.com/ctwelve/KitchenMemory/issues/57)
wires imported evidence through the complete projections and exercises the
signed Development scenarios E1, E2b, E3, E4a, E4b, E5, and E7. Where ordinary
tests cannot drive transport, the smallest signed harness lives under `/Tools`
and remains outside product targets and archives.

Receiving-store domain evidence is proof. Account availability, notifications,
and successful framework events remain bounded diagnostics, and Production
schema promotion remains untouched.

### Slice 20 — 0.2 feature acceptance

[Close 0.2 feature acceptance and release evidence](https://github.com/ctwelve/KitchenMemory/issues/58)
runs the complete automated gates, signed migration and managed-CloudKit matrix,
physical iPhone/iPad/Mac walkthrough, two-pass human brief, stable localization,
proportional accessibility, privacy review, production builds, archive, and
signing. It records conclusions in `release-evidence-0.2.md` against the exact
intended commit.

Accepted at the 0.2.0 checkpoint: build 128 passed every iOS and macOS Xcode
Cloud action; the signed archives, physical products, representative migration,
managed-CloudKit transport, localization, proportional accessibility, privacy,
and explicit alpha reductions are recorded in the release-evidence ledger.
Production schema promotion, tagging, and distribution remain separately
authorized release operations.

The final walkthrough remains:

1. Start a scaled cook from a known immutable Recipe Revision.
2. Record ingredient and instruction progress.
3. Add a Session Entry and optionally an Outcome.
4. Terminate and relaunch the application.
5. Resume without losing or reassigning activity.
6. Exercise supported continuation across personal devices.
7. Stop, Resume, and carefully Finish.
8. Confirm the maintained Recipe is unchanged.
9. Open Finished history observationally.
10. Delete, restore, and verify Recovery remains honest under conflicting or
    incomplete evidence.

Feature completion follows the exact [0.2 acceptance contract](acceptance-0.2.md).
Data/state failures block; only noncatastrophic UI refinements may move to a
linked 0.2.x issue.

## 0.2 release engineering

Release engineering follows the accepted 0.2.0 feature state and is not another
product slice. The feature evidence records immutable-schema review and
promotion readiness, device and recovery results, privacy and localization,
production builds, archive, signing, and distribution decisions in
`release-evidence-0.2.md`.

Production schema promotion, a `RELEASE` change, an immutable `release/0.2.0`
tag, TestFlight, or App Store submission occur only in a separately authorized
publication task. Physical-device feature acceptance does not silently authorize
distribution.

## Explicitly outside 0.2

- Planned Cooks, meal planning, shopping lists, and pantry deductions.
- Timers, Live Activities, and Siri command integration.
- Session photographs, video, and other media capture.
- Promotion of Session Entries into Recipe Revisions or named variants.
- Repeated-pattern suggestions, inferred Recipe corrections, and AI extraction.
- Search implementation, folders, tags, and persistent Session organization.
- Household sharing, membership, permissions, and multi-person live cooking.
- Session merging, advisory soft locks, local-network discovery, and Handoff.
- Physical pruning, Empty Deleted Items, expiry, and permanent erasure.
- Recipe draft/finalization and derivation eligibility redesign.
- Migration of self-contained Finished items into a document store.
- A wholesale redesign of every 0.1 library, import, and editor screen.
- TestFlight or App Store publication without a separate distribution decision.

These boundaries preserve the distinction in
[product doctrine](product-doctrine.md) between published source, maintained
Recipe, Planned Cook, Cooking Session, and pantry observation. They also keep
0.2 focused on proving that durable cooking history is useful before later
planning, pantry, media, and collaboration work depends on it.
