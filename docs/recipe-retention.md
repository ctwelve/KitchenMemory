# Recipe payload retention and Recovery

`RecipeRepository.maintainDeletedRecipes(in:at:)` is the explicit, clock-driven
maintenance boundary. It rechecks eligibility and commits payload removal and
compact authority evidence in one isolated transaction. Repeating a completed
pass is harmless. Scheduling these opportunities belongs to issue #112; this
slice does not start background jobs or claim synchronization completion.

A complete deleted Recipe becomes eligible only after every unresolved deletion
with a known date is at least 30 days old. Unknown legacy dates, incomplete
aggregates, and contradictory evidence remain retained. Restoration before a
pass removes eligibility. A newer concurrent deletion starts its own recovery
window.

Pruning removes the Recipe root, all its revision payload families, and the
covered Save, Selection, Deletion, and Restoration rows. It records revision
heads, selection heads, and disposition identities in the V5 frontier codec.
The tombstone promises at least five calendar years of retention. Expiration
requires both the stored promise and that minimum horizon to have passed, and
no late evidence may remain. Multiple tombstones must all be eligible.

References from surviving revisions, shared section identities, and media keep
payloads retained. A Cooking Session's self-contained Execution Snapshot does
not pin its source Recipe or Revision solely for provenance. Its media references
remain hard dependencies. Unreadable dependency evidence blocks pruning rather
than guessing. Unowned orphan rows with no recoverable ownership or age are not
deleted speculatively; descendants owned by an eligible revision are removed
with it. General long-horizon orphan scheduling remains in #112.

Any retained Recipe root or authority/payload arriving behind a tombstone enters
Recovery, even before a full revision can be decoded. It cannot restore the old
identity. Recovery can offer individually readable, non-colliding revision
content; missing or ambiguous content stays unavailable. The person confirms an
explicit loss warning before creating a new device-local editing draft. Saving
that draft creates a new Recipe with no ancestry claim on the pruned aggregate;
section, ingredient, instruction, and Equipment identities are copied freshly.
The original evidence remains in Recovery and the tombstone remains retained.

No schema change is introduced. The [V5 authority contract](recipe-authority-v5-schema.md)
and [deletion contract](recipe-disposition.md) remain authoritative.
