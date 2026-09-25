# Continuous integration

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

GitHub Actions owns daily build, analysis, coverage, and native test checks.
Xcode Cloud remains the release-engineering and beta-testing service. The
application requires macOS 27.0 and iOS 27.0 or newer; the current toolchain is
Xcode 27.

**Release boundary (2026-09-24):** GitHub owns review-ready development validation.
Xcode Cloud is reserved for deliberate release candidates: optimized tests and
Production archives on both platforms. Ordinary main and release-eng pushes do
not need a second Cloud validation environment. The 0.3.3 candidate (Cloud build 481) archived successfully but failed required
production tests; it was not published. Historical build 429 proves collector
compatibility only.

## Scheme, plan, and destination contract

| Scheme and plan | Scheme build product | Plan test targets | Native destination |
| --- | --- | --- | --- |
| `KitchenKit` with `KitchenKit.xctestplan` | `KitchenKit` | `KitchenKitTests` | native macOS for canonical coverage; iOS as needed |
| `KitchenMemory Release` with `KitchenMemoryCloud.xctestplan` | `KitchenMemory` | `KitchenKitTests`, `KitchenMemoryTests`, `KitchenMemoryUITests` | Cloud iOS or native macOS, `ProductionTesting` |
| `KitchenMemory` with `KitchenMemory.xctestplan` | `KitchenMemory` | `KitchenMemoryTests`, `KitchenMemoryUITests` | iOS device, Simulator, or native macOS |

Each shared scheme has one top-level product buildable; Xcode adds dependencies
through ordinary resolution. Its selected plan is the sole owner of test-target
membership: `KitchenKit.xctestplan` contains the unhosted framework target,
while the default local application plan includes hosted and UI tests, and the
Cloud release plan includes framework, hosted, and serial UI tests. Development
schemes use `Testing`; `KitchenMemory Release` uses `ProductionTesting` for Test
and `Production` for Archive. This explicit release scheme preserves ordinary
local test settings while exercising optimized code in Cloud.

`KitchenMemoryTests` resolves KitchenKit through its application bundle loader.
Do not add KitchenKit to that hosted target's Link Binary With Libraries phase:
this keeps the host responsible for the shared framework. Under the former
automatic-merging configuration, a second link caused duplicate runtime types
and failed optimized type checks. The unhosted
`KitchenKitTests` target still links KitchenKit directly.

Only the disposable `ProductionTesting` app disables hardened runtime, following
[Apple's macOS Cloud test-runner workaround](https://developer.apple.com/xcode-cloud/release-notes/)
(Feedback 11302291). Cloud can re-sign the injected test bundle with a different
team from its host. `Production` archives retain hardened runtime, signing,
and production entitlements; the artifact collector still verifies them.

The hosted `KitchenMemoryTests` and `KitchenMemoryUITests` targets run serially
in both application plans. Hosted tests exercise real native windows, first
responders, paste delivery, and undo managers; they are not independent of an
application lifecycle. This also isolates the intermittent iOS native-paste
failure observed under parallel CI execution. Serialization is a controlled
mitigation, not yet proof of that failure's cause. The unhosted `KitchenKitTests`
target remains parallelizable. The UI launch harness terminates a retained macOS
host before applying the disposable UI-testing launch plan. The project-structure
contract enforces parallel framework tests and serial application tests.

The application scheme does not expose Mac Catalyst, Mac Designed for iPhone
or iPad, or visionOS Designed for iPhone or iPad destinations. Compatibility
products require an explicit target and acceptance decision; they are not
incidental CI coverage.

Xcode Cloud workflow metadata lives outside this repository. Inspect live
actions when changing CI; checked-in schemes and plans do not configure those
actions automatically.

## Workflow policy

### Integration and hardening development

`.github/workflows/development.yml` handles PRs against any stack base, merge
queues, main pushes, and manual dispatch. Draft PRs receive fast repository
checks. Review-ready source/base changes require full validation. Native lanes
reuse evidence only for an identical Git tree under the same policy within seven
days, from a successful same-repository Development CI run and its current run
attempt. Missing, expired, incompatible, or unreadable evidence runs the full
suite. Manual dispatch always forces full validation.

`Tools/ci-evidence.rb` records the actual checked-out candidate tree after every
full run. The accepted merge can therefore verify the exact tree without another
native suite. Different merge-queue combinations still require validation.
An edited PR event covers stack retargeting. The required `Development CI` check
keeps the same name for every event. Ready PR description/title edits must reuse
successful evidence for the exact tree or run full validation; a cheap metadata
check cannot authorize merging. Their separate concurrency group prevents them
from cancelling a candidate run. An edit before evidence is available can start
another full run. Draft checks never produce full-validation evidence.

The independent lanes are:

- Repository contracts: dependency-free Ruby tooling tests, project structure,
  localization, documentation, software inventory, and release-version checks.
- macOS and iOS `Production` builds, without distribution signing or Archive.
- Optional macOS/iOS Clang analysis through manual dispatch with `analyze: true`;
  use it for relevant C-family/dependency or analysis-setting changes.
- KitchenKit: standalone macOS correctness tests, exact complete line coverage,
  and ordinary-consumer public interface checks.
- iOS application tests: full `KitchenMemory` plan on an available iPhone
  simulator at iOS 27.0 or newer.
- Signed macOS application tests: full `KitchenMemory` plan, including serial
  UI navigation checks, with a dedicated development identity.

`Development CI` requires repository checks plus either every native lane's
success or verified reusable full evidence. Only draft PRs use the fast path;
a draft must become review-ready and satisfy validation before merging. A skipped
signing lane, failure, or cancellation cannot pass a full run. Diagnostics and
validation evidence are retained for seven days.

The workflow uses GitHub's `xcode-27` hosted image and explicitly selects
`/Applications/Xcode_27.0.app`. The simulator is discovered from the installed
runtimes, not pinned to a device UUID or model name. Package versions come from
`Package.resolved`; each build job checks the reviewed software inventory
before allowing the pinned build-tool plugin to execute.

`Tools/ci.rb` owns the command orchestration, while shared schemes and plans
own configuration and test membership. Local native tests continue to use
[Xcode's Test action](agents/xcode.md). The hosted driver refuses ordinary local
invocation so it cannot silently replace that signing workflow.

Keep feature work in `slice/*`, hardening in `bugs/*`, and release infrastructure
in `release-eng/*`. Focused `codex/*` working branches can feed those lanes.
Stacked PRs receive CI before their base lands. The existing `PR source policy`
check applies when the final integration PR targets `main`.

Local `Develop` builds retain the separate development bundle identifier and
CloudKit container. Testing hosts use disposable state; Production retains the
shipping entitlement set. This migration changes no persisted schema, user
store, release version, or CloudKit service configuration.

### Signing setup

As of 2026-09-24, both secrets are configured in KitchenMemory's `ci-signing`
environment using Folio's dedicated CI development certificate, as authorized
by the maintainer. The identity is shared for now; separate it if project
ownership or organization boundaries later require that separation.

Create the `ci-signing` GitHub environment with `CI_CERTIFICATE_P12_BASE64` and
`CI_CERTIFICATE_PASSWORD`, containing a dedicated Apple Development identity
for the project's team. Do not use a distribution identity. The helper imports
it only into a temporary keychain on a disposable GitHub-hosted runner, restores
the original keychain search list, and removes it even after failure.

Fork pull requests never receive this identity. Their unsigned checks can run,
but the aggregate remains red until a maintainer reviews the change and runs it
from an in-repository branch. No `pull_request_target` execution is used.

### Branch cleanup

Cleanup follows acceptance and integration; it does not substitute for either.
Confirm that the intended pull request is merged into `main`, its required
pull-request checks passed, and the GitHub `Development CI` push run succeeded for the actual merge commit.
During cutover, also preserve any still-required Cloud merge evidence. A PR
result is not proof of the post-merge result. A deleted remote branch or a
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

The push-to-`main` GitHub run verifies evidence for the actual merged tree. It
runs Production builds and native tests only if reusable evidence is absent.
It does not archive, notarize, upload, or distribute an app.

### Release tags and notarization

[Release engineering](release-engineering.md) owns the version/`RELEASE`/tag
contract, tiered release checks, Archive, signing, notarization, and distribution.
Keep Xcode Cloud's `Tag to release/` workflow and its immutable release evidence.
Xcode Cloud also remains the place for beta-testing workflows; do not infer a
new TestFlight distribution group, audience, or automatic upload from the daily
CI migration.

### Change filters

Daily GitHub checks have no path filter. Release tags accept every file change
because the immutable tag is the deliberate release signal.

### Pull-request gate

Require `PR source policy` and GitHub Actions' `Development CI` on `main` after
cutover. The aggregate has the same name for PR and merge-group runs. Source
policy continues to enforce governed branch names only for PRs into `main`;
stacked PRs to other bases receive the development checks without that final
integration restriction.

### GitHub enforcement boundary

The live cutover on 2026-09-24 replaced the Cloud PR requirement with
`Development CI`, bound to GitHub Actions (app 15368), alongside `PR source
policy`. Strict mode, required PRs, resolved conversations, administrator
enforcement, and force-push/deletion restrictions remain unchanged.

`Release tag readiness` requires GitHub's `Development CI` (integration 15368),
with no bypass actors. Cloud validation follows the tag and gates collection. The release operator and collector
must verify the successful **push-to-main** run on the exact tagged commit;
a same-named PR check does not establish post-merge acceptance.

The agreed Cloud routing is release-only. The Development Workflow, Merge to
main, and old PR workflows are retired; their history is preserved. The tagged
release workflow has two `KitchenMemory Release` Test actions and two Production
Archive actions, one per platform. Test builds already compile their products;
archives provide the distribution build, so separate Cloud Build actions add no
required evidence. No TestFlight audience is inferred from this configuration.

Release tag readiness requires GitHub's exact-main Development CI result. Cloud
release tests and archives gate collection of the finished artifact, not creation
of the tag that triggers those actions. The collector accepts only a successful
whole Cloud run, including required tests.

Release creation authority and tag immutability remain separate rulesets.
This preserves the immutable tag and owner-only creation policy. Repository
files cannot update Cloud workflows or GitHub protection by themselves; record
the live cutover evidence when it is performed.

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

The `Testing` and `ProductionTesting` configurations deliberately omit the
shipping entitlement files and retain the project-owned sandbox capabilities. Their application-hosted tests do not
carry personal CloudKit or push-notification capabilities. This is least
privilege on iOS and is also required because Xcode Cloud's macOS test runner
cannot launch a host application carrying those restricted entitlements.
Development and production configurations retain the complete entitlement set;
the testing exception does not alter a shipped application.

### Cloud UI testing

Cloud UI testing is re-enabled in `KitchenMemoryCloud.xctestplan`, including its
serial UI target, to reassess the previous activation failures under the current
toolchain. GitHub's full application plan also retains UI tests. Runner failures
remain failures until investigated; re-enabling a target is not passing evidence.

To temporarily suspend UI tests, disable the UI target in the affected test plan
and document the reason. Neither the GitHub workflow nor Cloud action needs to
change. Preserve the target reference so re-enabling it is a plan-only edit.
Historical context: [the activation research](research/macos-cloud-ui-test-activation.md).

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
smoke target. The runner also compiles an ordinary `import KitchenKit` client
against that build with `Tools/check-ingredient-authoring-interface.rb`. Supported
live-draft operations must compile; direct session replacement, ingredient writes,
and retired low-level text/history APIs must fail access checking. This gate uses
neither `@testable` nor access-control overrides.

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

## Build settings baseline

All five targets and all five configurations share a macOS/iOS 27.0 minimum.
This alpha compatibility decision is recorded in [ADR 0021](adr/0021-adopt-platform-27-during-alpha.md).

The project checker rejects lower project defaults or divergent target overrides.
The launch storyboard is refreshed with Xcode 27's Interface Builder upgrader;
its object identifiers and layout remain stable. Resource schema numbers such
as storyboard `3.0` and “Xcode 8 format” are serialization identifiers, not OS
minimums. Historical SwiftData schemas remain immutable.

Xcode's recommended localizability analysis, dead-code stripping, and String
Catalog symbols remain enabled. No outstanding recommended-setting warning was
shown by Xcode 27 during this audit. Do not copy settings from Folio wholesale:
KitchenMemory's Swift, multiplatform framework build has different
requirements from Folio's Objective-C Suite installation.

KitchenKit is an ordinary dynamic framework, embedded and signed in the app's
standard Frameworks directory. All project configurations explicitly set
`MERGED_BINARY_TYPE = none`, and the project checker rejects automatic merging.
The app uses its platform-standard Frameworks runpaths. The former `@loader_path/../ReexportedBinaries` workaround is removed;
it applied to Xcode's automatic-merging development layout.

One non-default header search path remains deliberate:

- KitchenKit's `_NumericsShims` header search paths cover ordinary and Archive
  package-checkout layouts. Removing them on 2026-09-24 reproduced `Unable to
  resolve module dependency: '_NumericsShims'` during Xcode dependency scanning.
  Retain them until both a clean normal build and an Archive build succeed
  without them. SwiftPM pins and the ordinary-consumer interface check make
  dependency-layout changes visible rather than silently accepting stale code.

`Tools/StartupMeasurements/measure.py` sets `DYLD_FRAMEWORK_PATH` only for its
local measurement subprocess. It is not a shipped app setting or CI environment.
The signed GitHub Mac lane verifies the test host's team signature, Hardened
Runtime, sandbox, and library validation before starting tests.

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

The retained Cloud workflows use a shared macOS alias mapped to the latest
available macOS release. During early alpha, the project prefers the current Xcode Cloud test
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
uses `Tools/check-repository.rb`, the same dependency-free checks as GitHub.
It validates the target/scheme/plan structure and the read-only release contract. Run
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
xcconfig and disabled merging; the development and production bundle namespaces; platform plist, entitlement, and synchronized-folder
ownership; the shared schemes and explicit plans listed above; and exclusive
plan ownership of test-target membership. It also requires each
localization-catalog embedding phase to run first in its hosted-test target,
preserving the ordering introduced to avoid a cycle with the former KitchenKit
re-export signing step. Treat a contract failure as a reviewable project change, not
as a reason to weaken the checker until the project happens to pass.

Keep cloud scripts short, deterministic, and limited to environment preparation
so build, test, Analyze, and Archive behavior remains visible in Xcode's schemes.

### Local platform 27 validation

Use Xcode 27 and the `KitchenMemory Release` scheme's `KitchenMemoryCloud`
test plan for production-test reproduction. Record the exact Xcode and OS build,
simulator model, and completed result bundle; compare those with the Cloud run.
Run UI tests serially. Do not substitute larger-device success for the compact
device that failed, or send another release candidate to Cloud before local
validation is complete.

Keep a compact simulator inventory on iOS/iPadOS 27:

| Destination | Purpose | Frequency |
| --- | --- | --- |
| iPhone SE (3rd generation) | Smallest phone viewport; toolbar and keyboard pressure; current Cloud parity | Focused fixes and full release plan |
| iPhone 17 (or a current standard-size Pro) | Modern phone safe areas and typical layout | Layout changes and release spot checks |
| iPad mini (A17 Pro) | Small tablet and narrow window layouts | Layout changes and release spot checks |
| iPad Pro 13-inch | Wide layouts and window resizing | Layout changes and release spot checks |
| My Mac, macOS 27 | Native AppKit integration and resizable windows | Focused fixes and full release plan |

The SE and Mac form the frequent loop. The other destinations add layout
coverage without repeating the entire business-logic suite on every screen.
Include manual large-text, VoiceOver, keyboard, and RTL checks at accessibility
acceptance; automated element discovery alone does not establish usability.

#### Platform 27 migration evidence, 2026-09-25

Xcode 27 (27A266a), Swift 6.4, and the `KitchenMemory Release` scheme's
`KitchenMemoryCloud` plan produced these completed local results:

| Destination | Result | Result bundle timestamp |
| --- | --- | --- |
| iPhone SE (3rd generation), iOS 27.0 (24A434) | 813 passed, no failures or skips | 2026.09.25_12-21-22--0500 |
| My Mac, macOS 27.0 (26A428) | 815 passed, no failures or skips | 2026.09.25_12-30-25--0500 |

The final background-submission completion-order correction was rebuilt on iOS
and followed by both background/startup coordinator checks passing
(`2026.09.25_12-28-03--0500`). The focused editor accessibility test also passed
on the SE after compact toolbar controls replaced the overflowing text-only
mode action. Priority alone had reproduced the original failure.

Both full-plan bridge calls exceeded their response timeout; the completed
DerivedData result bundles, not the bridge timeout, establish these counts.
Repository contracts passed. Standards and spec reviews identified and resolved
background-submission ordering and an artifact-architecture guard error.

This is not warning-free or distribution acceptance: duplicate debug-map object
warnings remain (98 in the macOS optimized build), alongside AppIntents metadata
notices. The macOS result also records six internal runtime priority-inversion
warnings; their origin has not been established by this migration. No warning
suppression was added. A signed archive, notarized installation, remote CI run,
and comprehensive assistive-technology validation remain separate evidence.

### Collections umbrella and merged debug-map follow-up (2026-09-25)

The initial umbrella-product experiment kept automatic KitchenKit merging,
explicit Collections dependencies in both consumers, coverage, and dead-code
stripping. Its macOS ProductionTesting build succeeded but reported 387 duplicate
debug-map warnings: 365 Collections object entries and 22 profile-runtime
entries (11 in the app, 11 in KitchenKitTests). This supersedes the earlier
98-warning baseline for the narrower product selection above.

A linker-only differential probe reused the same compiled app objects, SDK,
coverage instrumentation, and link flags from the successful Xcode build. All
output paths (executable, LTO object, dependency information) were redirected
into temporary directories. `dsymutil --dump-debug-map` then gave:

| Temporary app link | Duplicate Collections entries | Duplicate coverage-runtime entries |
| --- | ---: | ---: |
| Original `-merge_framework KitchenKit` | 365 | 11 |
| Only replace merge with `-framework KitchenKit` | 0 | 0 |
| Original merge; omit nine Collections product objects from the app link file list | 0 | 11 |

The nine inputs were Collections, InternalCollectionsUtilities, BitCollections,
SpanPreview, DequeModule, HashTreeCollections, HeapModule, OrderedCollections,
and _RopeModule. Each temporary link succeeded. These probes establish that
merging combines duplicate debug-map records for package objects linked by both
consumers; the coverage runtime has the same merge-sensitive symptom. The
third probe is diagnostic only: removing the app's direct dependency would make
it rely on framework implementation details and needs separate development-link
validation. The temporary probe executables were not runtime-tested.

LLVM's [Mach-O debug-map parser](https://github.com/llvm/llvm-project/blob/main/llvm/tools/dsymutil/MachODebugMapParser.cpp)
warns when records share an object name and timestamp, then skips the duplicate.
This is evidence about debug information, not proof of duplicated executable
behavior or a complete dSYM. Following this evidence, the maintainer selected
ordinary dynamic KitchenKit linking. The app now explicitly embeds and signs KitchenKit in Frameworks,
automatic merging is explicitly disabled, and the ReexportedBinaries runpath
workaround is removed. Both consumers retain their explicit Collections
umbrella dependency. Coverage and dead-code stripping remain enabled; no
warning suppression was added. This trades merged packaging for a conventional
framework load and avoids depending on the observed merge/debug-map interaction.
Archive symbolication remains a separate release check.

The adopted dynamic configuration passed all 815 macOS tests (no failures or
skips; result `2026.09.25_13-01-56--0500`). The completed DerivedData result
establishes this despite a bridge result-copy error. Six pre-existing internal
QoS runtime warnings remain. A clean preceded the topology validation; the app
contains signed KitchenKit in `Contents/Frameworks`, links it through `@rpath`,
and contains no `ReexportedBinaries` directory. Deep, strict signature verification
passed with the normal keychain context. Direct debug-map inspection of the app,
embedded KitchenKit, and KitchenKitTests found zero duplicate-object warnings on
both macOS and the iOS simulator. Repository contracts pass and both review axes
have no remaining findings.

The dynamic iPhone SE iOS 27 full plan (`2026.09.25_13-06-13--0500`) recorded
812 passes and one failure in `testSettingsExposeAccessibleTopLevelStructure`,
with no skips or runtime warnings. Its unchanged isolated rerun passed
(`2026.09.25_13-15-40--0500`). The failed activity trace and UI hierarchy show
three large Settings swipes reaching the bottom (100% scroll), past the lazily
materialized iCloud switch. The helper now uses bounded, overlapping 30%-height
drags and checks existence between steps. Both callers then passed on the SE
(`2026.09.25_13-18-16--0500`): ordinary Settings access and the six-language
doubled-text/right-to-left check. These focused passes do not replace the
record of the initial full-plan failure; the complete plan was not repeated
after the test-helper correction.

The Apple linker report was prepared with the controlled comparison and a
redacted diagnostic attachment. The maintainer is handling submission through
Feedback Assistant; no submitted feedback ID is recorded here yet. The reported
absence of these warnings on Xcode 26.6 is maintainer history, not an identical
build comparison performed during this investigation.
