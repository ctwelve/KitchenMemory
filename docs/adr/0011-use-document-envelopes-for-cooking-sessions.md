# ADR 0011: Use document envelopes and scalar identity for Cooking Sessions

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Accepted
- Date: 2026-08-27

## Context

A SwiftData object graph would make Cooking Session navigation and ownership
look natural, but managed CloudKit does not provide the relational guarantees
that such a graph visually implies. Relationships may arrive separately, have
no authoritative ordering, must accommodate missing peers, and refer to
persistence identities that are distinct from Kitchen Memory's stable domain
identities. Those constraints already matter across one person's devices and
would become more consequential in a future shared Kitchen.

## Decision

Persist each Cooking Session as immutable, versioned document envelopes joined
by application-owned UUIDs. The Session root owns one self-contained Execution
Snapshot. Independently arriving Session Facts, Closure evidence, and deletion
evidence refer to the aggregate through scalar identities and causal identity
sets rather than SwiftData relationships. The persistence adapter reconstructs
and validates the aggregate before exposing a domain value.

SwiftData and CloudKit relationships may later appear in disposable local
projections when measured read performance justifies them. Such projections
remain rebuildable conveniences and never become ownership, ordering,
completeness, lifecycle, or deletion authority.

## Considered options

- **Authoritative SwiftData object graph:** offers convenient traversal,
  inverses, and familiar cascade semantics, but would make partial relationship
  arrival and framework-owned object identity part of the domain contract.
- **Normalized immutable snapshot graph:** preserves stable scalar identity but
  expands one Start or Continue operation into many independently arriving
  records. It was the measured fallback, but the complete envelope passed the
  V3 physical smoke.
- **Immutable document envelope:** keeps creation sufficient in one local row,
  preserves authored order inside the envelope, and leaves independently
  authored activity as insert-preserving Facts.

## Consequences

- Duplicate physical rows and partial imports are expected and validated by
  logical identity rather than hidden by relationship traversal.
- Ordering inside an immutable envelope is ordinary document content; ordering
  between independently authored Facts is causal where known and approximate
  otherwise.
- Domain and Logic remain portable to another persistence technology.
- Repository mapping is intentionally deeper: it must group, validate,
  reconstruct, and classify stored evidence before creating a Cooking Session.
- No relationship delete rule can cascade through Session history. Deletion and
  future pruning remain explicit domain operations.
