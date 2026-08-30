# ADR 0007: Prioritize complete business-logic coverage and keep UI tests to smoke tests

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

## Status

Accepted.

Amended by [ADR 0012](0012-consolidate-business-code-in-kitchenkit.md) and
[ADR 0013](0013-unified-native-multiplatform-app-target.md): the
coverage-versus-UI investment policy remains, but `KitchenKitTests` is now one
unhosted target and `KitchenMemoryTests` is one multiplatform hosted target.
Each shared scheme builds only its primary product and references one checked-in
test plan; the plan is the sole owner of test-target membership.
`KitchenMemory.xctestplan` runs hosted tests plus the shared UI smoke target on
both native destinations, while `KitchenKit.xctestplan` runs the unhosted
framework suite. Both use `Testing` as the default Test configuration. Names
below record historical topology where applicable, not the live project contract.

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

- the application launches into its durable recipe shell and can reach its sidebar;
- the sidebar presents recipes and opens a recipe;
- the sidebar's basic visibility control works where present; and
- Settings opens and guards destructive reset behind confirmation; and
- the durable Sessions destination reaches Current, Recent, and Finished
  history, supports deliberate switching, and completes one representative
  immutable continuation path; and
- the durable recovery shell completes one representative Delete and Restore
  path and reaches the separate Deleted Items and Recovery destinations.

Do not add UI tests for provisional editor layout, scrolling, disclosure state,
exact visible strings, or detailed accessibility-tree behavior. A feature whose
behavior can be verified below the view layer must be tested there.

Keep the multiplatform `KitchenMemoryTests` target and the `Testing`
configuration non-UI. `KitchenMemory.xctestplan` contains that hosted target and
the bounded `KitchenMemoryUITests` smoke target; the same saved plan is an
application correctness gate on iOS Simulator and native macOS. Both use the
least-privilege disposable `Testing` host by default. The actual `Production`
application must not contain the disposable UI-test storage switch.

`KitchenKitTests` is one standalone, unhosted XCTest target. The `KitchenKit`
scheme and `KitchenKit.xctestplan` run it once on the canonical macOS
destination and generate the exact line-coverage artifact. Shared property-test
support is compiled directly into that target rather than becoming another
production module. Both application destinations remain required because
native composition, resources, build settings, and runtime behavior can fail
independently of the shared source metric.

Continue to use native controls, semantic structure, and sensible accessibility
labels during prototyping. Defer exhaustive accessibility audits, localized-copy
verification, screenshots, and interaction-specific UI coverage until the
relevant interface and its String Catalog are stable enough to represent a
shipping contract.

Coverage percentage is evidence, not a substitute for test quality. Generated
code, declarations without executable behavior, and unreachable defensive paths
must not motivate artificial tests. Any exclusion from the business-logic
coverage target should be narrow and documented.

The direct Apple-runtime bridge in `PersonalCloudStatusMonitor.swift` is one
such exclusion. It performs a real `CKContainer` account query and receives a
Core Data CloudKit event object that Apple does not expose a public initializer
for. Its deterministic status reducer is isolated in `PersonalCloudStatus.swift`
and remains subject to the exact coverage gate; focused adapter tests still
exercise notification delivery, concurrency hops, and stale-result rejection.

## Consequences

- Business-rule changes are incomplete until their success, failure, boundary,
  and preservation behavior is covered below the UI.
- UI tests remain fast, few, identifier-driven, and resilient to localization.
- The standalone core lane supplies the canonical exact framework coverage
  artifact; both destination-level application-test runs remain correctness gates.
- Provisional UI can be redesigned without repairing tests that encode obsolete
  presentation choices.
- Accessibility remains a product requirement, but comprehensive proof becomes
  an interface-stabilization and release-hardening activity.
- Internationalization work can establish String Catalogs and localized
  behavior before tests treat user-facing copy as a stable contract.
- ADR 0005 still governs test frameworks and code comprehension; this decision
  narrows where each kind of test should be invested.
- [ADR 0013](0013-unified-native-multiplatform-app-target.md) defines the native
  multiplatform app target and shared application plan without changing this
  division between durable logic coverage and application-shell smoke coverage.
