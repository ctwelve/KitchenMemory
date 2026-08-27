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
An immutable Cooking Session whose cook has explicitly declared the performance complete; further work begins by duplicating it into a new session.
_Avoid_: Closed session, archived session
