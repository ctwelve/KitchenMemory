# Continuous integration

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

Xcode Cloud is Kitchen Memory's continuous-integration system. Three shared
schemes make the workflow boundary explicit: `KitchenMemory Debugging` owns
ordinary developer runs, `KitchenMemory Testing` owns deterministic non-UI
validation, and `KitchenMemory Production` owns production UI smoke tests and
archives. CI-only replacements for those actions should be avoided.

## Workflow policy

### Integration and hardening development

The development workflow starts for meaningful project changes pushed to
`slice/*` integration branches and `bugs/*` hardening branches. It performs
Build, Analyze, and Test actions using the shared
`KitchenMemory Testing` scheme, but does not archive a product. Its actions use
`Testing` and do not include UI automation. Local developer runs use
`KitchenMemory Debugging`, whose Run and Analyze actions use `Develop`.

The completed feature baseline was collected on `slice/completion` before its
merge to `main`. Release engineering begins from that `main` baseline and uses
focused reviewed fixes rather than extending the integration branch as an
indefinite parallel trunk. A future batch of feature slices may establish a new
temporary `slice/*` integration branch.

Build, Analyze, and the non-UI Test action are required to pass. The core
framework coverage gate has reached exact complete line coverage; a failing
logic test or coverage check is a product defect.

### Main production

The `Merge to main` workflow starts for selected project changes merged or
pushed to `main`. It currently contains an iOS Build action for Any iOS Device
and a macOS Build action for Any Mac, both using `KitchenMemory Production`. It
does not contain Test, Analyze, Archive, or post-actions. Signed distribution
archives therefore remain an explicit release-tag operation.

This division is intentional. Test and Analyze are handled by the development
and pull-request workflows under their respective gates; `Merge to main`
verifies that the actual merge result still compiles as a production build on
both platforms without repeating those actions. It is production-build
evidence, not distribution evidence.

### Release tags and notarization

The enabled, restricted-editing `Tag to release/` workflow starts only when a
custom tag name begins with `release/`. A tag must have the exact form
`release/<major>.<minor>.<patch>` and point to a reviewed commit already present
on `main` whose required production evidence has passed. The trigger accepts any
file change and does not auto-cancel an older release build.

The workflow runs an iOS Archive action for Any iOS Device and a macOS Archive
action for Any Mac, both using `KitchenMemory Production`. Both archives select
App Store Connect distribution preparation. The `Notarize - macOS` post-action
is attached specifically to the macOS archive. Creating the tag is a release
operation, not an exploratory build shortcut.

There is no TestFlight post-action or tester-group distribution configured.
App Store Connect preparation makes an archive eligible for later distribution;
it does not by itself publish the build to TestFlight testers. Add that separate
post-action only when the beta path and its groups are ready.

The committed Xcode project remains the source of truth for
`MARKETING_VERSION`, and its `CURRENT_PROJECT_VERSION` remains `1`. Xcode Cloud
assigns and increments the distributed build number without a source edit. The
post-clone contract is read-only: on a release tag, it requires the numeric tag
suffix to match every application configuration's marketing version and confirms
that every source build number is still `1`.

Branch, pull-request, and `main` actions have no associated tag and skip this
release-only check successfully. An Archive action without a release tag fails,
as do malformed or mismatched release tags. CI never needs credentials that can
write version changes back to `main`.

Treat release tags as immutable evidence: never move, reuse, or recreate one for
a different commit. Confirm that the version and build metadata match the tag,
then install and launch the notarized Mac artifact outside Xcode. A successful
workflow without an installation check is incomplete release evidence.

### Change filters

The release-tag workflow accepts any file change because the tag itself is the
deliberate release signal. The other workflows use an all-file exclusion rule:
they do not start when every changed path is one of the root `README.md`,
`LICENSE`, `COPYRIGHT`, `AI.md`, or `.gitignore` files. A commit that also
changes any other path still starts the workflow. This corresponds to Xcode
Cloud's `DO_NOT_START_IF_ALL_FILES_MATCH` rule mode.

This denylist keeps product, project, dependency, test, asset, lint, tooling,
and cloud-script changes covered without maintaining a fragile allowlist.
Update it only for root-level files that cannot affect the product or CI
contract.

### Pull-request gate

The pull-request workflow starts for meaningful project changes in pull requests
from `slice/*` or `bugs/*` into `main`. Its Test action is required to pass,
while tests in the development workflow remain advisory during ordinary work.

Xcode Cloud reports the pull-request result to GitHub. To make the gate prevent
rather than merely warn about a failed merge candidate, `main` requires the
aggregate `KitchenMemory | PR to main from slice/ or bugs/` result from the
Xcode Cloud GitHub App. The production workflow then verifies that the actual
merge result still builds for both supported platforms.

### GitHub enforcement boundary

Xcode Cloud supplies build and action results but does not provide all of the
repository controls required by the release policy. GitHub owns that boundary.

Classic branch protection on `main` requires a pull request, the strict aggregate
Xcode Cloud pull-request result, and resolution of review conversations. It
applies to administrators, blocks force-pushes and deletion, and deliberately
allows merge commits. Zero approving reviews are required while the project has
one release operator; the pull request remains the reviewable unit even when a
second human approval is unavailable.

Three active tag rulesets target `release/*`:

- `Release tag creation` allows only the repository owner to create a matching
  tag.
- `Release tag readiness` has no bypass and requires a successful
  `KitchenMemory | Merge to main` status from the Xcode Cloud GitHub App on the
  target commit.
- `Release tag immutability` has no bypass and prevents every update or deletion
  after creation.

The separate rulesets are intentional: authority to create a release does not
grant authority to move or erase its evidence. The Ruby release contract then
validates the tag and committed version inside Xcode Cloud.

The UI target contains smoke tests only. Localization of durable copy and
formatting proceeds independently, but comprehensive localized-layout assertions,
accessibility audits, and interaction-specific UI suites are deferred until the
relevant interface is stable. See
<doc:0007-business-logic-coverage-and-ui-smoke-tests> and
<doc:accessibility-engineering>. Localization ownership and its non-UI testing
boundary are described in <doc:localization-architecture>.

The `Testing` and `ProductionTesting` configurations deliberately use a minimal
macOS entitlement file. Their application-hosted tests do not enable personal
CloudKit synchronization, and Xcode Cloud's macOS test runner cannot launch a
host application carrying restricted iCloud and push-notification entitlements.
Development and production configurations retain the complete entitlement set;
the testing exception does not alter a shipped application.

The localization contract test reads an exact JSON copy of the raw String
Catalog from its test bundle. A declared test-target build phase embeds that
copy while the source checkout is available. This is necessary because Xcode
Cloud may execute `test-without-building` on a different host that receives the
test products but not the original repository path recorded by `#filePath`.

The committed non-UI test plan collects code coverage. Evaluate the durable domain,
import, persistence, and product-logic sources separately from SwiftUI
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
location, runs the committed non-UI test plan, and invokes the checker only
after Xcode succeeds. The Testing scheme and plan exclude the UI target; the
Production scheme and plan include it.

To check an existing result bundle directly, pass it to:

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
than in this repository. Keep its actions, requirements, branch patterns, tag
prefixes, and change filters aligned with this policy. TestFlight distribution
is intentionally absent for now; archives and notarization are driven only by
the `release/` tag prefix.

The first release-engineering pass uses the production workflow as release
evidence rather than as a ceremonial final build. Its acceptance and
distribution gates are defined in <doc:release-engineering>.

### Current iOS UI-runner diagnostic

With Xcode 26.6 and the iOS 26.5 simulator, Xcode may report internal
`DebuggerVersionStore` / `no debugger version` messages while launching XCUI
tests. Its fallback launcher currently proceeds and the smoke tests execute.
Treat the messages as Apple tooling diagnostics, but treat any assertion reached
inside a test body as an ordinary test failure requiring investigation.

## Static analysis

The Debugging and Testing schemes mark the application as buildable for Analyze. Project build
settings select Xcode's `deep` static-analyzer mode specifically for the Analyze
action. The analyzer does not run during every ordinary build, avoiding a slower
duplicate pass during day-to-day development.

Run the same action locally with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -skipPackagePluginValidation analyze \
  -project KitchenMemory.xcodeproj \
  -scheme 'KitchenMemory Debugging' \
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
slice, or bug work. Strict warning promotion may later be attached explicitly
to the production scheme rather than inherited by every build.

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

The workflows use a shared macOS alias mapped to macOS 26.2, the oldest current
Tahoe release supported by the project. This provides a stable deployment
environment while keeping the selected version centralized in Xcode Cloud.

Treat every environment or alias change as a deliberate migration: run the
Testing and Production schemes locally with that Xcode version, review new
analyzer and linter diagnostics, and then update all applicable workflows.

Custom scripts in `ci_scripts` run for every cloud action. The post-clone script
runs the dependency-free Ruby contract tests and the read-only release check on
every action. Run the same checks locally with:

```sh
ruby Tools/Tests/check_release_version_test.rb
ruby Tools/check-release-version.rb \
  --tag release/0.1.0 \
  --action archive
```

Keep cloud scripts short, deterministic, and limited to environment preparation
so build, test, Analyze, and Archive behavior remains visible in the shared
schemes.
