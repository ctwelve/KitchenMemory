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
automation to the application-shell smoke tests defined by
[ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md). Comprehensive audits and
interaction-specific accessibility tests resume when the relevant interface is
stable enough to represent a shipping contract.

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

The UI suite verifies only that:

- the application launches into the recipe library;
- a recipe can be selected from the sidebar;
- the sidebar can be hidden and restored where that control is present; and
- Settings presents confirmation before destructive reset;
- the Cooking Session lifecycle shell can Start, Stop, Resume, Finish, leave,
  and reopen retained work; and
- one representative Cooking Session path can account for an ingredient,
  complete an instruction, and change a working yield when available; and
- the first-class Sessions destination exposes Current, Recent, and Finished
  history, deliberate Session switching, and one representative continuation
  path with inspectable lineage; and
- the durable recovery shell confirms one Delete and Restore path and exposes
  the separate Deleted Items and Recovery destinations.

The tests use stable identifiers instead of visible English copy so they remain
useful through String Catalog adoption and localization. Hosted tests separately
prove container-width composition boundaries, accessibility-size reading order,
ordered retry, and relaunch-safe state restoration without coupling automation
to the provisional SwiftUI tree.

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
4. add focused automated checks for stable, high-value interaction contracts;
5. run platform accessibility audits and investigate each result against the
   current Xcode toolchain; and
6. document only the narrow exceptions that current evidence requires.

Do not restore broad UI assertions merely to increase a coverage percentage.
Coverage goals apply to durable business logic; accessibility confidence for a
stable interface requires semantic review, assistive-technology use, and focused
automation together.

## Validation environment

Record Xcode, operating-system, simulator, and device versions with future audit
evidence. SwiftUI can expose different accessibility structures on macOS and iOS,
and toolchain behavior changes. An exception observed in one environment is not
a permanent rule for later releases.
