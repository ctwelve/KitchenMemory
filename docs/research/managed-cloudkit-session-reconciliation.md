# Managed CloudKit facts for Cooking Session reconciliation

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Research complete; experiments specified but not yet run
- Issue: [#38 — Establish managed CloudKit facts for session reconciliation](https://github.com/ctwelve/KitchenMemory/issues/38)
- Researched: 2026-08-26
- Scope: SwiftData's managed `NSPersistentCloudKitContainer` integration with a
  private CloudKit database on Kitchen Memory's supported Apple platforms

## Decision boundary

This note establishes transport and persistence constraints. It does **not**
select the Cooking Session convergence model, persistence records, activity
representation, terminal-action policy, or product conflict behavior.

The architectural boundaries remain unchanged:

- Domain and Logic do not expose SwiftData, Core Data, or CloudKit types.
- `CookingSession` remains a top-level aggregate behind the distinct seam in
  [ADR 0010](../adr/0010-distinct-cooking-session-module.md).
- Stable domain UUIDs are product identity; Core Data and CloudKit identifiers
  remain persistence details under [ADR 0003](../adr/0003-domain-persistence-boundary.md).
- Cooking Session storage is an additive V3 SwiftData and CloudKit evolution
  under [ADR 0004](../adr/0004-apple-persistence-and-portability.md).

Apple documents managed synchronization as a local replica whose imports and
exports run later, when the system permits. A local save is therefore proof of
durability in that local store, not proof that CloudKit or another device has
the change. A local fetch similarly returns the local replica without querying
CloudKit for newer server state. [TN3163](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer)

## Fact, unknown, and experiment matrix

| Concern | Verified Apple fact | Still unknown or unsafe to infer | Smallest resolving experiment or design consequence |
| --- | --- | --- | --- |
| Identity and uniqueness | SwiftData managed CloudKit cannot enforce `@Attribute(.unique)`. Core Data owns the CloudKit record identity and generates a UUID record name for each mirrored object. Apple says peers can inevitably create duplicate logical data and demonstrates deterministic application-level deduplication. [SwiftData synchronization](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) · [WWDC19](https://developer.apple.com/videos/play/wwdc2019/202/) · [Apple's duplicate-data sample guidance](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users) | Managed CloudKit does not know that two different rows carrying the same domain UUID are the same product object. Apple does not promise which duplicate arrives first or whether duplicate detection happens in one import. | **E1.** On two offline devices, insert distinct physical rows with the same synthetic logical UUID, then reconnect A-first and B-first in separate runs. Record physical row count, CloudKit record count, import history, and final graph on both devices. Treat domain UUID lookup and duplicate tolerance as mandatory regardless of the observed arrival order. |
| Ordered children | Ordered relationships are unsupported. Relationships can also synchronize nonatomically and in an indeterminate order. [TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer) · [CloudKit-compatible Core Data models](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit) | Array order, insertion order, relationship import order, and CloudKit record order cannot be used as authored ingredient, instruction, activity, or note order. The correct explicit ordering value and concurrent-position tie-break are domain decisions, not Apple facts. | No transport experiment can make an ordered relationship safe. Any candidate session schema must represent order as ordinary persisted values plus stable child identity. Include simultaneous insertion at the same logical position in **E2b** so the eventual ordering policy can be tested without relying on fetch order. |
| Concurrent scalar changes | `NSPersistentCloudKitContainer` automatically resolves competing flat values with last-writer-wins; one scalar value survives. Apple recommends decomposing independently meaningful contributions into related objects when losing one contribution is unacceptable. [WWDC19](https://developer.apple.com/videos/play/wwdc2019/202/) | Apple does not document a product-usable definition of “last writer” such as device wall clock, local save order, export start, or server receipt. It does not promise that reversing reconnect order always reverses the winner. | **E2a.** Start from one synchronized row, edit the same scalar differently while both devices are offline, then reconnect in both orders. Capture local save time, event time, server `modificationDate`, and final value. The outcome can validate current-platform behavior, but no session rule may depend on the observed winner unless Apple documents that rule. |
| Concurrent child insertions | Apple shows that separate related child objects allow multiple devices to contribute without colliding on one flat parent value; the children eventually combine, while applications supply deterministic traversal and merge behavior. [WWDC19](https://developer.apple.com/videos/play/wwdc2019/202/) | The current SwiftData versions' transient relationship states, notification grouping, and behavior when both peers also edit the parent are not documented. | **E2b.** From the same synchronized parent, insert distinct stable-ID children offline on both devices, with and without a concurrent parent scalar edit. Reconnect in both orders and inspect every persistent-history transaction and final membership. Require both inserts to survive before adopting an insert-preserving representation. |
| Remote notification timing | The system, not the app, decides when imports and exports run; work may be deferred or throttled. Private-database changes schedule imports after CloudKit notification. CloudKit may coalesce notifications, so a notification means “remote changes may exist,” not “this exact change arrived.” [TN3163](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer) · [TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer) · [CloudKit remote records](https://developer.apple.com/documentation/cloudkit/remote-records) | There is no delivery-time guarantee suitable for session correctness, UI deadlines, or tests. Notification behavior while foregrounded, backgrounded, suspended, terminated, under Low Power Mode, or after relaunch can differ. | **E3.** Export one synthetic change while the receiving app is successively foregrounded, backgrounded, terminated, and relaunched. Log CloudKit events, `NSPersistentStoreRemoteChange`, persistent-history visibility, and UI refresh separately. Measure latency for diagnostics only; assert eventual content after a generous operator-controlled wait, never a fixed notification deadline. |
| Import visibility | A managed import writes changes into the local store's persistent history and posts `NSPersistentStoreRemoteChange`. Applications can consume the history to identify inserted, updated, and deleted local objects and then refresh presentation. [Store-change guidance](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users) · [Persistent history](https://developer.apple.com/documentation/coredata/consuming-relevant-store-changes) | A remote-change notification does not identify a complete domain aggregate and does not mean all causally related CloudKit records have arrived. Multiple records or saves may appear in one or several imports. | **E3** must log the history delta behind each remote-change callback. Refresh code must tolerate a partial session graph and re-read repository state; the callback itself cannot authorize a lifecycle transition. |
| Offline save and export | A local save commits to the local store and persistent history. Managed CloudKit later exports local history when the system permits, and Apple says it exports every store change unless work is deferred or throttled. [TN3163](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer) · [TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer) | Apple does not document a cross-record export ordering contract matching local save order, nor a guarantee that another device observes root, children, progress, and terminal state atomically. | **E4a.** While offline, save a synthetic root, children, scalar update, child deletion, and terminal update as separate transactions. Reconnect and inspect CloudKit events plus every importing history transaction on device B. Repeat with one local transaction and with separate transactions. Session reconstruction must tolerate every observed prefix. |
| Reconnecting a formerly local-only store | Managed import and export are separately scheduled tasks. Their execution requires system approval, and relationships may process in indeterminate order. The documentation does not promise “import before export” or “export before import” when a durable store is reopened with private sync after a local-only launch. [TN3163](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer) · [SwiftData synchronization](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) | The initial event ordering, conflict winner, and transient graph when both the local store and server changed during disconnection are managed implementation behavior. Treat the existing “copies will merge” product language as the promise; neither copy is an authoritative backup. | **E4b.** Begin with identical synchronized stores, launch A local-only and diverge both A and B using independent inserts plus a same-row scalar conflict, quit cleanly, then reopen A with private sync. Record setup/import/export events and content after each event. Repeat with the opposite device reconnect order. This is the required probe for the existing sync opt-out/reconnection path. |
| Deletion transport | Private-database mirroring synchronizes creates, updates, and deletes. Imported deletes are visible as delete changes in local persistent history. A Core Data history “tombstone” contains only attributes explicitly preserved after deletion. [Core Data synchronization](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit) · [Persistent-history tombstones](https://developer.apple.com/documentation/coredata/nspersistenthistorychange/tombstone) | Apple's documentation does not define the product outcome for delete versus offline update, delete versus independently inserted child, repeated delete, or delete before another device first imports the object. It also does not say a local history tombstone is a durable distributed restoration marker. It is not safe to treat it as one. | **E5.** Exercise each conflict above in both reconnect orders, then inspect final rows, relationships, persistent history, and CloudKit records on both devices. Also reinstall one device after convergence to test reconstruction from server truth. Keep Kitchen Memory's explicit deletion-marker design conceptually separate from Core Data history tombstones. |
| Schema defaults, optionality, and delete rules | Unique constraints are unsupported. All relationships must be optional; inverses must be inferable or explicit because changes process in indeterminate order; `deny` is unsupported because synchronization is not immediate. Ordered relationships are unsupported. Production CloudKit evolution is additive: published record types and fields cannot be removed or repurposed. [SwiftData synchronization](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices) · [CloudKit-compatible Core Data models](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit) · [TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer) | Current Apple documentation is explicit about relationship optionality but does not state an equally clear SwiftData contract for whether every nonoptional attribute must have a schema default. Managed-store validation has historically required “optional or defaulted,” but Swift initializers and SwiftData schema defaults can be easy to confuse. | **E6.** Before freezing V3, construct a minimal schema matrix containing optional attributes, declaration-defaulted nonoptional attributes, initializer-only nonoptional attributes, optional relationships with explicit inverses, and each intended delete rule. Open a signed managed store, initialize the Development schema, and inspect generated fields. Record load/initialization failures verbatim. Regardless of the result, schema placeholder values must never become trusted domain data. |
| Observable sync completion | `eventChangedNotification` exposes operation-scoped setup, import, and export events. Each event has an identifier, store identifier, start date, optional end date, success flag, and error. Apple uses ended events as control points in CloudKit tests. `NSPersistentStoreRemoteChange` separately indicates that an import changed the local store. [Event API](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/event) · [WWDC22](https://developer.apple.com/videos/play/wwdc2022/10119/) · [TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer) | A successful event proves that one operation ended successfully. It does not prove global quiescence, that no new operation will start, that another device imported the data, or that every record a person expects is synchronized. The managed API exposes no per-record cross-device acknowledgement or “all devices current” state. | Settings may report setup/import/export activity and errors, but must not report “fully synced.” Acceptance must confirm content on the receiving device. **E7.** End an export successfully, immediately save another change, and show that a later event is possible; then keep B offline through A's successful export to demonstrate that A cannot observe B's receipt. |

## Required experiment harness

The experiments above are deliberately a single bounded investigation, not a
Cooking Session implementation.

1. Use only small synthetic, nonprivate records shaped like a root, ordered
   children, append-only activities, mutable progress, and a terminal value.
2. Use a signed Development build and a resettable Development CloudKit
   environment. Never add probe fields or record types to Production.
3. Start with clean installations on two devices signed into the same dedicated
   iCloud test account. The smallest cross-platform pair is iPhone and Mac;
   repeat any behavior adopted as a release assumption on iPhone and iPad.
4. Log bounded identifiers and state only: experiment/run ID, synthetic logical
   UUID, physical row count, event identifier/type/start/end/success/error,
   remote-change receipt, persistent-history transaction/change type, and the
   final reconstructed synthetic graph. Do not log recipe or user-authored data.
5. For concurrency tests, synchronize a baseline, disable network or select the
   existing local-only launch mode, make both changes, then reconnect one device
   at a time. Run both A-first and B-first orders.
6. Inspect CloudKit Console only after the app-observable state is recorded, so
   console inspection does not become an application dependency.
7. Capture OS, Xcode, and SDK versions with the result. Managed behavior that
   Apple has not documented remains version-specific evidence and must be
   rerun before final 0.2 release acceptance.

## Decision gates unlocked by this research

The next design ticket can compare candidate session convergence models with
the following nonnegotiable inputs:

- no persistence-enforced logical uniqueness;
- no relationship or fetch-order authority;
- one surviving value for a conflicting flat scalar, with no documented
  product-usable winner rule;
- independently inserted records as the available mechanism for preserving
  independent contributions, subject to signed verification;
- partial and delayed graph visibility as ordinary operation;
- no managed ordering guarantee when a disconnected local store rejoins the
  private database;
- no documented delete-versus-update product semantics;
- operation status, not global or per-record cross-device completion; and
- additive-only production schema evolution.

Those constraints favored representations reconstructable from stable identity
and independently arriving facts. The follow-on convergence decision selected
immutable causal Session Facts plus disposable deterministic projections; the
frozen result is recorded in
[Cooking Session V3](../cooking-session-v3-schema.md).

## Resolution-ready summary for issue #38

Apple documentation answers the structural questions but not the product
convergence questions. Managed CloudKit supplies delayed local-replica
synchronization, random persistence identity, unsupported uniqueness and
ordering constraints, last-writer-wins flat-value conflict handling,
indeterminate relationship processing, private-database deletion transport,
and operation-scoped observability. It does not supply logical identity,
aggregate atomicity, deterministic domain ordering, delete/update intent,
reconnection precedence, remote-device acknowledgement, or a global “synced”
state.

Issue #38 closed as research when this matrix was accepted. Its result informed,
but did not itself make, the separate convergence and schema decisions.

The V3 schema freeze used one alpha-sized signed smoke covering generated-schema
compatibility, independent immutable inserts, one partial-arrival sequence,
duplicate logical identity, and one deliberately large Execution Snapshot.
That probe passed and is recorded in
[issue #48](https://github.com/ctwelve/KitchenMemory/issues/48). It tested only
the facts capable of falsifying the chosen physical representation. E1–E7
remain the broader transport and release-acceptance matrix; notification
timing, local-only reconnection, physical deletion, and the lack of global
receipt acknowledgement do not all block the alpha schema decision.

## Primary Apple sources

- [Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)
- [TN3163: Understanding the synchronization of `NSPersistentCloudKitContainer`](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer)
- [TN3164: Debugging the synchronization of `NSPersistentCloudKitContainer`](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)
- [Using Core Data with CloudKit, WWDC19](https://developer.apple.com/videos/play/wwdc2019/202/)
- [Optimize your use of Core Data and CloudKit, WWDC22](https://developer.apple.com/videos/play/wwdc2022/10119/)
- [Syncing a Core Data store with CloudKit](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit)
- [Sharing Core Data objects between iCloud users](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users)
- [Remote records](https://developer.apple.com/documentation/cloudkit/remote-records)
- [`NSPersistentCloudKitContainer.Event`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/event)
- [Consuming relevant store changes](https://developer.apple.com/documentation/coredata/consuming-relevant-store-changes)
- [`NSPersistentHistoryChange.tombstone`](https://developer.apple.com/documentation/coredata/nspersistenthistorychange/tombstone)
