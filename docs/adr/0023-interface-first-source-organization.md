# Organize source around discoverable interfaces and modules

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Accepted; source organization adopted
- Date: 2026-10-07

Organize source so a reader can start with the public contract and descend into
its implementation. Comprehensibility is the primary reason: an interface-first
source tree makes the architecture visible without requiring readers to discover
entry points throughout implementation files. This decision is harmonized with
[Folio ADR 0017](https://github.com/Folio-Suite/Folio/blob/main/docs/adr/0017-discoverable-swift-interfaces-and-resources.md).

## Source organization

Within each owning application, framework, or library, use `Interface/`,
`Modules/`, and `Resources/` as the standard source organization:

- `Interface/` collects public declarations: protocols, classes, structs, enums,
  initializers, methods, and properties, with their documentation. Group files by
  capability, using subfolders corresponding to implementation modules where
  useful. Make the starting points discoverable in the README or DocC overview.
- `Modules/` contains implementation grouped by cohesive responsibility, with
  explicit dependencies and a clear interface. A module here means source code
  organization, not necessarily a Swift compiler module, framework, or library.
  Its responsibility should be understandable as a potential later dynamic-library
  extraction; that discipline does not require a new target or speculative
  abstraction today.
- `Resources/` collects the owning product's bundled assets, catalogs, storyboards,
  models, and other resources, grouped by purpose. Preserve platform-required
  locations and formats. Resource ownership and lookup remain with the enclosing
  product unless a later decision explicitly changes them.

Application entry points remain easy to find at the source root. App-internal
entry points need not gain Swift `public` access merely to appear in `Interface/`;
access control still expresses the actual caller contract. Implementation-only
helpers remain internal or private. Organizing declarations does not itself
widen or narrow that contract.

## Natural Swift declarations

Prefer protocols and classes where they naturally express a contract or identity;
structs and enums remain natural, supported choices for values and alternatives.
This is not a mandate to replace value types or invent a protocol for every type.
Use actual Swift declarations, with documentation beside them. Extensions and
internal implementation types may separate substantial logic, but stored
properties, initializers, small method bodies, and other code that Swift requires
or reasonably keeps with its declaration may remain in `Interface/`. Do not
introduce forwarding types, duplicate declarations, or artificial indirection
solely to imitate headers or satisfy the directory layout.

## Adoption and existing decisions

This amends the source-folder prescription in [ADR 0012](0012-consolidate-business-code-in-kitchenkit.md)
and [implementation architecture](../implementation-architecture.md), while
retaining one KitchenKit framework and its responsibility separation. Domain,
Import, Logic, and Persistence still describe ownership; they organize both `KitchenKit/Interface/` and `KitchenKit/Modules/`. Application
feature ownership, presentation independence, immutable evidence, persistence
contracts, and the separate UndoKit decision remain unchanged.

Adopt the organization through behavior-preserving refactoring. Move source,
project references, resource lookup, documentation pointers, and structural
checks together in each scoped change. Keep current-layout documentation honest
until those changes land. Narrowing contracts or deepening behavior can follow
where the visible organization supplies evidence; neither is required to obtain
the comprehension benefit. The initial adoption reorganizes KitchenKit and the application while preserving
the existing test-target layout. Natural Swift colocation exceptions remain
visible in the interface folders.
