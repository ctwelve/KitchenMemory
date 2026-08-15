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

Do not commit the domain or application use cases to SwiftData managed CloudKit
sync as the only integration mechanism. Select the final combination of managed
sync, Core Data CloudKit integration, and direct CloudKit behavior after a
shared-Kitchen collaboration prototype.

Provide documented, versioned import and export formats as the content-
sovereignty mechanism. Portable data is expressed in domain terms and includes
the stable identities, provenance, source evidence, and media appropriate to the
exported scope.

## Consequences

- The application can use native local persistence, observation, and iCloud
  capabilities.
- CloudKit schema constraints must influence persistence records before a
  production schema is promoted.
- Multi-person sharing remains an explicit product and sync responsibility.
- Export formats require versioning and migration independently of SwiftData.
- Replacing or supplementing persistence technology does not require changing
  the domain model.
