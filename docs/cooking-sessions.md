# Cooking Sessions

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Accepted 0.2 product contract
- Decided: 2026-08-27

A Recipe Revision describes maintained intent. A Cooking Session records one
device-independent performance of that revision without silently editing it.
The performance may move among one person's devices, but simultaneous live
cooking, device ownership, and multi-person collaboration are not 0.2 promises.

The precise evidence and storage contracts live in
[Cooking Session V3](cooking-session-v3-schema.md). The ordered implementation
route lives in the [0.2 roadmap](roadmap-0.2.md).

## Start and historical context

Viewing a Recipe never creates a Session. Explicit Start mints one stable
Session identity and succeeds only after one sufficient, immutable Execution
Snapshot is locally durable.

The snapshot is self-contained cooking context: authored Recipe content,
working yield and structured quantities, targetable Session-owned ingredient
and instruction identities, lightweight provenance, and optional media
references. Recipe and Recipe Revision identities explain where it came from;
the source objects are not runtime dependencies.

A sparse or imperfect Recipe may still produce a sufficient snapshot. Missing
required envelope material does not produce a partial user-visible Session.

## Lifecycle

A Session has three initial lifecycle states:

- **Active** accepts progress, working-scale changes, Session Entries, and
  Outcome changes.
- **Stopped** is deliberately dormant and resumable. It accepts no cooking
  activity until explicit Resume.
- **Finished** is an immutable closure created only after careful user
  confirmation.

Only durable user actions change lifecycle. Sleep, process termination,
navigation, network loss, inactivity, or another device appearing never Stops,
Resumes, or Finishes a Session.

Finish may occur from Active or Stopped. Finished never reopens or accepts
further evidence. Further cooking begins through Session Continuation: a new
Active Session with its own identities, a self-contained inherited baseline,
and explicit lineage to the Finished source.

Several Sessions may be Active at once. Presentation may recommend one current
Session locally, but devices, clocks, and view state are never lifecycle
authority.

## Cooking interaction

During an Active Session, the cook may:

- account for or reopen an ingredient row;
- complete, skip, or reopen an instruction step;
- replace the working scale and resulting structured quantities;
- move backward and forward without losing progress;
- submit exact authored Session Entries for the whole Session or one stable
  snapshot element; and
- optionally set, change, or clear a coarse Session Outcome.

Progress records resulting state rather than toggles or deltas. An ingredient
check means “accounted for during this cook,” not precise pantry consumption.
Conflicting progress uses a nonhiding ordinary presentation until the person
resolves it.

The representative interface recomposes for available container space rather
than platform identity. It favors what to do next, rapid independent intentions,
large readable content, native accessibility semantics, and recoverable local
drafts without turning the cooking surface into Recipe editing.

## Session Entries and Outcome

A Session Entry is exact user-authored text, optionally anchored to one
Session-owned ingredient or instruction identity. It does not carry a deviation
enum, reason, input-modality marker, inferred structure, or automatic Recipe
meaning.

Entries may be causally revised, retargeted, or withdrawn without deleting
earlier evidence. A local meaningful draft survives navigation, Stop, and
process relaunch. Finish and remote Finish must offer explicit handling for that
draft; no path silently loses or misassigns it.

Session Outcome is optional and distinct from lifecycle. Its initial coarse
values are great, okay, and unsuccessful. Finishing with no Entries or Outcome
remains useful history and does not manufacture a conclusion that the Recipe
was followed or was excellent.

## Synchronization and recovery

Accepted intentions are immutable causal Facts with stable retry identities.
Personal CloudKit synchronization transports them asynchronously; deterministic
set union and reconstruction define product meaning. Arrival order, timestamps,
device identity, CloudKit identity, and framework-event success never choose a
winner or prove global synchronization.

Missing roots or predecessors and well-formed unknown formats produce an
Unavailable Session, withheld from ordinary presentation while synchronization
may still complete. Positive invariant violations produce a Session Requiring
Recovery whose evidence remains retained and retryable.

Finished absorbs late or concurrent evidence without erasing it. Competing
Closures require explicit human selection from the observed candidates; timing
may support a recommendation but never a silent choice.

## History, deletion, and later use

Sessions remain independently discoverable when their source Recipe changes,
is deleted, or is temporarily absent. Finished history opens observationally
from its self-contained evidence and may later source a deliberate Recipe
workflow only because it is immutable.

Session Deletion is reversible disposition, separate from lifecycle. Any state
may be deleted, deletion never cascades, and causal Restore resolves only the
deletion evidence actually observed. Deleted Items and Recovery remain separate
surfaces. Physical pruning, Empty Deleted Items, expiry, and permanent erasure
require a later dependency-aware contract.

## Deferred work

The following do not belong to the 0.2 flow:

- promoting selected Entries into a Recipe Revision, variant, or new Recipe;
- repeated-pattern suggestions and AI-assisted interpretation;
- Session media capture and management;
- search, folders, tags, and durable Session organization;
- timers, Live Activities, and Siri commands;
- deliberate Session merging, advisory soft locks, Handoff, or local-network
  discovery;
- shared-Kitchen membership and multi-person live cooking; and
- pantry deductions inferred from progress.

These later features must preserve the central distinction: a Recipe is
maintained intent, while a Cooking Session is retained cooking reality.
