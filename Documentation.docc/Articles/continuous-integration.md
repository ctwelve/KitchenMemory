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

Build and Analyze are required to pass. Test is advisory on `slice/*` while the
project establishes complete business-logic coverage and keeps UI automation to
the durable application-shell smoke tests. A failing logic test is still a
product defect even when that cloud action is not yet a branch gate.

### Main production

The production workflow starts for meaningful project changes merged or pushed
to `main`. It requires Test, Analyze, and Archive on iOS and macOS to pass. Each
Archive action is the production Release build for that platform, so separate
Build actions would duplicate that work without producing different artifacts.

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

The UI target contains smoke tests only. Comprehensive accessibility audits,
localized-copy checks, and interaction-specific UI suites are deferred until the
relevant interface is stable. See
<doc:0007-business-logic-coverage-and-ui-smoke-tests> and
<doc:accessibility-engineering>.

The committed test plan collects code coverage. Evaluate the durable domain,
import, persistence, and application-operation sources separately from SwiftUI
views and test bundles; an app-wide percentage is not the business-logic metric.
Use uncovered executable lines to find missing behavior and boundary tests, not
to justify exercising provisional views through UI automation.

### Core framework coverage gate

Generate a fresh coverage bundle from the complete non-UI test target and apply
the gate in the same run:

```sh
Tools/run-core-framework-coverage.sh
```

The runner creates a unique evidence directory under `/private/tmp`, prints its
location, runs the tests, and invokes the checker only after Xcode succeeds. To
check an existing result bundle directly, pass it to:

```sh
Tools/check-core-framework-coverage.sh /path/to/Tests.xcresult
```

The script reads Xcode's integer covered and executable line counts rather than
its rounded percentage. It prints evidence for the domain, import, logic, and
persistence frameworks and
fails when a target or current framework source is missing, when even one
executable line is uncovered, or when source, tests, the test plan, or project
membership, scheme behavior, or resolved dependencies changed after the bundle's
recorded build start.

### Deterministic property-test corpora

Property tests load named entropy seeds from
`KitchenMemoryTests/TestSupport/PropertyTestSeeds.json`. Failure messages record
the seed and case number so a generated input can be replayed exactly. The test
harness verifies catalog integrity, proves that changed seeds produce different
raw and derived corpora, and pins a known-answer vector so an accidental generator
rewrite cannot silently change the meaning of an existing seed/case pair.

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
