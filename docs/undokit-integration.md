# UndoKit consumer qualification

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

KitchenMemory [#236](https://github.com/ctwelve/KitchenMemory/issues/236) qualifies
the independently maintained **UndoKit 0.2.1** source package at revision
`7b77677bf8c079fbb03fc7719e9bae4244c5d92f`. It does not implement production Recipe
undo or close the [delivery gate](https://github.com/ctwelve/KitchenMemory/issues/204).
The [accepted policy](adr/0022-shared-durable-undo-framework.md) continues to own
operation eligibility, lifecycle, scope and domain authority.

## Supply route and ownership

The dynamic `UndoKit` package product links to KitchenKit. The application embeds
and signs it beside KitchenKit, rather than nesting it inside KitchenKit. The
Testing-only demonstrator and hosted test bundle also link that same product;
they do not add another source route or independently open its database.
`Package.resolved`, [the inventory](../DEPENDENCIES.md), SBOM and bundled notices
record the exact source and license. KitchenMemory's macOS/iOS 27 floors remain
unchanged. Source inspection and a build do not establish physical-device or
distribution signing acceptance.

The qualification host is compiled only with `TESTING`. Its native screen is
selected only by `--ui-testing --undo-qualification <UUID>`. It writes synthetic
collection values and receipts under `Application Support/UndoQualification/<UUID>`
in the disposable test app's container. Its UUID-only argument cannot select a
Kitchen database or arbitrary path. The screen's cleanup action closes its
history owner before removing that test directory. The UI tests retain the same
UUID across process termination and remove the successful fixture afterwards.
Failed runs can retain synthetic diagnostic files in this test-only directory.

UndoKit owns the local Core Data store, preparation, ordering, finalization,
retention, recovery and native binding mechanics. The host owns typed collection
meaning, guarded whole-group acceptance, inverse values and authoritative receipts.
The demonstration atomically replaces one JSON file containing domain values and
full-token receipts. That single-writer demonstration contract is not a new
Recipe repository, persisted organization format or production receipt design.
Real Folder and Tag compensation remains in #237–#239.

## Public integration contract

Declare one `HistoryOperation` per host family with versioned command/effect
codecs and a canonical sorted-key fingerprint. Retain its exact registration and
`HistorySessions` owner. Submit through the session's typed `HistoryCommands`;
do not recreate lookalike registrations per action. Persist complete
`HistoryToken` identity and member effects with domain acceptance. Outcome lookup
reloads authoritative receipts without repeating the action. A missing receipt
proves rejection only under this demonstrator's intact, exclusive single-writer
contract; production adapters must establish their own proof.

Native callbacks synchronously admit requests through the supplied UndoManager
facade. Domain work and finalization complete asynchronously; await
`waitForNativeOperations()` before observing completed state. Do not register
another reciprocal callback or claim the semantic inverse finishes inside the
native callback. AppKit/UIKit bindings preserve focused local text priority,
including refusal to fall through from an empty local stack to an older app action.

The host must map each logical scene plus owner/store/Kitchen boundary to stable
history scope and working identities. Independent test windows use independent
stores and identities. Disconnecting a presentation does not dispose its history.
Explicit disposal adopts a coherent baseline and retires the generation; old
command handles must remain unusable. The tests prove the framework primitives,
not production account-change or scene-restoration wiring.

`maxUndoGroups: 100` limits actionable depth, not retained detail or disk bytes.
The separate consolidation proof creates a coherent host checkpoint and requests
`targetDetailedGroups: 100`. Production must coordinate checkpoint/resource
retention and handle protected material, capacity refusal and cleanup failures;
setting the depth alone does not satisfy the retention policy.

## Executable proofs

The native application plan includes:

- `UndoKitQualificationTests`: typed ordered identities, native Undo/Redo and
  reopening without replay.
- `UndoKitRecoveryQualificationTests`: accepted reply loss, durable authoritative
  recovery, unresolved outcomes remaining blocked, and durable inverse rejection
  without false Redo or fallback to an older action.
- `UndoKitBoundaryQualificationTests`: all-or-nothing batch rejection, proved
  pre-write host failure, 100-group retention/depth, generation disposal and
  unreadable-store refusal without replacement.
- `UndoKitNativeRoutingTests`: local text priority, empty-local-stack isolation,
  independent windows and restored/disposed presentation history.
- `UndoKitRelaunchTests`: actual application termination/relaunch after finalized
  acceptance and after unacknowledged host acceptance, with duplicate-free recovery.

Run these through [Xcode's Test action](agents/xcode.md). The app/UI tests use
signed native hosts. Their synthetic control names are explicit localization
contract exceptions, compiled out of distributed builds; they are not the
shipping localized action-name proof.

## Remaining qualification requirements

- **Localized native names:** [UndoKit #73](https://github.com/Folio-Suite/UndoKit/issues/73)
  records that 0.2.1's `advanced.nativeActionNames(resolve:)` resolves retained
  presentation metadata but has no public bridge into the ordinary attachment's
  native UndoManager names. A supported upstream route or a separately verified
  host presentation adapter is required. Preserve local/live text names and routing.
- **Actual history write failure:** the typed finalization injector is guarded by
  UndoKit's `#if DEBUG` and is absent from the package compiled by this project's
  Testing configuration. Host pre-write rejection and accepted reply loss do not
  establish failure of UndoKit's preparation/finalization SQLite writes. Do not
  describe orderly reopen, reply loss or this Debug injector as abrupt power-loss
  evidence. Retain the remaining storage-boundary proof explicitly in #236.
- **Native acceptance:** simulator/hosted automation does not establish physical
  iPhone/iPad keyboard/menu/gesture or human assistive-technology acceptance.
  Record the actual environments, modalities and omissions in #236. Comprehensive
  beta accessibility remains [#168](https://github.com/ctwelve/KitchenMemory/issues/168).

Until these requirements are reconciled, #236 remains open and #237 remains
blocked. Qualification results do not authorize expanding the approved operation
matrix, changing production domain schemas or publishing KitchenMemory.
