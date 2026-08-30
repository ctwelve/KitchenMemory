# ADR 0008: Freeze the 0.1 localization contract

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

## Status

Accepted.

## Context

The 0.1 interface is stable enough to live with before the planned 0.2 redesign.
Its original String Catalog grew from automatically extracted English sentences,
which made visible copy double as identifier, left reusable editor prompts
outside extraction, and allowed English plural behavior to remain incomplete.

ADR 0007 deferred localized UI proof until the interface and catalog represented
a shipping contract. That condition is now met for 0.1, even though its layout
remains replaceable.

## Decision

Treat the meaning expressed by the 0.1 interface as a versioned localization
contract. Use manually managed semantic keys with explicit American English,
Canadian French, and Mexican Spanish values. Access them through Xcode-generated
localizable symbols, use named operands for formatted messages, and require
translator context for every entry.

Enforce the catalog structure in unit tests and preserve locale-specific
formatter tests for plural and composed wording. Exercise the durable UI shell
under all supported locales, doubled strings, and forced right-to-left writing
direction without coupling smoke tests to visible copy.

A future redesign may rearrange or replace views without renaming keys whose
product meaning is unchanged. Add or retire keys when meaning changes, not merely
when layout changes. Authored recipe content remains outside the interface
catalog and continues to follow the resource model in
[localization architecture](../localization-architecture.md).

## Consequences

- A missing translation, translator comment, plural branch, or placeholder match
  is a test failure rather than a catalog-review convention.
- Application views no longer contain English fallback sentences for stable 0.1
  interface copy.
- The 0.2 redesign can reuse established product vocabulary while replacing the
  0.1 presentation architecture.
- Linguistic review and visual accessibility review remain human release tasks;
  smoke automation proves structural survival rather than prose quality.
- ADR 0007 continues to limit detailed UI automation and is not superseded.
