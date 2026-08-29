# ADR 0003: Separate the domain from persistence and synchronization

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->


- Status: Accepted
- Date: 2026-08-10

Amended by [ADR 0012](0012-consolidate-business-code-in-kitchenkit.md): the
domain/persistence boundary remains, but it is now enforced by responsibility
folders and interfaces inside `KitchenKit` rather than separate framework
targets.

## Context

Kitchen Memory needs a precise cooking model, local-first behavior, Apple-native
persistence, synchronization across one person's devices, and collaboration
among several iCloud participants. Persistence frameworks impose schema and
relationship constraints that are not cooking-domain rules, while group sharing
introduces lifecycle and permission behavior beyond ordinary local storage.

## Decision

Maintain one persistence-independent `KitchenMemoryDomain` module as a native
framework target inside the Xcode project.
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
- Cross-aggregate updates require explicit Logic operations rather than
  mutation of one giant Kitchen object graph.
