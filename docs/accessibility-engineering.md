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
[ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md). The accepted release policy from
[Issue 132](https://github.com/ctwelve/KitchenMemory/issues/132) is recorded below
and in [ADR 0019](adr/0019-stage-accessibility-acceptance-at-beta.md).

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

## Alpha release gate

Alpha development must keep accessibility programming sound and avoid accumulating
untracked accessibility debt. The current UI is a playground/proof of concept;
comprehensive validation of its incidental layout would consume effort that
belongs to the intended shipping interface. The current push defines policy and
performs bounded alpha checks; it does not declare the UI stable. Releasing
0.3-alpha does not commit the next milestone to beta rather than more features.

Every published alpha requires the bounded semantic checks described above and
a short ordinary-use walkthrough of core paths on the platforms actually
distributed. Cover startup/recovery, finding and reading Recipes, creating or
importing and saving one, starting/resuming a Cooking Session, and reaching
Settings. Focus additional checks on changed interactions. Ordinary development
slices use checks appropriate to their changes; the
[alpha translation device-check waiver](localization-alpha-validation.md) remains
in force.

The device-class, VoiceOver, and extensive accessibility/layout matrix below is
deferred to beta. Alpha evidence must say what was omitted; deferred proof is
unverified, not a pass. Known barriers that prevent a core path using a supported
input method or assistive technology block alpha distribution. Examples include
unreachable essential actions, unnamed essential controls, focus traps, and
inaccessible recovery when they prevent completion.

## Beta stabilization and acceptance

[Issue 168](https://github.com/ctwelve/KitchenMemory/issues/168) holds this future
work independently of the 0.3-alpha release graph.

First approach the UI comprehensively. Only after that design pass may individual
workflows be declared stable: navigation, controls, reading order, and supported
interactions must be intended to ship. Today's provisional screens do not qualify
merely because they have stopped changing. Beta requires every supported workflow
to reach this point, including organization, editing, deletion, and restoration.

Validate all supported workflows across Mac, iPhone, and iPad using a documented
representative matrix rather than every possible combination:

- VoiceOver and keyboard navigation where supported;
- native touch and pointer operation;
- accessibility text sizes, smaller screens, and constrained window sizes;
- light/dark appearance, increased contrast, and reduced motion; and
- every shipping language.

Platform audits, Accessibility Inspector, and human assistive-technology
walkthroughs determine accessibility acceptance. Check focus order, grouping,
spoken coherence, and the ability to complete tasks. A populated accessibility
tree and green UI tests cannot override an observed barrier. Missing required
beta audit or walkthrough evidence blocks distribution.

## Proof layers and automation

Domain, Logic, persistence, and hosted tests own business behavior. UI automation
proves durable accessibility semantics, not duplicate feature workflows or native
button behavior. Add focused accessibility regression tests when they reliably
catch a real barrier; do not expand automation to satisfy a coverage quota.

Reliable automated semantic regressions block pull requests. Diagnose runner and
toolchain failures and provide an alternate local check with evidence; a tooling
failure cannot silently excuse a product regression. Cloud UI testing remains
suspended under [Issue 155](https://github.com/ctwelve/KitchenMemory/issues/155).
Local native tests use [Xcode-managed signing](agents/xcode.md). The ordinary CI
and governed-branch gates remain in force; release acceptance additionally
requires the human evidence appropriate to alpha or beta.

## Findings and release evidence

Use blocking tickets instead of a separate exception/assignment bureaucracy for
this personal project. Core-path barriers block alpha; other accessibility
findings block the relevant stabilization/beta gate. Visual polish alone is not
an accessibility blocker. Record user impact, reproduction evidence, any usable
workaround, and the applicable release gate so findings cannot silently become
permanent debt. Alpha deferral does not carry into beta as acceptance.

The release maintainer explicitly accepts a versioned release-evidence document
before distribution. Identify the exact candidate, checks and workflows,
Xcode/toolchain and OS versions, device/configuration matrix actually exercised,
results, omissions, linked blocking tickets, and toolchain limitations. Keep
records privacy-safe and retain prior release evidence permanently.

Navigation, control semantics, focus behavior, layout, or relevant platform and
toolchain changes reopen affected checks. Unchanged workflows may carry forward
explicitly linked evidence with its scope and continuing applicability stated.
Record false positives against the specific environment where they were
established; never turn them into permanent toolchain folklore.
