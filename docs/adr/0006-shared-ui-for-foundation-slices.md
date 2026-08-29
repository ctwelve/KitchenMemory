# ADR 0006: Use a shared UI for the foundation slices

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

## Status

Accepted.

## Context

Kitchen Memory is still establishing its domain, import, persistence, and core
application workflows. A basic interface is valuable because it exercises
those slices end to end on Mac, iPhone, and iPad.

The mature experiences may diverge substantially. A serious Mac recipe editor
could benefit from AppKit's precise pointer, keyboard, focus, text-editing,
drag-and-drop, window, panel, and accessibility control. Storyboards may also
be valuable for visual interface design and rapid experimentation. Mobile
editing must instead be designed for touch, compact presentation, and
platform-appropriate disclosure and rearrangement.

Choosing those mature presentation architectures now would require decisions
before the product workflows are sufficiently understood.

## Decision

Use a basic shared SwiftUI interface as the vehicle for completing and
validating the foundation slices.

Keep that interface coherent, accessible, and platform-appropriate where small
differences are necessary, but do not treat maximum view reuse or final visual
design as goals during this phase. Avoid elaborate interactions that would
prematurely commit the product to a presentation architecture.

Continue to keep the domain, import pipeline, persistence interfaces, and Logic
operations outside the view layer. The shared core is the durable
product investment; the current shared UI is replaceable scaffolding.

Before serious visual-editor work begins, evaluate separate Mac and mobile
presentation products using representative interactions such as in-place
ingredient editing, contextual option presentation, step rearrangement,
keyboard and pointer operation, touch operation, undo, and accessibility. That
evaluation should include SwiftUI, AppKit or UIKit, Storyboards where their
visual workflow is useful, and hybrid approaches.

## Consequences

- Foundation slices can continue through one small, testable application UI.
- Current SwiftUI screens are not presumed to be the final Mac or mobile design.
- Platform-specific presentation code is acceptable when it keeps the shared
  UI functional and accessible.
- A future decision may select a first-class AppKit Mac application and a
  separately designed mobile application without replacing the shared core.
- Presentation-framework selection is deferred until a representative editor
  prototype can provide evidence.

[ADR 0009](0009-separate-native-app-targets.md) gives iOS and macOS distinct product
targets while retaining this shared 0.1 application layer. It does not
supersede this decision or make shared presentation a requirement for 0.2.
