# Folder authority and storage

Issue [#114](https://github.com/ctwelve/KitchenMemory/issues/114) implements the
Folder policy settled in [#113](https://github.com/ctwelve/KitchenMemory/issues/113).
Folder organization belongs to stable Recipes, independently of Revisions and
Cooking Sessions. The native organization interface is tracked by
[#116](https://github.com/ctwelve/KitchenMemory/issues/116); this slice does not
add sidebar management, filtering, drag and drop, or pending-draft assignment.

## Entry points

`FolderRepository.library(in:)` reconstructs the available organization evidence.
Prepare one `FolderCommand` against that returned `FolderLibrary`, preserve the
command for exact retry, and pass it to `FolderRepository.append(_:)`. The command
captures observed causal heads and, for deletion, the observed subtree. Commands
are immutable Codable values; replay order is independent of physical arrival.

`FolderLibrary.children(of:locale:)`, `subtree(of:)`, `primaryFolder(for:)`, and
`collisions` supply presentation with ordinary Domain values. Missing parent
identities temporarily place children at the implicit Kitchen root. Positive
integrity failures throw `FolderError`; callers must surface recovery without
blocking unrelated Recipe access. Name collisions remain readable and expose
separate Folder identities for explicit Rename or Merge.

Single-value decisions select causal maxima before using timestamps and action
identifiers for concurrent ties. Parent-cycle resolution uses canonical causal
replay and retains a rejected move's prior parent choices. Merge keeps an existing
identity, defaults to the older creation, retains aliases, and leaves newly
colliding children for separate repair. Folder deletion never writes Recipe or
Cooking Session payloads.

## Compaction

`compact(in:at:)` atomically replaces eligible raw rows with reconstructive
checkpoint evidence. It requires a causally complete frontier with at least
30 days of raw history. Dominated Rename, assignment, and ordering-mode payloads
can be dropped; concurrent register maxima remain. Creation, parent, neighbor,
deletion, and Merge evidence stays when needed for reconstruction and fallback.
Digest receipts preserve action identity and causal ancestry after value payloads
are removed, including validation and suppression of late exact retries.

Checkpoints promise at least five years of anti-resurrection retention (1,827
days). This change does not automatically expire checkpoints or claim global
replica settlement. Background maintenance scheduling and further bounded
retention work belong to [#112](https://github.com/ctwelve/KitchenMemory/issues/112).

## Additive V7 physical contract

V7 retains every V6 entity unchanged and adds two scalar-only record types. They
have defaults and no relationships, uniqueness constraints, or cascade rules.
Kitchen ownership is outside immutable encoded payloads, allowing the existing
account-convergence transaction to rehome both record families. Reset owns both.

| Record | Fields |
| --- | --- |
| `OrganizationActionRecord` | `id`, `kitchenID`, `namespace`, `authoredAt`, `formatVersion`, `payloadData`, `payloadDigest` |
| `OrganizationCheckpointRecord` | `id`, `kitchenID`, `namespace`, `createdAt`, `antiResurrectionUntil`, `formatVersion`, `checkpointData`, `checkpointDigest` |

The Folder namespace is `folders`; the shared internal evidence, codec, and
record families are available to the distinct Tag policy in #115. Format version
1 uses canonical JSON and SHA-256 payload digests. The SwiftData adapter checks
envelope identity, format, canonical bytes, and digest before projection, and
uses fresh contexts to see partial personal-iCloud arrivals. Production CloudKit
schema deployment must include these two new record types and their 15 fields.
