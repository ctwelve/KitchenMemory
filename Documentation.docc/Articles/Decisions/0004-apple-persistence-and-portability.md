# ADR 0004: Use SwiftData, CloudKit, and versioned import and export

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


- Status: Accepted
- Date: 2026-08-10

## Context

Kitchen Memory is intended to feel native on Apple platforms. People expect
their private data on all their devices and a Kitchen to be shareable with other
household members. They also need a durable way to retain and move their content
without treating the application's private database as a public file format.

## Decision

Use SwiftData as the first local persistence implementation and CloudKit as the
synchronization and household-collaboration platform.

Do not commit the domain or Logic operations to SwiftData managed CloudKit sync
as the only integration mechanism. The first synchronization slice targets the
private database for one person's devices and selects its integration after a
focused prototype. Select or supplement that mechanism for multi-person Kitchen
sharing only after a later collaboration prototype exercises participants,
permissions, private and shared database scopes, and conflict behavior.

Before promoting the first production CloudKit schema, make the persistence
model compatible with the selected integration and validate its generated
schema. After promotion, evolve CloudKit additively: new product aggregates may
add record types and fields, but published elements are neither removed nor
repurposed. Corresponding local persistence changes use new immutable SwiftData
schema versions and deliberate migration stages.

Provide documented, versioned import and export formats as the content-
sovereignty mechanism. Portable data is expressed in domain terms and includes
the stable identities, provenance, source evidence, and media appropriate to the
exported scope.

## Consequences

- The application can use native local persistence, observation, and iCloud
  capabilities.
- CloudKit schema constraints must influence persistence records before a
  production schema is promoted.
- A later aggregate such as `CookingSession` can add storage and CloudKit record
  types without rewriting existing recipe content, but it still requires a new
  local schema version and tested migration stage.
- Multi-person sharing remains an explicit product and sync responsibility.
- Export formats require versioning and migration independently of SwiftData.
- Replacing or supplementing persistence technology does not require changing
  the domain model.
