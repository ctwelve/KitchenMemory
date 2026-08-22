# Continuous integration

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

Xcode Cloud is Kitchen Memory's continuous-integration system. The shared
`KitchenMemory` scheme is the source of truth for local and cloud build, test,
Analyze, and archive behavior; CI-only replacements for those actions should
be avoided.

## Workflow policy

### Slice development

The slice workflow starts for meaningful project changes pushed to `slice/*`
branches. It performs Build, Analyze, and Test actions using the shared
`KitchenMemory` scheme, but does not archive a product.

Build and Analyze are required to pass. Test is advisory while the application
UI is changing rapidly, allowing work on `slice/*` to continue through known UI
test instability while still reporting the failures.

### Main production

The production workflow starts for meaningful project changes merged or pushed
to `main`. It requires Test on iOS and macOS, Analyze on iOS, macOS, and visionOS,
and Archive on iOS, macOS, and visionOS to pass. Each Archive action is the
production Release build for that platform, so separate Build actions would
duplicate that work without producing different artifacts.

Repeating the tests on `main` verifies the actual merge result, including its
interaction with changes that landed after a slice branch began. Running Analyze
and Archive across every supported platform deliberately pays the full production
confidence cost on `main`; the slice workflow remains the lighter development
feedback loop.

### Change filters

Both workflows use file and folder conditions so source, project, dependency,
test, asset, lint, and cloud-script changes run CI. Documentation-only and other
non-product maintenance changes do not spend a full build allocation. Keep the
filters conservative: configuration such as `.swiftlint.yml`, `Package.resolved`,
the shared scheme and test plan, and `ci_scripts` can change build behavior even
when no Swift source changed.

### Pull-request gate

The pull-request workflow starts for meaningful project changes in pull requests
from `slice/*` into `main`. Its Test action is required to pass, while tests in
the slice-development workflow remain advisory during ordinary development.

Xcode Cloud reports the pull-request result to GitHub. To make the gate prevent
rather than merely warn about a failed merge candidate, configure the resulting
Xcode Cloud build or Test action as a required GitHub status check for `main`.
The production workflow repeats required tests after merge to verify the actual
result on `main`.

The accessibility UI tests may remain advisory while their hierarchy is changing.
Their audit model and accepted Xcode false positives are documented in
<doc:accessibility-engineering>.

Xcode Cloud workflow metadata and start conditions live in Xcode Cloud rather
than in this repository. Keep its actions, requirements, branch patterns, and
change filters aligned with this policy. Add TestFlight or notarization as
distribution post-actions when release automation is ready.

## Static analysis

The shared scheme marks the application as buildable for Analyze. Project build
settings select Xcode's `deep` static-analyzer mode specifically for the Analyze
action. The analyzer does not run during every ordinary build, avoiding a slower
duplicate pass during day-to-day development.

Run the same action locally with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -skipPackagePluginValidation analyze \
  -project KitchenMemory.xcodeproj \
  -scheme KitchenMemory \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/KitchenMemoryAnalyze \
  CODE_SIGNING_ALLOWED=NO
```

## SwiftLint

SwiftLint is a pinned Swift package build-tool plugin attached to the application,
internal frameworks, and test targets. Consequently, linting runs for the source
files Xcode is already building, both locally and in Xcode Cloud. There is no
separate cloud lint installation or script.

The root `.swiftlint.yml` is the development policy: violations retain their
configured severities instead of being promoted globally. File length warns
above 400 lines and becomes an error above 1,000 lines. The goal remains a
warning-free tree, but an ordinary maintenance warning does not block local,
slice, or bug work. Strict warning promotion is reserved for an explicit release
engineering scheme once that scheme split is added, rather than inherited by
every build.

The opt-in rules are deliberately limited to product safety and lifecycle
mistakes, collection correctness and avoidable work, SwiftUI accessibility
contracts, and test quality. Formatting preferences that would create broad
mechanical churn are not CI policy.

When adding an opt-in rule:

1. audit it across the application, frameworks, and both test targets;
2. confirm that its findings represent defects or an agreed maintenance cost;
3. bring the current tree to zero violations before making it required; and
4. avoid a baseline unless an incremental migration has been explicitly chosen.

Xcode Cloud's noninteractive environment cannot approve package-plugin
fingerprints. The executable `ci_scripts/ci_post_clone.sh` enables Xcode's
package-plugin fingerprint bypass before each action. This is acceptable only
because `Package.resolved` pins the SwiftLint plugin revision; dependency updates
must be reviewed like source changes.

## Maintenance

Xcode Cloud can update its Xcode and macOS environment. Treat a toolchain change
as a deliberate migration: run the shared scheme locally with that Xcode version,
review new analyzer and linter diagnostics, and then update the workflow.

Custom scripts in `ci_scripts` run for every cloud action. Keep them short,
deterministic, and limited to environment preparation so build, test, Analyze,
and archive behavior remains visible in the shared scheme.
