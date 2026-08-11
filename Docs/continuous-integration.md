<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# Continuous integration

GitHub Actions repeats the project's core and accessibility verification on
clean, GitHub-hosted Macs.

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

macOS and iOS each have three distinct checks:

1. `Build` compiles the application. The macOS build also builds the native
   DocC documentation.
2. `Core tests` runs after that platform's build succeeds. The macOS check also
   runs the KitchenMemoryDomain and sample-data package tests.
3. `Accessibility` runs the UI test target after that platform's build
   succeeds.

The two platform pipelines are independent: macOS checks do not wait for iOS
checks, and iOS checks do not wait for macOS checks. The repository's merge
rules require both platform builds and both core-test checks directly, so there
is no additional aggregator job or runner-startup delay.

Accessibility results remain visible and actionable on every pull request but
are deliberately outside the required merge gate. This keeps platform-specific
accessibility regressions explicit without making unrelated feature work wait
on differences in SwiftUI's platform accessibility trees.

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

On macOS, SwiftUI exposes non-interactive layout groups to XCTest while keeping
their native `Text` nodes separate in the query tree. Xcode 26 then reports
those structural groups as having no description even though VoiceOver reaches
the labeled native elements. The macOS audit accepts only
sufficient-description findings whose reported element is an empty-labeled,
non-hittable `Group`. Buttons, links, other controls, hittable elements, and all
other audit categories remain fatal. The read-flow test separately proves both
that each stable automation identifier exists and that its expected native text
exists, without assuming macOS and iOS organize those facts on the same node.

## Security and resource choices

The workflow grants its GitHub token read-only repository access. Checkout does
not persist credentials because no step needs to write to the repository.

`Build (macOS)`, `Core tests (macOS)`, `Build (iOS)`, and `Core tests (iOS)` are
required status checks. The two accessibility checks are intentionally
optional; changing that policy requires updating the repository's merge rules,
not adding `continue-on-error` to the workflow. This distinction preserves
honest failing results while preventing those results from blocking a merge.

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
