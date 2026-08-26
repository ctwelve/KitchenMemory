# ADR 0005: Prefer a consistent test model and code optimized for comprehension

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


- Status: Accepted
- Date: 2026-08-10

## Context

Kitchen Memory is a long-lived learning project as well as a household tool. Its
application and UI tests benefit from one familiar testing model. The codebase
also needs clear boundaries without accumulating layers whose cost exceeds the
small application's needs.

## Decision

Use XCTest for application, integration, and UI tests so those suites share one
testing model and toolchain. This does not prohibit Swift Testing where it is a
better fit for independent domain or support modules.

Keep the codebase modular, tidy, and compact. Prefer small types, explicit data
flow, domain language, and a limited number of meaningful layers. Introduce an
abstraction when it protects an established boundary, enables a required
platform capability, or removes demonstrated duplication—not merely because a
larger system might need it.

Optimize implementation choices first for correctness and comprehension.
Performance work should follow evidence from measurement or actual use.

## Consequences

- Application and UI testing use the same XCTest concepts and Xcode tooling.
- Independent domain or support test targets remain free to adopt Swift Testing
  without forcing mixed conventions inside one test target.
- Module boundaries remain intentional rather than multiplying with every type.
- Straightforward code is preferred to speculative generality.
- Non-obvious Apple-platform idioms should be explained where naming and
  structure do not make their purpose clear.
