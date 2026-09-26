# Share durable semantic undo through UndoKit

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Accepted; implementation pending
- Date: 2026-09-25

KitchenMemory and Folio need durable semantic history alongside native Undo/Redo,
so implement **UndoKit** as a reusable framework with its own small, local-only
Core Data store and native undo integration. Host applications choose the store
location and history policy: KitchenMemory uses app-local storage, while Folio
can embed a separate history database in each document package. Native callbacks
alone cannot preserve history across process termination; two independent
consumers justify the framework boundary permitted by [ADR 0012](0012-consolidate-business-code-in-kitchenkit.md),
without splitting KitchenKit's domain responsibilities or adding a third-party
module.

## Agreed policy and ownership

UndoKit owns durable history records and their native presentation. Each host's
domain Kit owns semantic payload meaning, validation, compensation, accepted
outcomes and recovery evidence. A history database save or native callback does
not establish domain acceptance. Do not serialize closures, reverse immutable
domain rows through automatic object undo, or replay commands just to rebuild
native Undo/Redo availability.

KitchenMemory starts with saved-Recipe Folder moves and Tag add/remove, including
atomic batches. Its app history belongs to the initiating logical scene and
owner/store/Kitchen scope, retains at most 100 groups, uses localized action
names, and never navigates automatically. Focused native text retains its own
history and responder priority. Relevant intervening evidence conservatively
invalidates the affected app history; reversal must check eligibility inside
domain acceptance, not merely against a view snapshot.

Eligible app history survives backgrounding, system scene disconnection, process
termination, force-quit and ordinary relaunch for that same logical scene. Restore
it only after checking scope identity, command outcomes and current eligibility.
Explicit scene disposal, owner/store changes, reset and relevant interference
invalidate affected history durably. Native text stacks retain their existing
lifetime; durable structured draft/media history is a later scope.

A rejected or reported failed inverse invalidates actionable history, preserves
the exact pending compensation under existing retry rules, and must not expose
false Redo. Ordinary interruption instead requires reconciliation and restoration
of eligible history. Invalidated actions must not reappear after relaunch,
including when the invalidation write itself failed; unproved outcomes block
affected history until reconciled.

The [agreed operation matrix and decisions](../research/application-undo-policy.md#agreed-decisions)
retain the approved exclusions and later waves. In particular, later Undo Save
of an existing Recipe creates a new Selection and preserves its Revision; first
Save and reconciliation Save need separate policy. Start, Finish, Continuation,
organization deletion/merge, draft discard, Sample Pack requests, reset and
pruning stay outside the initial undo policy. [#204](https://github.com/ctwelve/KitchenMemory/issues/204)
still requires a separately selected and validated app-wide acceptance scope.

## Consequences and remaining proofs

- KitchenMemory's scene scope, retention limit and conservative invalidation are
  host policies. The shared interface must also accommodate Folio's Cocoa clients
  and its existing document-wide ordering, branching, checkpoints and deliberate
  history omission. This decision does not amend or implement Folio's contract.
- UndoKit does not synchronize its database through CloudKit. A document host may
  carry history with its package under its save/export policy. It owns coordination
  of content and history during save, copy, restore and omission.
- Separate domain and history stores require a proven preparation, acceptance
  and finalization recovery protocol with stable command identities. Preserve
  recoverable evidence across interruption and schema failures; do not silently
  replace unreadable history with an empty store. No cross-store atomicity is
  assumed. [Storage research](../research/durable-undo-storage.md) identifies the
  platform constraints and required package/journal proofs.
- Framework distribution, implementation language, public API, versioned model,
  payload compatibility, migration, branching algorithms and retention mechanics
  remain implementation design work. Define and prove those contracts before
  shipping Move/Tag undo; neither this ADR nor #191 changes a persisted format or
  adds a framework target. [Ticket drafts](../research/application-undo-policy.md#proposed-implementation-tickets)
  separate those proofs from delivery and release acceptance.
