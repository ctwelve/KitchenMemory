# Tag authority and storage

Issue [#115](https://github.com/ctwelve/KitchenMemory/issues/115) implements the
Tag policy settled in [#113](https://github.com/ctwelve/KitchenMemory/issues/113).
Tags classify stable Recipes independently of Folder location, Recipe Revisions,
and Cooking Sessions. The [native organization interface](recipe-library-organization.md) supplies
management, collision Recovery, filtering, and atomic pending-draft assignment.

## Entry points

Read `TagRepository.library(in:)`, prepare a `TagIntent` against that observed
`TagLibrary`, and append the resulting immutable `TagCommand`. Preserve that
command for exact retry. `tagIDs(for:)`, `recipeIDs(for:)`, `orderedTags(locale:)`,
`canonicalTagID(for:)`, and `collisions` supply persistence-independent values.
An unavailable creation does not manufacture a Tag; later arrivals reconstruct
its identity. Positive integrity failures throw rather than showing an empty
library. Separate identities with colliding names remain available for explicit
Merge or Rename without blocking unrelated Recipes.

Names retain entered case and diacritics, compare case-insensitively after
canonical Unicode normalization, and trim surrounding whitespace. Leading hashes
are presentation syntax: `Tag.name` stores `samples`, while `Tag.displayName`
returns `#samples`. Names reject controls, line breaks, empty values, and more
than 256 extended grapheme clusters after removing the presentation prefix.
No metadata conversion, Tag hierarchy, reserved system names, or suggestions
are introduced.

## Assignment and convergence

Each assignment is an immutable dot identified by its command ID. Removal names
only the live assignment dots observed for that Recipe and canonical Tag,
including observed aliases after a Merge. A concurrent unseen assignment
survives. Merge unions the surviving dots under an existing identity and retains
the alias; it does not create replacement assignments or revive removed dots.
Deletion suppresses the disposed identity and its assignments, including
concurrent edits, without rewriting Recipe or Cooking Session payloads.

Single-value names and ordering preferences choose causal maxima before
concurrent timestamp and action-ID ties. Tags default to locale-aware
alphabetical order. Manual neighbor order is retained through mode changes;
new identities append to that sequence. Opposite concurrent merges resolve to
the same oldest existing identity using the shared organization alias policy.

## Shared evidence and retention

`OrganizationEvidence`, `OrganizationAliases`, `OrganizationManualOrder`, and
`OrganizationStore` own replay, alias resolution, neighbor sequencing, canonical
encoding, digest checks, fresh-context reads, atomic acceptance, and compaction
for both Folder and Tag policies. Domain commands, values, and errors remain
specific to their respective policy.

Tags use the existing V7 scalar record families with namespace `tags`; Folders
use `folders`. No physical schema advancement or new CloudKit record type is
needed. Account convergence and Kitchen reset already own both record families.
Fresh assignments require a same-Kitchen Recipe payload. Exact accepted retries
remain valid after Recipe pruning, whether their evidence is raw or checkpointed.

`compact(in:at:)` uses the shared 30-day complete-causal-frontier gate and retains
at least five years of anti-resurrection evidence. Dominated rename and ordering
mode payloads can be dropped. Assignment dots, observed-removal receipts,
creation, deletion, aliases, and neighbor evidence remain reconstructive in the
checkpoint. Old exact retries cannot restore removed membership. Automatic
scheduling and conservative retention share the
[records-maintenance boundary](records-maintenance.md).
