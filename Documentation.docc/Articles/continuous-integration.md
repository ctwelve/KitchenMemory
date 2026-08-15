# Continuous integration

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


GitHub Actions repeats the project's build and core-test verification on clean,
GitHub-hosted Macs.

## When CI runs

The workflow runs:

- for every pull request targeting `main`;
- after a commit is pushed to `main`; and
- when started manually from GitHub's Actions interface.

Pull-request runs provide feedback before a change is merged. The subsequent
`main` run verifies the resulting branch, including GitHub-created merge
commits. If a newer commit makes an in-progress run obsolete, concurrency
control cancels the older run.

## What CI verifies

macOS and iOS each have two distinct checks:

1. `Build` compiles the application. The macOS build also builds the native
   DocC documentation.
2. `Core tests` runs after that platform's build succeeds. The macOS check also
   runs the KitchenMemoryDomain and sample-data package tests.

The two platform pipelines are independent: macOS checks do not wait for iOS
checks, and iOS checks do not wait for macOS checks. The repository's merge
rules require both platform builds and both core-test checks directly, so there
is no additional aggregator job or runner-startup delay.

The accessibility UI-test jobs are temporarily disabled while the application
UI is changing rapidly. The tests and their local-running documentation remain
in the repository; restore the platform-specific jobs when the primary recipe
workflows and accessibility tree are stable enough for their results to be
durable CI signals.

Application, integration, and UI targets use XCTest as their common test model.
Independent domain and support packages may use Swift Testing when it improves
their tests without mixing conventions inside one target.

The commands disable code signing because these checks produce no distributable
application and require no development certificate. Each job receives a clean
runner and its own temporary Derived Data directory. GitHub jobs do not share
build products automatically, so test jobs compile the test products they need
after the preceding build has established that the application itself compiles.
Sharing those products would require transferring large Derived Data artifacts;
that optimization is deferred until measurements justify its complexity.

The locally run UI suite treats accessibility semantics as part of the app's
test contract. It verifies stable identifiers and reading order for the starter
recipe, then runs semantic XCTest accessibility audits in light and dark
appearances. The audits cover element detection, hit regions, descriptions,
Dynamic Type, clipped text, traits, actions, and parent-child relationships.

The app-wide XCTest contrast audit is intentionally excluded. Xcode 26 samples
wholly offscreen macOS `ScrollView` text against unrelated onscreen pixels,
making that audit nondeterministic. The palette uses semantic text colors and
defined light/dark asset variants; a deterministic contrast specimen is a
finish-polish follow-up.

SwiftUI and XCTest expose several platform-specific structural and system-owned
elements. Every accepted false positive is matched by its audit type and exact
element evidence rather than by broad error text. The full semantic model,
exception boundaries, local runner-signing requirements, and result-bundle
debugging workflow are documented in
[Accessibility engineering](accessibility-engineering.md).

## Security and resource choices

The workflow grants its GitHub token read-only repository access. Checkout does
not persist credentials because no step needs to write to the repository.

`Build (macOS)`, `Core tests (macOS)`, `Build (iOS)`, and `Core tests (iOS)` are
required status checks. Accessibility checks are not currently emitted by the
workflow and must not be configured as required repository status checks.

Each job has a 20-minute timeout to prevent an unexpected hang from consuming
runner time indefinitely. The repository is public. CI should nevertheless
remain economical and avoid unnecessary duplicate work.

## Maintenance

GitHub updates its hosted runner images and their default Xcode installations.
The workflow records `xcodebuild -version` on every run so a toolchain change is
visible in the log. Update the runner label or select a specific installed Xcode
when the project needs a deliberate migration rather than accepting the hosted
image's default.

If CI becomes slow or expensive, useful later refinements include running
portable domain tests on Linux, separating documentation into a less frequent
job, or adding dependency caching. Those optimizations are intentionally deferred
until measurements justify their complexity.
