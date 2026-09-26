# Durable undo storage

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Primary-source evidence for the approved storage direction; protocol and schema remain open
- Researched: 2026-09-25
- Scope: A reusable UndoKit with a local Core Data store at a host-selected location

## Approved direction and evidence boundary

The host supplies the database location: Kitchen Memory uses application storage;
Folio uses a separate database inside each document package. Undo survives
ordinary closing and reopening. This record examines the persistence and
lifecycle constraints of that direction; it does not define a schema, select an
acceptance protocol, or claim that recovery has been implemented.

Folio's existing contract additionally requires document-wide accepted-action
ordering, retained reversal/redo records, preserved abandoned branches, and
explicit history omission. It requires failed omission saves to preserve
existing history. Those requirements belong to the host's semantic/document
contract and are not supplied merely by placing a Core Data database in a
package.
[Folio contract, inspected revision](https://github.com/Folio-Suite/Folio/blob/94958fe6c98c364a9b81c2431057914caeb04d7e/docs/architecture/semantic-history-contract.md)

## Documented platform facts

| Area | Apple-documented behavior | Architecture implication |
| --- | --- | --- |
| Location and readiness | A persistent-store description has a configurable URL; custom descriptions must be set before loading stores. Loading reports completion and errors separately for each store. [Store URL](https://developer.apple.com/documentation/coredata/nspersistentstoredescription/url), [descriptions](https://developer.apple.com/documentation/coredata/nspersistentcontainer/persistentstoredescriptions), [loading](https://developer.apple.com/documentation/coredata/nspersistentcontainer/loadpersistentstores(completionhandler:)) | UndoKit can accept a host-owned location. Open/load failure must remain distinguishable from an empty history, and callers cannot use the stack before successful initialization. |
| Persistence boundary | A context save commits to its parent. Saving a child context does not persist to disk; changes must reach the context connected to the persistent-store coordinator. [Context save](https://developer.apple.com/documentation/coredata/nsmanagedobjectcontext/save()) | “History recorded” must identify a completed persistent-store save, not an in-memory insert, child-context save, or queued task. |
| Termination | UIKit generally does not call `applicationWillTerminate` when an app moves into the background, and termination cleanup has limited time. [Termination callback](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/applicationwillterminate(_:)) | Persist accepted history during operation processing. Closing/termination can be an additional flush opportunity, never the only durability boundary. |
| WAL and copies | Apple's archived QA1809 explains that committed transactions can remain in the SQLite `-wal` file after a context save. Copying only the main store can lose data. It recommends Core Data store operations and also describes packaging the main store with its WAL as one item. [QA1809](https://developer.apple.com/library/archive/qa/qa1809/_index.html) | A saved context does not imply that the `.sqlite` file alone is a complete snapshot. Package save, copy, backup, and export must account for the store's complete state. |
| Store replacement and relocation | The coordinator exposes store-aware replacement and migration. Migration changes location/type and removes the original store from the coordinator. [Replacement](https://developer.apple.com/documentation/coredata/nspersistentstorecoordinator/replacepersistentstore(at:destinationoptions:withpersistentstorefrom:sourceoptions:type:)), [migration](https://developer.apple.com/documentation/coredata/nspersistentstorecoordinator/migratepersistentstore(_:to:options:type:)) | Choose a store-aware copy/relocation lifecycle; do not treat migration as a harmless file-copy helper while retaining the original attachment. Rebind or reopen against the resulting location deliberately. |
| Coordinated files | `NSFileCoordinator` coordinates reads/writes and notifies registered presenters across objects/processes before operations proceed. [File coordination](https://developer.apple.com/documentation/foundation/nsfilecoordinator) | Use the host's document/package coordination boundary. File coordination alone does not establish a shared semantic commit between the domain store, UndoKit store, and other package resources. |
| Save failures | Core Data exposes incomplete-save errors identifying stores or objects that failed. [Incomplete save](https://developer.apple.com/documentation/coredata/nspersistentstoreincompletesaveerror) | Propagate concrete failures. Do not equate a single framework call, shared directory, or common coordinator with a documented transaction across independent persistence systems. |
| Persistent history | Core Data persistent history records store transactions and object insert/update/delete changes; tokens track consumed history. [Persistent history](https://developer.apple.com/documentation/coredata/persistent-history), [consuming changes](https://developer.apple.com/documentation/coredata/consuming-relevant-store-changes) | This can support change observation/reconciliation. It is not an application-level inverse-command format, a durable native UndoManager stack, or Folio's branching semantic history. |
| Migration | Lightweight migration requires discoverable source/destination models and inferable changes; staged migrations require properly versioned models and defined stages. Store opening can fail. [Automatic migration](https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically), [staged migration](https://developer.apple.com/documentation/coredata/staged-migrations), [loading](https://developer.apple.com/documentation/coredata/nspersistentcontainer/loadpersistentstores(completionhandler:)) | UndoKit owns its model-version compatibility and recovery policy. A successful Core Data schema migration does not by itself make old host-defined inverse payloads executable. |

The installed Core Data SDK's `NSPersistentStoreCoordinator.h` additionally
documents that store replacement honors SQLite locks, journal files, and
journaling modes. This corroborates using the coordinator's store-aware API;
it does not prove an application's surrounding document-save procedure correct.
QA1809 is historical guidance, so its old method spelling should not be copied
over the current typed APIs linked above.

## Recovery implications to settle in the protocol

**Two durable stores create an interruption boundary.** If the host's domain
save succeeds and the UndoKit save fails or never runs, the domain action exists
without finalized history. Reversing the write order can instead leave a history
record for an action never accepted. Neither the reviewed save APIs nor file
coordination document a common commit spanning independent coordinators and
arbitrary package resources. This is an architectural inference from their
scope, not a claim about undocumented Core Data internals.
[Context save](https://developer.apple.com/documentation/coredata/nsmanagedobjectcontext/save()),
[file coordination](https://developer.apple.com/documentation/foundation/nsfilecoordinator)

The protocol consequently needs a recoverable relationship between a stable
operation identity, the host's authoritative outcome, and the history record.
Preparation/finalization and querying an already accepted host outcome are
possible ingredients, not selected APIs here. Retrying recovery must not create
a second domain change. An unknown outcome must remain unknown until reconciled;
blindly replaying a command or declaring it absent would manufacture certainty.
The host must retain enough evidence for whatever reconciliation it promises.
Folio already requires stable action identities and idempotent internal retry.
[Folio semantic-operation contract](https://github.com/Folio-Suite/Folio/blob/94958fe6c98c364a9b81c2431057914caeb04d7e/docs/architecture/semantic-history-contract.md)

**Package integrity spans more than WAL.** Copying the entire directory avoids
the specific omitted-WAL mistake only when the copy is coherent with active
writers. The host also needs a matching generation of its domain content and
undo history. Pause/coordinate writers or create a validated staged snapshot
using store-aware operations; then verify the package pair on reopen. This is a
recommended proof obligation, not a selected implementation. A local-only
UndoKit store has no framework-owned cloud replication; a host's package copy,
backup, or export may still carry the database. The host owns that inclusion and
omission policy.
[WAL guidance](https://developer.apple.com/library/archive/qa/qa1809/_index.html),
[coordination contract](https://developer.apple.com/documentation/foundation/nsfilecoordinator)

**Unavailable history is not disposable history.** Preserve source files when
opening, migration, decoding, or finalization fails. Report a recoverable state
instead of silently deleting the store and beginning again. Exact recovery UI,
repair/export behavior, and whether domain editing may continue while history
is unavailable remain protocol/product decisions. Core Data's migration and
loading APIs provide error paths; they do not decide this policy.
[Migration](https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically),
[load errors](https://developer.apple.com/documentation/coredata/nspersistentcontainer/loadpersistentstores(completionhandler:))

## Required implementation proofs

1. **Interruption at each acceptance boundary:** terminate the process before
   preparation persists, after preparation, after domain acceptance, and after
   history finalization. Reopen and establish the correct outcome without
   duplicated domain effects or undo entries for rejected operations. Include
   disk-full/write failure at both stores.
2. **Rebuilt native history:** reopen a persisted history and reconstruct valid
   Undo/Redo availability without reapplying accepted domain actions. Exercise
   undo, redo, new edits after undo, and host-version/payload incompatibility.
3. **Coherent package operations:** save/copy/move a Folio package with outstanding
   WAL data and active editing contexts; reopen the resulting package and verify
   matching domain and history generations. Inject failure during staging and
   replacement; preserve the original usable package.
4. **Migration failure:** open every supported prior store/payload version,
   reject unsupported versions, and interrupt/fail migration. Confirm preserved
   source evidence, an actionable error, and a deliberate recovery route.
5. **Host-specific history policy:** verify ordinary save/reopen, restoration,
   branching, and successful/failed history omission against Folio's existing
   contract. Verify Kitchen Memory's account/store/Kitchen boundaries separately;
   shared infrastructure must not merge histories merely because hosts use the
   same framework.

No implementation, crash test, package-copy test, or migration fixture was run
for this research. Storage approval does not yet establish these guarantees.
