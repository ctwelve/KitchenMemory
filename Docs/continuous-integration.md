<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# Continuous integration

GitHub Actions repeats the project's core verification on a clean,
GitHub-hosted Mac.

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
2. Run the KitchenMemoryDomain and sample-data package tests.
3. Build the macOS app and run its tests.
4. Build the iOS app and run its tests on an iPhone Simulator.
5. Build the native DocC documentation.

Application, integration, and UI targets use XCTest as their common test model.
Independent domain and support packages may use Swift Testing when it improves
their tests without mixing conventions inside one target.

The commands disable code signing because these checks produce no distributable
application and require no development certificate. A shared temporary Derived
Data directory lets later Xcode steps reuse compatible work from earlier steps.

The UI suite treats accessibility semantics as part of the app's test contract.
It verifies stable identifiers and reading order for the starter recipe, then
runs XCTest accessibility audits in light and dark appearances. The audits cover
contrast, element detection, hit regions, descriptions, Dynamic Type, clipped
text, and traits.

Recipe metadata combines each decorative SF Symbol and adjacent label into one
phrase so VoiceOver announces, for example, “Yield” instead of “person.2,
Yield.” Xcode 26 cannot infer the font behavior of the inner native `Text` nodes
after SwiftUI creates that combined accessibility node, so it reports a Dynamic
Type false positive. The audit handler accepts only Dynamic Type findings whose
identifiers begin with `recipe-metadata-label-` or `recipe-metadata-value-`.
Every other finding remains fatal. The metadata text uses SwiftUI's unmodified
Dynamic Type behavior, and its grid becomes a single flexible column at
accessibility sizes to prevent genuine clipping.

## Security and resource choices

The workflow grants its GitHub token read-only repository access. Checkout does
not persist credentials because no step needs to write to the repository.

All checks run in one job to keep the first workflow understandable and avoid
provisioning several macOS runners for the same commit. The job has a 20-minute
timeout to prevent an unexpected hang from consuming runner time indefinitely.
The repository is public. CI should nevertheless remain economical and avoid
unnecessary duplicate macOS jobs.

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
