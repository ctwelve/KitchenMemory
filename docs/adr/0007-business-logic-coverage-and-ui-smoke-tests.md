# ADR 0007: Prioritize complete business-logic coverage and constrain UI automation

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
`KitchenMemory.xctestplan` runs hosted tests plus the shared top-level UI target on
both native destinations, while `KitchenKit.xctestplan` runs the unhosted
framework suite. Both use `Testing` as the default Test configuration. Names
below record historical topology where applicable, not the live project contract.

Amended on 2026-09-02 to clarify that the current UI target proves only
accessible top-level structure and navigation. It does not repeat feature
behavior or claim comprehensive assistive-technology validation.

## Context

Kitchen Memory's domain rules, product operations, import behavior, and
persistence contracts are durable product investments. The current shared
SwiftUI interface is deliberately replaceable scaffolding. Its modal editing
flows, detailed layout, visible copy, and accessibility hierarchy are expected
to change as the Mac and mobile experiences mature.

Broad UI automation has imposed a disproportionate maintenance cost on this
provisional interface. Interaction-heavy scripts mostly prove that XCUITest can
tap and scroll through the current SwiftUI layout. They duplicate behavior that
is proved more deterministically below the view layer and do not establish that
a screen reader receives a coherent interface. Stable automation identifiers
make elements findable; they are not accessibility evidence by themselves.

## Decision

Target complete automated coverage of executable business logic, including its
meaningful branches, boundary cases, failure behavior, and preservation rules.
Keep that logic outside views so the domain, Logic, import, and persistence
suites can exercise it deterministically without launching the application UI.

Use UI automation only to establish that the durable application shell exposes
meaningfully named top-level accessibility elements and that its principal
destinations are reachable:

- the recipe library and its recipe links;
- Sessions, Deleted Items, and Recovery;
- Settings; and
- the startup-failure recovery action.

Navigation activation is permitted only as the minimum action needed to reveal
and inspect a top-level destination. Do not use UI automation to re-prove
feature workflows, state transitions, framework-standard button behavior,
provisional editor layout, scrolling, disclosure state, exact visible strings,
or incidental accessibility-tree shape. Do not locate controls by coordinates.
A feature whose behavior can be verified below the view layer must be tested
there.

The current suite checks only a narrow semantic floor: required landmarks and
actions exist in the accessibility hierarchy, have meaningful names, are
enabled where appropriate, and reveal the expected destination structure. It
does not prove focus order, grouping quality, spoken phrasing, gesture behavior,
Dynamic Type, Switch Control, keyboard completeness, or VoiceOver usability.
[Issue 132](https://github.com/ctwelve/KitchenMemory/issues/132) holds the future
work to define a layered accessibility-first testing strategy before broader UI
automation returns.

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
names during prototyping. Human VoiceOver, keyboard, and platform accessibility
inspection remain necessary evidence at acceptance gates. Defer exhaustive
automated audits, screenshots, exact-focus scripts, and interaction-specific UI
coverage until the relevant interface is stable enough to represent a shipping
contract and Issue 132 defines the appropriate test layers.

Coverage percentage is evidence, not a substitute for test quality. Generated
code, declarations without executable behavior, and unreachable defensive paths
must not motivate artificial tests. Any exclusion from the business-logic
coverage target should be narrow and documented.

The direct Apple-runtime bridges in `PersonalCloudStatusMonitor.swift` and
`CloudKitKitchenOwnerIDResolver.swift` are such exclusions. They perform real
`CKContainer` account queries, and the status monitor receives a Core Data
CloudKit event object that Apple does not expose a public initializer for. The
deterministic status reducer is isolated in `PersonalCloudStatus.swift`, and the
owner resolver's opaque container-scoped mapping is isolated from its account
query; both remain subject to focused deterministic tests. Adapter tests still
exercise notification delivery, concurrency hops, and stale-result rejection.

## Consequences

- Business-rule changes are incomplete until their success, failure, boundary,
  and preservation behavior is covered below the UI.
- UI tests remain fast and few, use identifiers only to locate semantic
  elements, and assert accessible names rather than treating identifiers as
  accessibility proof.
- Hosted correctness tests may execute in parallel, while the UI target
  remains serial so every flow owns one deterministic application lifecycle.
- The standalone core lane supplies the canonical exact framework coverage
  artifact; both destination-level application-test runs remain correctness gates.
- Provisional UI can be redesigned without repairing tests that encode obsolete
  presentation choices.
- Accessibility remains a product requirement. The small automated shell suite,
  human assistive-technology acceptance, and future accessibility-first test
  strategy make distinct, explicitly bounded claims.
- Internationalization work can establish String Catalogs and localized
  behavior before tests treat user-facing copy as a stable contract.
- ADR 0005 still governs test frameworks and code comprehension; this decision
  narrows where each kind of test should be invested.
- [ADR 0013](0013-unified-native-multiplatform-app-target.md) defines the native
  multiplatform app target and shared application plan without changing this
  division between durable logic coverage and application-shell smoke coverage.
