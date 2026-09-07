# Continuous integration

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Xcode Cloud is Kitchen Memory's continuous-integration system. Local Xcode
uses the full `KitchenMemory` test plan. Cloud Test actions explicitly select
`KitchenMemoryCloud`, which runs hosted correctness tests while UI testing is
temporarily suspended. The `KitchenKit` scheme and plan retain unhosted framework
coverage.

## Scheme, plan, and destination contract

| Scheme and plan | Scheme build product | Plan test targets | Native destination |
| --- | --- | --- | --- |
| `KitchenKit` with `KitchenKit.xctestplan` | `KitchenKit` | `KitchenKitTests` | native macOS for canonical coverage; iOS as needed |
| `KitchenMemory` with `KitchenMemoryCloud.xctestplan` | `KitchenMemory` | `KitchenMemoryTests` | Cloud iOS or native macOS |
| `KitchenMemory` with `KitchenMemory.xctestplan` | `KitchenMemory` | `KitchenMemoryTests`, `KitchenMemoryUITests` | iOS device, Simulator, or native macOS |

Each shared scheme has one top-level product buildable; Xcode adds dependencies
through ordinary resolution. Its selected plan is the sole owner of test-target
membership: `KitchenKit.xctestplan` contains the unhosted framework target,
while the default local application plan includes hosted and UI tests, and the
Cloud application plan includes hosted tests only. The schemes default Test and Analyze to `Testing`; Xcode Cloud
may still select a configuration and destination explicitly without introducing
duplicate scheme names.

The hosted `KitchenMemoryTests` target remains parallelizable. The
`KitchenMemoryUITests` target is deliberately serial: its methods share one
application lifecycle, and native macOS runners cannot safely foreground that
application while another UI runner or retained hosted-test process owns it.
The UI launch harness terminates a retained macOS host before applying the
disposable UI-testing launch plan. The project-structure contract enforces this
parallel-hosted, serial-UI boundary.

The application scheme does not expose Mac Catalyst, Mac Designed for iPhone
or iPad, or visionOS Designed for iPhone or iPad destinations. Compatibility
products require an explicit target and acceptance decision; they are not
incidental CI coverage.

Xcode Cloud workflow metadata lives outside this repository. Inspect live
actions when changing CI; checked-in schemes and plans do not configure those
actions automatically.

## Workflow policy

### Integration and hardening development

The development workflow starts for meaningful project changes pushed to
`slice/*` integration branches, `bugs/*` hardening branches, and
`release-eng/*` release-infrastructure branches. Development currently performs separate iOS and macOS Build and Analyze actions
with the `KitchenMemory` scheme and `Testing`. The pull-request workflow supplies
hosted correctness Test actions using `KitchenMemoryCloud` on both destinations.
The standalone KitchenKit coverage runner and full native local application plan
supply the remaining required evidence; they are not additional Cloud Test
lanes. Local UI navigation remains required when applicable while Cloud UI
testing is paused. Local
developer runs use the
same application scheme with the `Develop` configuration. The distinct
development bundle identifier keeps local stores,
CloudKit metadata, and onboarding preferences out of the Production app
sandbox. Its separate
CloudKit container also keeps development records and schema administration
away from production service state.

Start a release-engineering pass from accepted `main`. A batch of feature
slices may use a short-lived `slice/*` integration branch; focused `codex/*`
working branches feed the appropriate governed lane.

`release-eng/*` owns repeatable release plumbing and its directly supporting
hardening: CI contracts, dependency inventory, SBOM maintenance, version and tag
validation, packaging, signing, notarization, and distribution automation. It
is not a second feature lane. User-visible defects remain `bugs/*`, while new
product capability remains `slice/*`.

Published `slice/*`, `bugs/*`, and `release-eng/*` branches are governed
integration lanes. GitHub automatically deletes their remote branches after
merge. The merge commit, pull request, and protected `main` history preserve
the accepted integration and its evidence; keeping a branch name is unnecessary.
Local integration branches, working branches such as `codex/*`, and completed
worktrees are short-lived working state. Clean them up only after verifying
their work on `main` and the required merge evidence, as described in
[branch cleanup](#branch-cleanup).

Build, Analyze, and the complete platform Test actions are required to pass.
The KitchenKit coverage gate has reached exact complete line coverage; a
failing logic test or coverage check is a product defect.

### Branch cleanup

Cleanup follows acceptance and integration; it does not substitute for either.
Confirm that the intended pull request is merged into `main`, its required
pull-request checks passed, and the applicable iOS and macOS `Merge to main`
Production Build actions succeeded for the actual merge commit. If the workflow
did not start because of the documented [change filters](#change-filters),
verify and record that the exact merged diff qualifies for that exclusion;
an unexplained missing run is not an exemption. A deleted remote branch or a
green result from another commit is not proof of the required state.

Inspect local state before switching branches or removing anything:

```sh
git status --short --branch
git worktree list
git branch -vv
gh pr view <number> --json state,baseRefName,headRefName,mergeCommit,url
```

Run the following from the checkout that will keep `main`. If `main` is already
checked out in another worktree, use that checkout. Preserve any uncommitted
work and stop if switching or fast-forwarding fails; do not reset the checkout
to make cleanup succeed.

```sh
git fetch origin --prune
git switch main
git merge --ff-only origin/main
git branch --merged main
```

Pruning removes stale remote-tracking references, not local branches. Verify
that the pull request's merge commit is an ancestor of this updated `main`.
For each explicitly identified completed branch, require that its tip is also
an ancestor of `main` (and appears in `git branch --merged main`). A working
branch merged only into an unaccepted slice is not ready for local cleanup.

For a completed linked worktree, inspect its status, including untracked files,
and confirm its branch or detached HEAD is contained in `main`. Check for
ignored local artifacts that need preserving as well. Remove only that clean,
inactive worktree, from another checkout, before deleting its branch:

```sh
git -C <completed-worktree-path> status --short --untracked-files=all --ignored
git worktree remove <completed-worktree-path>
git branch -d <verified-completed-branch>
```

The paths, branch names, and pull-request number above are placeholders for
the specific work being cleaned up. The merged-branch list is evidence to
inspect, not a bulk deletion list. Leave active, unmerged, unrelated, dirty,
locked, or ambiguous worktrees and branches alone. Never add `--force`, use
`git branch -D`, or use `git reset --hard` or `git clean` to bypass a refusal.
If a squash or rebase means ancestry cannot prove containment, preserve the
branch for explicit reconciliation rather than treating a merged PR as enough.

This lifecycle preserves branch naming, pull-request gates, protected-main
rules, and immutable release tags. It does not authorize deleting release tags
or rewriting historical evidence.

### Main production

The `Merge to main` workflow starts for selected project changes merged or
pushed to `main`. It currently contains an iOS Build action for Any iOS Device
and a macOS Build action for Any Mac, both using `KitchenMemory` with
`Production`. It does not contain Test, Analyze,
Archive, or post-actions. Signed distribution archives therefore remain an
explicit release-tag operation.

This division is intentional. Test and Analyze are handled by the development
and pull-request workflows under their respective gates; `Merge to main`
verifies that the actual merge result still compiles as a production build on
both platforms without repeating those actions. It is production-build
evidence, not distribution evidence.

### Release tags and notarization

[Release engineering](release-engineering.md) owns the version/`RELEASE`/tag
contract, candidate gates, Archive and notarization actions, immutable evidence,
and distribution procedure. `Tag to release/` uses the native application
scheme with `Production` on both platforms, accepts any file change, and does
not auto-cancel an older release build. Creating its tag is an intentional
release operation.

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
from `slice/*`, `bugs/*`, or `release-eng/*` into `main`. Both hosted Test actions are required by project policy before merge;
Development supplies Build and Analyze, not a duplicate Test action.

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
until it is renamed or closed. Preserve the required Cloud check's Xcode Cloud
GitHub App binding when maintaining the rule. Never fabricate its status to hide that platform
limitation.

Xcode Cloud reports the aggregate `KitchenMemory | PR to main from governed
branches` result. It is required for PRs; inspect the actual candidate result
before merge.

### GitHub enforcement boundary

Xcode Cloud supplies build and action results but does not provide all of the
repository controls required by the release policy. GitHub owns that boundary.

As inspected on 2026-09-07, classic protection on `main` requires a pull request,
the GitHub Actions-owned `PR source policy` check, the Xcode Cloud-owned
`KitchenMemory | PR to main from governed branches` aggregate, an up-to-date
branch, and resolved review conversations. It applies to administrators, blocks force-push
and deletion, allows merge commits, and requires zero approving reviews while
there is one release operator.

The maintainer restored the Cloud PR requirement on 2026-09-07 after the hosted
Cloud lanes became reliable with UI testing suspended. The earlier exception
allowed progress during repeated Cloud UI runner failures; it did not waive the
local semantic tests or the obligation to inspect real Cloud results.

The PR rule should require exactly `PR source policy` from GitHub Actions and
`KitchenMemory | PR to main from governed branches` from the Xcode Cloud GitHub
App, with strict/up-to-date mode enabled. `KitchenMemory | Development Workflow`
is a separate branch workflow, and `KitchenMemory | Merge to main` runs after
merge. Requiring that post-merge status on a PR creates a circular gate. Its
release-tag requirement below remains separate. Do not fabricate a status or
weaken its trusted-source binding to hide a missing run.

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

## Native test boundary

The UI target contains only accessible top-level structure and navigation
checks. It does not re-prove feature workflows or standard control activation.
Localization of durable copy and formatting proceeds independently, while
comprehensive localized-layout assertions, accessibility audits, focus and
grouping checks, and interaction-specific UI suites are deferred until the
comprehensive UI design pass and per-workflow stabilization required for beta.
The accepted alpha/beta gates and alternate evidence for tooling failures are
defined in ADR 0019. See
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

### Cloud UI testing

Cloud UI testing is temporarily suspended on both native platforms following
macOS foreground-activation failures (issue #155). Configure every application
Test action in Cloud to use **Specific Test Plans > KitchenMemoryCloud**. Keep
`KitchenMemory` as the local default; its bounded UI suite remains enabled. A green Cloud run does not replace local UI validation. The speculative
activation delegate and diagnostic probes have been removed.

To restore Cloud UI coverage after the platform issue is resolved, select the
full `KitchenMemory` plan in those Cloud actions and verify repeated passes on
macOS and iOS. Track the upstream investigation separately from this temporary
mitigation; see [the activation research](research/macos-cloud-ui-test-activation.md).

Application-hosted XCTest processes also select an in-memory store in those two
testing configurations by detecting Xcode's hosted-test environment. This keeps
the saved application plan disposable without relying on a plan-level launch
argument. UI navigation tests pass their own harness argument and use the same
disposable `Testing` host by default. Ordinary development and production
launches continue to use durable storage; `ProductionTesting` remains available
for an explicitly selected release-optimized smoke run.

UI navigation launches also ignore persisted application-window restoration state.
On macOS, XCUITest can nevertheless relaunch a live `WindowGroup` application
without creating its primary window. The navigation harness detects the missing
expected surface and invokes the public Command-N New Window path before making
assertions. This keeps launches deterministic without depending on localized
menu copy or altering ordinary application behavior.

The localization contract test reads an exact JSON copy of the raw String
Catalog from its test bundle. A declared test-target build phase embeds that
copy while the source checkout is available. This is necessary because Xcode
Cloud may execute `test-without-building` on a different host that receives the
test products but not the original repository path recorded by `#filePath`.

The KitchenKit lane enables code coverage explicitly; the two app-hosted plans
do not. Framework and both native application runs are correctness gates. Evaluate durable
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
location, runs the shared `KitchenKit` scheme and its explicit plan with
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

### Current UI-runner diagnostic

With Xcode 26.6, both the iOS 26.5 simulator and macOS 26.6.2 may report internal
`DebuggerVersionStore` / `no debugger version` messages while launching XCUI
tests. The fallback launcher currently proceeds and the smoke tests execute.
Treat the messages as Apple tooling diagnostics, but treat any assertion reached
inside a test body as an ordinary test failure requiring investigation.

## Repository contracts

`ci_scripts/ci_post_clone.sh` runs the dependency-free Ruby checker tests and
validates project structure, localization, software inventory, release versions,
and [documentation](documentation-maintenance.md) before package/plugin code.
For the documentation gate locally:

```sh
ruby Tools/Tests/check_documentation_test.rb
ruby Tools/check-documentation.rb
```

The existing project checker owns target, source taxonomy, scheme/plan, resource,
plist, and entitlement invariants. The documentation checker connects navigable
current guidance to those same source inputs; historical records are exempt
from current-topology assertions, not from local-link checks.

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
  -scheme KitchenMemory \
  -configuration Testing \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/KitchenMemoryAnalyze \
  CODE_SIGNING_ALLOWED=NO
```

## SwiftLint

SwiftLint is a pinned Swift package build-tool plugin attached to the application,
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

1. audit it across the application, KitchenKit, the hosted application-test
   target, and the shared UI-test target;
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
ruby Tools/Tests/check_localization_test.rb
ruby Tools/Tests/check_documentation_test.rb
ruby Tools/check-documentation.rb
ruby Tools/check-localization.rb
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
ownership; the shared schemes and explicit plans listed above; and exclusive
plan ownership of test-target membership. It also requires each
localization-catalog embedding phase to run first in its hosted-test target,
preventing a dependency cycle between that test-bundle output and KitchenKit
re-export signing. Treat a contract failure as a reviewable project change, not
as a reason to weaken the checker until the project happens to pass.

Keep cloud scripts short, deterministic, and limited to environment preparation
so build, test, Analyze, and Archive behavior remains visible in Xcode's schemes.
