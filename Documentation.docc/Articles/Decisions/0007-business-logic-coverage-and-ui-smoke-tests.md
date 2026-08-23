# ADR 0007: Prioritize complete business-logic coverage and keep UI tests to smoke tests

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

## Status

Accepted.

## Context

Kitchen Memory's domain rules, product operations, import behavior, and
persistence contracts are durable product investments. The current shared
SwiftUI interface is deliberately replaceable scaffolding. Its modal editing
flows, detailed layout, visible copy, and accessibility hierarchy are expected
to change as the Mac and mobile experiences mature.

Broad UI automation has imposed a disproportionate maintenance cost on this
provisional interface. Detailed assertions also couple tests to English copy at
the point when the application still needs an internationalization pass and
String Catalog adoption. Accessibility proofing against unstable screens would
mostly prove implementation that the project already intends to replace.

## Decision

Target complete automated coverage of executable business logic, including its
meaningful branches, boundary cases, failure behavior, and preservation rules.
Keep that logic outside views so the domain, Logic, import, and persistence
suites can exercise it deterministically without launching the application UI.

Use UI automation only for smoke coverage of the durable application shell:

- the application launches into its recipe library;
- the sidebar presents recipes and opens a recipe;
- the sidebar's basic visibility control works where present; and
- Settings opens and guards destructive reset behind confirmation.

Do not add UI tests for provisional editor layout, scrolling, disclosure state,
exact visible strings, or detailed accessibility-tree behavior. A feature whose
behavior can be verified below the view layer must be tested there.

Continue to use native controls, semantic structure, and sensible accessibility
labels during prototyping. Defer exhaustive accessibility audits, localized-copy
verification, screenshots, and interaction-specific UI coverage until the
relevant interface and its String Catalog are stable enough to represent a
shipping contract.

Coverage percentage is evidence, not a substitute for test quality. Generated
code, declarations without executable behavior, and unreachable defensive paths
must not motivate artificial tests. Any exclusion from the business-logic
coverage target should be narrow and documented.

## Consequences

- Business-rule changes are incomplete until their success, failure, boundary,
  and preservation behavior is covered below the UI.
- UI tests remain fast, few, identifier-driven, and resilient to localization.
- Provisional UI can be redesigned without repairing tests that encode obsolete
  presentation choices.
- Accessibility remains a product requirement, but comprehensive proof becomes
  an interface-stabilization and release-hardening activity.
- Internationalization work can establish String Catalogs and localized
  behavior before tests treat user-facing copy as a stable contract.
- ADR 0005 still governs test frameworks and code comprehension; this decision
  narrows where each kind of test should be invested.
