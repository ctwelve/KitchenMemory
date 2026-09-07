# Opportunistic records maintenance

`RecordsMaintenanceRepository` applies the existing evidence policies through one
clock-driven boundary. `RecordsMaintenanceSchedule` keeps only local scheduling
hints: the last completed opportunity for each job and the next job to consider.
Losing those hints repeats idempotent work. Evidence, never the hints, decides
whether removal is safe.

The app coalesces launch, foreground, local-save, external-store and successful
managed-transfer opportunities. A round considers each due job once and yields
between jobs. Cancellation stops before the next transaction. Each repository
transaction either commits its removal and replacement evidence together or rolls
back; interruption after a commit but before saving the hint safely repeats it.

| Job | Suggested check interval | Eligibility and preserved evidence |
| --- | --- | --- |
| Deleted Recipes | Six hours | Every unresolved known deletion must be at least 30 days old; complete authority and all retained dependencies are rechecked. |
| Folder and Tag compaction | Six hours | At least 30 days of complete causal history; reconstructive checkpoints preserve receipts, aliases, assignment dots, observed removes and ordering. |
| Compact evidence | One day | Recipe tombstones may expire only after their promised five-year minimum and with no late Recovery evidence. Organization checkpoints can be removed only after their promise expires and a newer checkpoint covers every receipt. The last reconstructive checkpoint remains. |
| Orphan cleanup | One week | Raw organization copies at least 366 days old may be removed only when their exact receipts already survive in a validated checkpoint. Unknown ownership, missing roots and late Recipe Recovery payload remain retained. |

These are independent eligibility windows and suggested check intervals, not
execution deadlines. A Folder or Tag deletion never becomes a restorable item
in Deleted Items. Five years is a minimum for aliases and suppression evidence,
not a command to erase still-needed history.

## Bounded admission

Each job currently admits at most 4,096 physical records across the dependency
store and 512,000 bytes of encoded organization history. The existing aggregate
reconstruction algorithms require complete evidence, so an oversized store is
left intact and the job remains due. Neither slicing an incomplete prefix nor
ignoring dependencies is a safe substitute. This conservative admission limit
bounds automatic work; it does not promise progress for arbitrarily large stores.
A future maintenance implementation can add resumable aggregate indexing and
larger-store processing behind the same boundary without changing retention law.

## Session and deeper-clean boundary

Cooking Session roots, Facts, Closures, deletions and restorations are preserved.
Their self-contained snapshots do not pin source Recipes solely for provenance,
but referenced Recipe media remains a hard dependency of Recipe pruning.
Incomplete or unreadable dependency evidence also prevents pruning.

The user explicitly confirmed this boundary for #112. The later dependency-aware
Session-retention policy should enable a deeper clean through this same mechanism
once it defines the surviving compact evidence, dependency checks and recovery
behavior for late arrivals. Until then, age alone never authorizes Session expiry
or erasure of ambiguous orphan payload. See [Cooking Sessions](cooking-sessions.md).

## Platform opportunities

On iOS, the scene registers one app-refresh task before launch completes and
requests another opportunity when entering the background or handling a granted
refresh. A cold background launch prepares the same application graph without
requiring a foreground window. SwiftUI task cancellation reaches the maintenance
round. On macOS, an in-process background activity supplies additional
opportunities while the application exists; there is no helper.

Apple controls whether and when this work runs. The implementation uses
[SwiftUI app refresh](https://developer.apple.com/documentation/swiftui/backgroundtask/apprefresh(_:))
and [NSBackgroundActivityScheduler](https://developer.apple.com/documentation/foundation/nsbackgroundactivityscheduler).

## Honest local synchronization observations

The app stores a start date and the latest successful import/export end date in
owner- and store-configuration-scoped local preferences. It stores no device
roster and no copies of cloud errors. A CloudKit event updates this observation
only when it names the current persistent store, has ended successfully and is
an import or export. Account availability, setup events, local saves, ordinary
reads and unrelated stores cannot clear the warning. Apple exposes the
[event's store identifier and completion properties](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/event).

After seven days without that observation, Settings warns that future
synchronization may be less reliable and the risk of losing data may increase.
A relevant success clears the stale warning. It does not prove that another
device has received anything or that all data has synchronized. Local-only mode
does not present the cloud warning. Foreground and maintenance opportunities
reevaluate the age; there is no time-bounded background or warning-delivery promise.
