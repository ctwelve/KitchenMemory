# Recipe revision reconciliation

Recipe authority exposes competing revisions without using revision numbers,
clocks, or device identity to choose a winner. A Recipe with competing Selection
heads appears as a comparison entry in the library instead of making unrelated
Recipes unreadable. A selected Recipe with another surviving branch offers the
same comparison from its reading toolbar.

The person chooses a starting Revision and can then take individual fields or
ingredient rows from any shown Revision. Field comparisons ignore revision-local
row identities but preserve authored ordering, unknown values, provenance, and
media references. Image payload availability is independent of an authored media
difference. No automatic proposal, publication, or selection occurs.

Comparison choices live in the existing device-local Recipe Editing Draft file.
An existing ordinary editing draft must be finished or discarded before a new
comparison starts. Reopening a comparison resumes its existing choices rather
than replacing them with a fresh snapshot. Ordinary editing remains available
after the starting Revision is chosen.

`RecipeReconciliation` records all compared parents and the observed Selection
frontier. Save Revision creates one immutable multi-parent Revision and explicit
Selection evidence through the existing atomic repository operation. The exact
Save command is frozen in the local draft before publication, so cleanup failure
or relaunch can retry it without creating another Revision. A later unobserved
selection remains competing; saving does not claim global synchronization.

Reconciliation preserves unedited authored values through the ordinary editor's
presentation conversions. It does not normalize unknown quantities, whitespace,
source capture, or ordering merely because a person compared revisions. Section,
ingredient, instruction, and Equipment row identities are regenerated for the
new immutable Revision as required by the existing physical schema; retained
media identities are unchanged.

The authority and schema rules remain in the [V5 persistence contract](recipe-authority-v5-schema.md).
No schema migration or synchronized draft storage is introduced.
