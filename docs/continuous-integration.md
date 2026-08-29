# Continuous integration

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

Xcode Cloud is Kitchen Memory's continuous-integration system. The repository
checks in the default `KitchenMemoryIOS` and `KitchenMemoryMacOS` schemes and
their platform plans so local and cloud Test actions select the same hosted and
UI-smoke targets. It also checks in a minimal `KitchenKit` scheme because an
unhosted framework test target needs an explicit scheme association; only that
scheme continues to use an automatically created plan.

## Scheme, plan, and destination contract

| Scheme and plan | Primary target | Native destination |
| --- | --- | --- |
| `KitchenKit` with automatic plan | `KitchenKit` and `KitchenKitTests` | native macOS for canonical coverage; iOS as needed |
| `KitchenMemoryIOS` with `KitchenMemoryIOS.xctestplan` | iOS app, hosted tests, and shared UI smoke | iOS device or Simulator |
| `KitchenMemoryMacOS` with `KitchenMemoryMacOS.xctestplan` | macOS app, hosted tests, and shared UI smoke | native macOS |

Each saved platform scheme has one top-level app buildable; Xcode adds
KitchenKit through ordinary dependency resolution. Its saved plan adds the
native hosted-test target and the shared UI-smoke target. The shared KitchenKit
scheme exists only to associate its one unhosted test bundle, and Xcode derives
that plan automatically. The platform schemes default Test and Analyze to
`Testing`; Xcode Cloud may still select a configuration and destination
explicitly without introducing duplicate scheme names.

The iOS schemes do not expose Mac Catalyst, Mac Designed for iPhone or iPad, or
visionOS Designed for iPhone or iPad destinations. The macOS schemes expose
native Mac destinations only. Compatibility products require an explicit target
and acceptance decision; they are not incidental CI coverage.

## Workflow policy

### Integration and hardening development

The development workflow starts for meaningful project changes pushed to
`slice/*` integration branches, `bugs/*` hardening branches, and
`release-eng/*` release-infrastructure branches. All three governed lanes
perform Build, Analyze, and Test actions using `KitchenMemoryIOS`,
`KitchenMemoryMacOS`, and the macOS-destination `KitchenKit` lane, but never
archive a product. Those actions use `Testing`; each platform Test action runs
its hosted correctness target and the bounded shared UI smoke suite. Local
developer runs use the
corresponding platform scheme with the `Develop` configuration. The distinct
development bundle identifier keeps local stores,
CloudKit metadata, and onboarding preferences out of the Production app
sandbox. Its separate
CloudKit container also keeps development records and schema administration
away from production service state.

The completed feature baseline was collected on `slice/completion` before its
merge to `main`. Release engineering begins from that `main` baseline and uses
focused reviewed fixes rather than extending the integration branch as an
indefinite parallel trunk. A future batch of feature slices may establish a new
temporary `slice/*` integration branch.

`release-eng/*` owns repeatable release plumbing and its directly supporting
hardening: CI contracts, dependency inventory, SBOM maintenance, version and tag
validation, packaging, signing, notarization, and distribution automation. It
is not a second feature lane. User-visible defects remain `bugs/*`, while new
product capability remains `slice/*`.

Build, Analyze, and the complete platform Test actions are required to pass.
The KitchenKit coverage gate has reached exact complete line coverage; a
failing logic test or coverage check is a product defect.

### Main production

The `Merge to main` workflow starts for selected project changes merged or
pushed to `main`. It currently contains an iOS Build action for Any iOS Device
using `KitchenMemoryIOS` and a macOS Build action for Any Mac using
`KitchenMemoryMacOS`, both with `Production`. It does not contain Test, Analyze,
Archive, or post-actions. Signed distribution archives therefore remain an
explicit release-tag operation.

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
action for Any Mac, using the corresponding platform scheme with the
`Production` configuration. Both
archives select App Store Connect distribution preparation. The
`Notarize - macOS` post-action is attached specifically to the macOS archive.
Creating the tag is a release operation, not an exploratory build shortcut.

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

After the 0.1.0 public alpha, each product slice commits its next semantic
`MARKETING_VERSION` when the slice begins. This makes every accepted slice a
distinct potential release while preserving the source build-number seed at
`1`. Ordinary untagged Build, Analyze, and Test actions accept the new version;
Archive still requires an immutable matching `release/<major>.<minor>.<patch>`
tag.

Advancing a working version does not require publishing it. Patch versions may
represent either focused bug fixes or coherent feature work smaller than the
next minor release, and development may move past an accepted version without
creating a tag or artifact. `RELEASE` changes only for a version deliberately
selected for distribution.

The root `RELEASE` file is the build-visible release marker. During development
it records the last submitted version. A final release commit advances the file
to the current marketing version and receives the matching annotated tag before
the commit and tag are submitted together. Tagged Archive actions reject any
disagreement among `RELEASE`, `MARKETING_VERSION`, and the tag. Do not add this
file to Xcode Cloud's documentation-only path exclusions: its change is the
source event that lets the tag start a fresh Archive workflow.

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
from `slice/*`, `bugs/*`, or `release-eng/*` into `main`. Its Test action is
required to pass, while tests in the development workflow remain advisory during
ordinary work.

The repository-owned `PR source policy` GitHub Actions check runs for every
pull request into `main`, including source branches that Xcode Cloud deliberately
does not accept. It succeeds only for `slice/*`, `bugs/*`, and `release-eng/*`;
an ineligible branch receives an immediate naming failure instead of silently
waiting for a Cloud workflow that cannot start. The workflow checks only pull-
request metadata, does not check out or execute proposed source, and has read-
only repository permission.

GitHub applies required status checks to the protected target branch rather
than conditionally interpreting the pull request's source name. Consequently,
an ineligible pull request may still display the Xcode Cloud result as expected
until it is renamed or closed. Do not weaken the required check's Xcode Cloud
GitHub App binding or fabricate its status to hide that platform limitation.

Xcode Cloud reports the pull-request result to GitHub. To make the gate prevent
rather than merely warn about a failed merge candidate, `main` requires the
aggregate `KitchenMemory | PR to main from governed branches` result from the
Xcode Cloud GitHub App. The production workflow then verifies that the actual
merge result still builds for both supported platforms. After renaming the
Cloud workflow, GitHub must observe that exact result at least once before it
can replace the former required check in branch protection.

### GitHub enforcement boundary

Xcode Cloud supplies build and action results but does not provide all of the
repository controls required by the release policy. GitHub owns that boundary.

Classic branch protection on `main` requires a pull request, the repository's
`PR source policy` check, the strict aggregate Xcode Cloud pull-request result,
and resolution of review conversations. The two required checks have distinct
trusted sources: GitHub Actions owns branch eligibility, and the Xcode Cloud
GitHub App owns build and test acceptance. Protection applies to administrators,
blocks force-pushes and deletion, and deliberately allows merge commits. Zero
approving reviews are required while the project has one release operator; the
pull request remains the reviewable unit even when a second human approval is
unavailable.

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
[ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md) and
[accessibility engineering](accessibility-engineering.md). Localization
ownership and its non-UI testing boundary are described in
[localization architecture](localization-architecture.md).

The `Testing` and `ProductionTesting` configurations deliberately use minimal
platform-specific entitlement files. Their application-hosted tests do not
carry personal CloudKit or push-notification capabilities. This is least
privilege on iOS and is also required because Xcode Cloud's macOS test runner
cannot launch a host application carrying those restricted entitlements.
Development and production configurations retain the complete entitlement set;
the testing exception does not alter a shipped application.

Application-hosted XCTest processes also select an in-memory store in those two
testing configurations by detecting Xcode's hosted-test environment. This keeps
the saved platform plans disposable without relying on a plan-level launch
argument. UI smoke tests pass their own harness argument and use the same
disposable `Testing` host by default. Ordinary development and production
launches continue to use durable storage; `ProductionTesting` remains available
for an explicitly selected release-optimized smoke run.

UI smoke launches also ignore persisted application-window restoration state.
On macOS, XCUITest can nevertheless relaunch a live `WindowGroup` application
without creating its primary window. The smoke harness detects the missing
expected surface and invokes the public Command-N New Window path before making
assertions. This keeps launches deterministic without depending on localized
menu copy or altering ordinary application behavior.

The localization contract test reads an exact JSON copy of the raw String
Catalog from its test bundle. A declared test-target build phase embeds that
copy while the source checkout is available. This is necessary because Xcode
Cloud may execute `test-without-building` on a different host that receives the
test products but not the original repository path recorded by `#filePath`.

The KitchenKit lane enables code coverage explicitly; the two automatic
app-hosted plans do not. All three lanes are correctness gates. Evaluate durable
domain, import, persistence, and product-logic sources separately from SwiftUI
views and test bundles; an app-wide percentage is not the business-logic
metric. Use uncovered executable lines to find missing behavior and boundary
tests, not to justify exercising provisional views through UI automation.

### KitchenKit coverage gate

Generate a fresh coverage bundle from the complete standalone KitchenKit suite
and apply the gate in the same run:

```sh
Tools/run-core-framework-coverage.sh
```

The runner creates a unique evidence directory under `/private/tmp`, prints its
location, runs the shared `KitchenKit` scheme and its automatic plan with
explicit code coverage, and invokes the checker only after Xcode succeeds. This
macOS result is the canonical exact line-coverage artifact for KitchenKit. It
does not replace either app correctness lane or the separately selected UI
smoke target.

To check an existing result bundle directly, pass it to:

```sh
Tools/check-core-framework-coverage.sh /path/to/Tests.xcresult
```

The script reads Xcode's integer covered and executable line counts rather than
its rounded percentage. It prints evidence for KitchenKit and fails when the
target or current source is missing, when even one executable line is uncovered,
or when source, tests, project membership, or resolved dependencies changed
after the bundle's recorded build start.

### Deterministic property-test corpora

Property tests load named entropy seeds from
`KitchenKitTests/Support/PropertyTestSeeds.json`. Failure messages record
the seed and case number so a generated input can be replayed exactly. The test
harness verifies catalog integrity, proves that changed seeds produce different
raw and derived corpora, and pins a known-answer vector so an accidental generator
rewrite cannot silently change the meaning of an existing seed/case pair.

Xcode Cloud workflow metadata and start conditions live in Xcode Cloud rather
than in this repository. Keep its actions, requirements, branch patterns, tag
prefixes, and change filters aligned with this policy. TestFlight distribution
is intentionally absent for now; the normal archive and notarization workflow
is driven only by the `release/` tag prefix.

### 0.1 tag synchronization exception

GitHub accepted the immutable annotated `release/0.1.0` tag and reported that it
peeled to accepted merge commit `98038e9`, whose iOS and macOS `Merge to main`
actions were green. Xcode Cloud nevertheless did not import the tag, list it as
an available manual source, or start `Tag to release/`. The workflow remained
active and correctly configured for tags beginning with `release/`.

The tag was not moved, deleted, or recreated to replay the external event. The
0.1 public alpha instead used a local Developer ID macOS archive from the same
accepted source, followed by notarization, stapling, post-ZIP verification, and
outside-Xcode acceptance. This is a recorded service-side exception, not the
new default release path.

Before relying on the next release tag, confirm that Xcode Cloud can import a
harmless newly pushed tag. If automatic synchronization remains unavailable,
approve a manual-start mechanism that still selects the immutable release tag
and preserves the version contract; do not broaden the archive workflow to
ordinary `main` commits merely to work around a missing tag event.

The first release-engineering pass used the production workflow as release
evidence rather than as a ceremonial final build. Its acceptance and
distribution gates are defined in [release engineering](release-engineering.md).

### Current UI-runner diagnostic

With Xcode 26.6, both the iOS 26.5 simulator and macOS 26.6.2 may report internal
`DebuggerVersionStore` / `no debugger version` messages while launching XCUI
tests. The fallback launcher currently proceeds and the smoke tests execute.
Treat the messages as Apple tooling diagnostics, but treat any assertion reached
inside a test body as an ordinary test failure requiring investigation.

## Static analysis

The saved application schemes use `Testing` for Analyze. Project build
settings select Xcode's `deep` static-analyzer mode specifically for the Analyze
action, while the invocation selects the desired configuration. The analyzer
does not run during every ordinary build, avoiding a slower duplicate pass
during day-to-day development.

Run the same action locally with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -skipPackagePluginValidation analyze \
  -project KitchenMemory.xcodeproj \
  -scheme KitchenMemoryMacOS \
  -configuration Develop \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/KitchenMemoryAnalyze \
  CODE_SIGNING_ALLOWED=NO
```

## SwiftLint

SwiftLint is a pinned Swift package build-tool plugin attached to the applications,
KitchenKit, and test targets. Consequently, linting runs for the source
files Xcode is already building, both locally and in Xcode Cloud. There is no
separate cloud lint installation or script.

The root `.swiftlint.yml` is the development policy: violations retain their
configured severities instead of being promoted globally. File length warns
above 400 lines and becomes an error above 1,000 lines. The goal remains a
warning-free tree, but an ordinary maintenance warning does not block local,
slice, or bug work. Strict warning promotion may later be attached explicitly
to the `Production` configuration rather than inherited by every build.

The opt-in rules are deliberately limited to product safety and lifecycle
mistakes, collection correctness and avoidable work, SwiftUI accessibility
contracts, and test quality. Formatting preferences that would create broad
mechanical churn are not CI policy.

When adding an opt-in rule:

1. audit it across both applications, KitchenKit, both application-test
   targets, and the shared UI-test target;
2. confirm that its findings represent defects or an agreed maintenance cost;
3. bring the current tree to zero violations before making it required; and
4. avoid a baseline unless an incremental migration has been explicitly chosen.

Xcode Cloud's noninteractive environment cannot approve package-plugin
fingerprints. The executable `ci_scripts/ci_post_clone.sh` enables Xcode's
package-plugin fingerprint bypass before each action. This is acceptable only
because `Package.resolved` pins the SwiftLint plugin revision; dependency updates
must be reviewed like source changes.

## Maintenance

The workflows use a shared macOS alias mapped to the latest available macOS
release. During early alpha, the project prefers the current Xcode Cloud test
host over carrying application workarounds for a Swift 6.2 XCTest runtime defect
on macOS 26.2, tracked as
[swiftlang/swift#87316](https://github.com/swiftlang/swift/issues/87316). This is
a CI test-environment choice and does not change the application's deployment
target. Reconsider an additional oldest-supported compatibility lane before an
external beta when failures can inform supported-user risk rather than block
early development on a fixed platform defect.

Treat every environment or alias change as a deliberate migration: run the
Testing and Production configurations locally with that Xcode version, review new
analyzer and linter diagnostics, and then update all applicable workflows.

Custom scripts in `ci_scripts` run for every cloud action. The post-clone script
runs the dependency-free Ruby contract tests, validates the live target/scheme/
plan structure, and performs the read-only release check on every action. Run
the same checks locally with:

```sh
ruby Tools/Tests/check_release_version_test.rb
ruby Tools/Tests/check_project_structure_test.rb
ruby Tools/Tests/check_software_inventory_test.rb
ruby Tools/check-project-structure.rb
ruby Tools/check-software-inventory.rb
ruby Tools/check-release-version.rb
```

The untagged command is the ordinary development check. Before submitting a
release, rerun it with `--tag release/<version> --action archive` after the
project marketing version and root `RELEASE` marker have both been advanced to
that same version.

The structure contract also pins each project configuration to its matching
xcconfig and automatic merged-binary mode; the development and production
bundle namespaces; platform plist, entitlement, and synchronized-folder
ownership; the three shared schemes and two platform plans; and KitchenKit's
automatic-plan policy. It also requires each localization-catalog embedding
phase to run first in its hosted-test target, preventing a dependency cycle
between that test-bundle output and KitchenKit re-export signing. Treat a
contract failure as a reviewable project change, not as a reason to weaken the
checker until the project happens to pass.

Keep cloud scripts short, deterministic, and limited to environment preparation
so build, test, Analyze, and Archive behavior remains visible in Xcode's schemes.
