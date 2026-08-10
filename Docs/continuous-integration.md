<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# Continuous integration

The bootstrap repository used GitHub Actions to repeat the project's core
verification on a clean, GitHub-hosted Mac. Equivalent continuous integration
will be reinstated after the standard multiplatform project and
`KitchenMemoryDomain` package are integrated.

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

One `macos-26` job performs the same checks used during local development:

1. Report the selected Xcode version in the log.
2. Run the KitchenMemoryDomain Swift package tests.
3. Build the macOS app and run its tests.
4. Build the app for a generic iOS Simulator destination.
5. Build the native DocC documentation.

The commands disable code signing because these checks produce no distributable
application and require no development certificate. A shared temporary Derived
Data directory lets later Xcode steps reuse compatible work from earlier steps.

## Security and resource choices

The workflow grants its GitHub token read-only repository access. Checkout does
not persist credentials because no step needs to write to the repository.

All checks run in one job to keep the first workflow understandable and avoid
provisioning several macOS runners for the same commit. The job has a 20-minute
timeout to prevent an unexpected hang from consuming runner time indefinitely.
Because this is a private repository, macOS jobs consume the account's GitHub
Actions minutes.

## Maintenance

GitHub updates its hosted runner images and their default Xcode installations.
The workflow records `xcodebuild -version` on every run so a toolchain change is
visible in the log. Update the runner label or select a specific installed Xcode
when the project needs a deliberate migration rather than accepting the hosted
image's default.

If CI becomes slow or expensive, useful later refinements include running the
portable KitchenMemoryDomain tests on Linux, separating documentation into a less
frequent job, or adding dependency caching. Those optimizations are intentionally
deferred until measurements justify their complexity.
