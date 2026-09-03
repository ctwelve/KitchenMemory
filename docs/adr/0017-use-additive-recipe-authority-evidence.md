# ADR 0017: Use additive Recipe authority evidence

- Status: Accepted
- Date: 2026-09-03

Kitchen Memory will represent Recipe creation, Revision ancestry, current
selection, deletion, restoration, and pruning with immutable additive authority
evidence behind `RecipeRepository`. Existing Recipe payload rows remain the
authored content representation. The deployed mutable
`RecipeRecord.currentRevisionID` may remain a compatibility index but is not
synchronized authority.

Each Save carries its complete parent set plus a compact payload manifest and
digest. Each Selection carries the complete frontier of prior Selections it
observed. Deletion and observed restoration are independent disposition
evidence. Pruning leaves a compact authority frontier with a five-year
anti-resurrection horizon. The exact V5 physical contract is frozen in
[Recipe authority V5 persistence contract](../recipe-authority-v5-schema.md).

## Context

Managed CloudKit may duplicate domain identities, deliver a local transaction
piecemeal, and resolve mutable fields without understanding Kitchen Memory's
domain intent. A mutable current pointer or clock-based winner would silently
erase concurrent choices. Separate graph-edge rows would make a partially
delivered operation indistinguishable from a complete one.

Recipes also predate this authority contract. The design must remain additive,
preserve existing Recipe and Cooking Session snapshot identities, and avoid
inventing ancestry that legacy evidence cannot prove.

## Consequences

- A Recipe is born through one atomic local first-Save transaction; exact retry
  coalesces and conflicting command reuse requires recovery.
- Currentness is derived from immutable Selection evidence, never timestamps,
  revision numbers, devices, delivery order, or mutable pointers.
- Concurrent Revision branches and selections remain explicit until a person
  chooses an existing Revision or saves a multi-parent reconciliation.
- Incomplete synchronized payload is unavailable rather than corrupt; evidence
  that positively violates ownership, identity, graph, manifest, or digest
  invariants requires recovery.
- V5 adds three scalar-only record types, extends the two existing disposition
  types additively, and uses an idempotent application backfill. It does not
  repurpose published fields or alter legacy payload identities.
- The repository adapter absorbs codec, migration, transport, and projection
  complexity so Domain and UI clients receive one deep Recipe authority seam.
- The logic and physical probe code remains only on the throwaway branch
  recorded in issue #104 and is not shipped.
