# Cooking Sessions

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
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

The 0.1.3 lifecycle shell implements this boundary directly. Start captures the
exact selected Recipe Revision, and the library exposes every ordinary Active
or Stopped Session as a distinct device-local discovery row. Entering, leaving,
sleeping, terminating, and relaunching only change or restore presentation
selection. Stop, Resume, and confirmed Finish are the only shell actions that
submit lifecycle intentions.

The presentation retains accepted intentions in an ordered device-local outbox
before they cross Logic. Independent progress and scale actions may accumulate
without replacing one another. Retries preserve order and reuse the same
Session, Fact, or Closure identity after an interruption or ambiguous failure;
each item normally clears only when Logic returns its locally durable accepted
projection. The typed terminal exception is a command that Logic definitively
rejects because its source Session is already Finished: only that now-impossible
identity clears. Any exact Entry draft remains separately local for explicit
continuation, confirmed copy, or discard. The outbox is not synchronized and
does not imply that another device has received the evidence.

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

The 0.1.4 interface reads only the retained Execution Snapshot and Session
projection. It preserves authored section and row order, marks the first open
instruction as what is up next, and leaves every completed or skipped step
available to reopen. Ingredient progress remains the intentionally modest
accounted/open distinction. Working-yield changes produce a complete
Session-owned scale replacement by recalculating from the immutable snapshot,
never from a previously scaled value or the current Recipe.

The same semantic content recomposes for available container space rather than
platform identity: Compact below 540 points, Regular from 540 points, and Wide
from 900 points. Accessibility Dynamic Type sizes retain Compact reading order
at every width. Buttons, menus, headings, state values, and stable
Session-owned identifiers provide native keyboard and assistive-technology
semantics without creating a parallel platform-specific interaction.

## Session Entries and Outcome

A Session Entry is exact user-authored text, optionally anchored to one
Session-owned ingredient or instruction identity. It does not carry a deviation
enum, reason, input-modality marker, inferred structure, or automatic Recipe
meaning.

Entries may be causally revised, retargeted, or withdrawn without deleting
earlier evidence. A local meaningful draft survives navigation, Stop, and
process relaunch. Finish and remote Finish must offer explicit handling for that
draft; no path silently loses or misassigns it.

The 0.1.5 interaction keeps that draft in application-owned device-local
storage, separate from the synchronized accepted-intention outbox. Submission
preserves the exact authored Unicode text and clears the draft only after Logic
confirms local durability. Finish offers add, copy, discard, and cancel choices.
If remote Finish arrives first, the person may continue into a new immutable
Session, copy the draft, discard it, or leave it unresolved; continuation maps
the target through the captured continuation baseline instead of silently
retargeting it.

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
