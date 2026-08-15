# ADR 0003: Separate the domain from persistence and synchronization

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


- Status: Accepted
- Date: 2026-08-10

## Context

Kitchen Memory needs a precise cooking model, local-first behavior, Apple-native
persistence, synchronization across one person's devices, and collaboration
among several iCloud participants. Persistence frameworks impose schema and
relationship constraints that are not cooking-domain rules, while group sharing
introduces lifecycle and permission behavior beyond ordinary local storage.

## Decision

Maintain one persistence-independent `KitchenMemoryDomain` Swift package.
Represent Kitchen Memory concepts and stable identities there without SwiftData
annotations, CloudKit record identifiers, or synchronization state.

Use repository interfaces and explicit mapping between domain values and the
first persistence implementation, SwiftData. Keep CloudKit integration behind
the same application boundary.

Treat `Kitchen` as the ownership and collaboration boundary while storing major
aggregates independently with a stable `kitchenID`.

## Consequences

- Domain rules can be tested without a database or iCloud account.
- SwiftData and CloudKit schemas may satisfy framework constraints without
  redefining cooking concepts.
- Shared-Kitchen synchronization can evolve independently of the editor and
  other application behavior.
- Import and export can use a stable domain format instead of a store dump.
- Mapping and repository code are deliberate application infrastructure.
- Cross-aggregate updates require explicit application use cases rather than
  mutation of one giant Kitchen object graph.
