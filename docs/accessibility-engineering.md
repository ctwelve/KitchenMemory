# Accessibility engineering

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Accessibility is part of Kitchen Memory's product contract, not a decorative
release task. The depth of automated proof should nevertheless match the
stability of the interface being proved.

The current shared SwiftUI interface is replaceable scaffolding. During this
phase, use native semantics and avoid creating obvious barriers, but keep UI
automation to the accessible top-level structure defined by
[ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md). Comprehensive
audits and interaction-specific accessibility tests resume when the relevant
interface is stable enough to represent a shipping contract and
[Issue 132](https://github.com/ctwelve/KitchenMemory/issues/132) defines the
appropriate validation layers.

## Principles during prototyping

- Prefer native `Text`, `Button`, `NavigationLink`, form controls, headings,
  semantic colors, and Dynamic Type behavior.
- Hide decorative imagery from assistive technologies.
- Give interactive controls meaningful accessible names even when their visual
  presentation is icon-only.
- Give durable navigation landmarks stable identifiers. Identifiers support
  automation but do not replace accessible names.
- Keep business rules and validation outside views so they can be tested without
  relying on an accessibility hierarchy.
- Do not add toolchain-specific audit exceptions for provisional screens.

These practices make later accessibility work cheaper without claiming that a
placeholder interface has received release-level proof.

## Current automated scope

The UI suite verifies only that the recipe library, Settings, and startup
recovery expose meaningfully named accessibility elements and that the recipe,
Sessions, Deleted Items, and Recovery destinations are reachable and expose
their named top-level structure.

Stable identifiers locate those elements without depending on translated copy;
the assertions then inspect accessible names and enabled state. An identifier is
an automation hook, not a user-facing name and not proof of accessibility.
Navigation activation is only a means of revealing the next top-level structure.
The suite does not test workflow behavior, coordinates, layout, geometry,
scrolling, or incidental hierarchy shape.

Hosted and framework tests separately prove behavior, including
container-width composition boundaries, accessibility-size reading order,
ordered retry, state transitions, and relaunch-safe restoration. Human
assistive-technology walkthroughs remain necessary because element existence
and labels cannot establish focus order, grouping, spoken coherence, or actual
VoiceOver usability.

Slice 15 uses native buttons, menus, headings, selection traits, state values,
and Dynamic Type. A physical iPhone/iPad and Mac pass with keyboard and
VoiceOver remains deliberate feature-acceptance work rather than evidence
claimed by the hosted smoke suite.

## Stabilization gate

Before declaring an interface stable or release-ready:

1. define the supported keyboard, pointer, touch, VoiceOver, Dynamic Type, and
   reduced-motion behavior for that workflow;
2. establish the String Catalog and verify layouts with representative longer
   translations and right-to-left presentation;
3. manually inspect the workflow on each supported platform and input model;
4. apply the layered automation strategy produced by Issue 132 to stable,
   high-value semantic contracts;
5. run platform accessibility audits and investigate each result against the
   current Xcode toolchain; and
6. document only the narrow exceptions that current evidence requires.

Do not restore broad UI assertions merely to increase a coverage percentage or
to prove that standard controls respond to taps.
Coverage goals apply to durable business logic; accessibility confidence for a
stable interface requires semantic review, assistive-technology use, and focused
automation together.

## Validation environment

Record Xcode, operating-system, simulator, and device versions with future audit
evidence. SwiftUI can expose different accessibility structures on macOS and iOS,
and toolchain behavior changes. An exception observed in one environment is not
a permanent rule for later releases.
