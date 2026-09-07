# Opportunistic records maintenance

`RecordsMaintenanceRepository` applies the existing evidence policies through one
clock-driven boundary. `RecordsMaintenanceSchedule` keeps only local scheduling
hints: the last completed opportunity for each job, its candidate continuation,
and the next job to consider.
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

## Bounded transactions and resumable progress

Each Recipe job considers at most 16 logical identities per opportunity, with
one isolated transaction per complete Recipe aggregate. A stable identity
continuation advances past ineligible or failing candidates as well as completed
ones. New arrivals behind a continuation are considered in the next sweep.
Losing the continuation repeats safe work. No unrelated store-size threshold
can disable maintenance.

Folder and Tag each form a complete `(Kitchen, namespace)` causal aggregate.
A compaction opportunity validates that aggregate, creates at most one
checkpoint and removes at most 16 covered raw rows. Later opportunities reuse
that checkpoint while draining covered rows. Compact-evidence and orphan sweeps
also page by stable logical identity, considering at most 16 candidates each.

The guarantee is a bounded transaction/candidate count, with cancellation
between transactions and a yield between jobs. Candidate enumeration and work
inside a transaction remain proportional to complete evidence and dependencies;
this is not a constant CPU, memory or wall-clock bound. Format-1 checkpoints
require complete ancestral receipts, so truncating a causal prefix to meet a
byte cap would be unsafe. Strict size-independent processing would require a
separately designed segmented evidence format, not a silent admission cliff.

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
