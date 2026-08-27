# Kitchen Memory

Kitchen Memory preserves the distinct human truths of maintained recipes and what actually happened during cooking without manufacturing precision or silently rewriting history.

## Cooking sessions

**Cooking Session**:
One device-independent performance of a Recipe Revision, recording what happens while cooking within its own durable context.
_Avoid_: Cooking mode, recipe edit

**Execution Snapshot**:
The immutable, self-contained cooking context captured from a Recipe Revision when a Cooking Session starts; the source revision remains provenance rather than a runtime dependency.
_Avoid_: Recipe copy, live recipe reference

**Active Session**:
A Cooking Session that may accept progress, notes, scale changes, and other cooking evidence, whether or not its interface is currently visible.
_Avoid_: Open session, foreground session

**Stopped Session**:
A deliberately dormant Cooking Session that may be resumed but accepts no cooking evidence until it becomes active again.
_Avoid_: Abandoned session, paused session

**Finished Session**:
An immutable Cooking Session whose cook has explicitly declared the performance complete; only a Finished Session may serve as the durable source for derived work, and further cooking begins through Session Continuation.
_Avoid_: Closed session, archived session

**Session Entry**:
One confirmed, session-owned piece of authored cooking reality, optionally anchored to one element of the Execution Snapshot.
_Avoid_: Deviation, annotation, change record

**Session Outcome**:
An optional coarse assessment of the overall cook, distinct from whether the Cooking Session is Finished.
_Avoid_: Recipe rating, completion state

**Session Deletion**:
A deliberate instruction to remove a Cooking Session from ordinary library presentation while retaining its evidence for synchronization, restoration, and later pruning; deletion is independent of session lifecycle.
_Avoid_: Finish, Stop, permanent erasure

**Session Continuation**:
A new Active Session created from the self-contained inherited baseline of a Finished Session; the source remains immutable and lineage remains available even when ordinary presentation appears flattened.
_Avoid_: Reopened session, repeated cook

**Unavailable Session**:
A known Cooking Session whose retained material is not yet sufficient to reconstruct its complete Execution Snapshot; it is withheld from ordinary presentation without being declared corrupt.
_Avoid_: Partial session, corrupt session

**Session Requiring Recovery**:
A known Cooking Session whose available evidence positively violates a reconstruction invariant; its evidence remains retained and retryable outside ordinary presentation.
_Avoid_: Deleted session, unavailable session

## Library retention

**Deleted Item**:
A Kitchen-owned object deliberately removed from ordinary library presentation while its evidence is retained for synchronization, restoration, and later pruning; its original domain kind and lifecycle remain intact.
_Avoid_: Permanently erased item, finished item

**Pruning**:
The dependency-aware physical removal of retained data that is no longer needed to reconstruct, explain, synchronize, or restore any surviving item; pruning remains distinct from user-visible deletion.
_Avoid_: Delete, Empty Trash, permanent erasure
