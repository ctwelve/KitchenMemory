# 0.3 release preparation evidence

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Resumable execution record for [Issue 124](https://github.com/ctwelve/KitchenMemory/issues/124),
following [the release preparation loop](release-preparation.md) and ADR 0018.
This is refactor evidence, not distribution acceptance.

## Pinned scope

- Base: `f242c31d4003bc0e324d1d43ae3499342bb00fa8` (`main`, September 7, 2026).
- Working branch: `codex/124-release-preparation`; submission lane:
  `release-eng/124-release-preparation`.
- Live prerequisite issues #121, #122, and #123 were closed when work began.
- Marketing version remains 0.2.16: this pass preserves accepted behavior rather
  than allocating a product slice. `RELEASE`, schema versions, and dependencies
  remain governed by their existing contracts.
- Architecture exploration, implementation, and dead-code audit are delegated
  with `gpt-6-astra` and an explicitly configured `high` reasoning setting.
  Coordination and validation occur in the parent task; no claim about its
  reasoning setting is needed for those stages.
- Accepted contracts: `CONTEXT.md`, implementation/domain architecture,
  Recipe authority and retention, Folder/Tag policy, Cooking Sessions,
  localization architecture, ADRs 0003, 0007, 0010–0014, and 0016–0019.
- Required gates: fresh exact KitchenKit coverage; Xcode-managed hosted and
  bounded UI tests on Mac and iOS; strict lint; project, resource, localization,
  inventory, and release contracts; release-style platform builds; independent
  adversarial Spec and Engineering reviews of the same pinned candidate.

## Initial validation

Environment: Xcode 26.6 (17F113), macOS 26.6.2 (25G83), September 7, 2026.
All 79 Ruby contract tests passed (292 assertions); localization, project
structure, software inventory, and untagged release checks passed. SwiftLint
0.65.0 passed with `lint --strict --no-cache --quiet`. The first lint attempt
could not write its cache under sandbox restrictions; disabling that optional
cache produced a successful strict run without changing policy.

## Measured hotspots and findings

Before editing, counted changed source paths over the last 100 nonmerge commits.
The leading paths were RecipeLibraryModel (18), KitchenMemoryUITests (17),
RecipeEditingModel (14), RecipeRepository/RecipeLibrarySidebar/ContentView (13
apiece), RecipeEditorView (10), and AppRuntime/LibraryDetailRouter (9 apiece).
Exploration followed those callers, then covered the remaining production,
tests, resources, project membership, scripts, and configuration.

| Rank | Finding and concrete benefit | Disposition |
| --- | --- | --- |
| A1 | Internal `CausalGraph.coalescing`, its result enum, and private initializer have only test callers. All seven production construction sites use the dictionary initializer. Removing the alternate route makes graph tests exercise the production interface and leaves collision policy with the evidence families that own it. | Fixed in `7f3cf00`; nine focused graph/identity tests passed. |
| A2 | Session presentation repeats identical restoration and navigation setup in concrete and protocol initializers. One existing protocol initializer serves both production and test adapters. | Fixed in `120a838`; three focused native tests passed before commit. |
| D1 | `SampleRecipeCatalog.imageResource`, `RecipeEditorView.Mode.saveLabel`, and Session `hasPendingCommand` have no callers. | Removed in `bbb1f23`; live UI calls unchanged. |
| D2 | Presentation `createRecipe`, `reviseRecipe`, and `persistEditingDrafts` exist solely for fixtures; `permitsKitchenActions` is asserted only by its own tests. | Fixed in `bbb1f23`; current draft interface and preservation assertions retained. |
| D3 | Five icon palette color sets have no source, generated-symbol, storyboard, or icon references; the real icon embeds explicit colors. | Removed in `bbb1f23`; actual icon/launch/image resources unchanged. |

The scan inventoried 506 files across production, tests, resources, Tools,
ci_scripts, Configurations, and .github. All production Swift declarations and
references participated in the candidate scan; suspicious candidates were
followed through actual callers. SwiftData/runtime discovery, Objective-C
callbacks, SwiftUI entry points, generated resource symbols, target membership,
platform conditions, and documented external tool entry points were considered.
This is a bounded static audit, not a proof that every possible unreachable path
or future refactor has been discovered.

Retain frozen V1–V7 schemas, migration/backfill, versioned Session codecs,
manifest fields, synchronization receipts/checkpoints/tombstones, and historical
localized copy. Test use does not make these compatibility contracts dead.
Also retain the real RecipeEditingModel native adapter, PreparedApp ownership,
window-specific command effects, and Folder/Tag policy helpers: deleting them
would spread knowledge across callers. Reject repository splitting based only
on file size. Public KitchenKit helpers and the in-memory repository have real
consumer/testing roles and no demonstrated removal benefit.

Local detailed audit: `/private/tmp/km124-architecture-audit.md`; inventory:
`/private/tmp/km124-audit-inventory.txt`; visual report:
`/var/folders/l6/1jrtzdgs4xz0bb5pdz8mgknh0000gn/T/architecture-review-20260907-153401.html`.
These temporary artifacts support resumption on this machine; the retained
findings and final validation below are the portable evidence.

## Iteration checkpoint

Iteration 1: A1 committed as `7f3cf00` after nine focused graph/identity tests
passed. The 40 deleted production lines belong exclusively to the unused
constructor route; meaningful graph assertions now cross the dictionary
initializer. Local result: `/private/tmp/km124-a1-graph-final-tests.xcresult`.
A fresh-cache attempt failed during dependency fetching; validation used the
existing pinned SourcePackages cache, with its expected path restored only in
temporary DerivedData. No repository dependency or project contract changed.

A2's duplicate initializer is removed. Xcode's native `RunSomeTests` action
passed three focused tests on My Mac: production composition/start, outbox
identity through durable retry, and relaunch restoration of progress/scale.
Summary artifact: `5CA3EEC5-F8C1-46D5-A38F-59CDD6B3B7A8`, under Xcode's temporary
`ActionArtifacts/default/RunSomeTests` directory. No failed, skipped, expected
failure, or not-run tests. An overlong terminal-bridge request failed to reach
Xcode before this successful bounded request; it was not a product test failure.

The remaining cleanup is committed as `bbb1f23793da90ea00283cfd965ccd7c45f82b41`.
That is the final production/test/configuration candidate. It removes the listed
members, the newly unused RecipeLibraryIssue.save mapping, and the five palette
sets; all five creation/revision fixture sites now explicitly unwrap an editor,
edit the draft, and assert Save. Unreadable-document retry preserves exact bytes;
KitchenKit's existing failure and compatibility tests still exercise rejected
persistence. The obsolete Save action and failure catalog keys are explicitly
retained in LocalizationContract.json, with every translation value unchanged.

Iteration 2: repeated the architecture/dead-code scan on the changed candidate,
including production/test callers, dynamic/framework entry points, resources,
project membership, scripts, and configuration. No further in-scope actionable
findings remain. Rejected/retained candidates above have no new evidence that
would justify revisiting them. No required refactor was deferred to get a pass.

## Final candidate validation

All rows refer to the production/test/configuration tree of `bbb1f23`. Later
edits to this evidence record and the documentation index do not change those
inputs; evidence is reused only for that unchanged scope.

| Gate | Result and evidence |
| --- | --- |
| Exact durable coverage | **568/568 framework tests passed**, zero failures/skips/expected failures; **13,817/13,817 executable lines**, with the same 130 runtime-adapter lines excluded under ADR 0007. Fresh canonical runner exited successfully. Local bundle: `/private/tmp/KitchenMemoryCoreCoverage.NSNu2F/Tests.xcresult`; log: `/private/tmp/km124-final-core-coverage.log`. |
| Native Mac correctness and semantics | Xcode MCP `RunAllTests`, KitchenMemory scheme/default plan, Testing, My Mac: **185/185 passed** (179 hosted + six UI), no failures/skips/expected failures/not run. Summary artifact `EA7F54FF-BC05-4F4A-AAA1-924ACF656F18`; console `test-console-log-2026-09-07T15-45-26-05-00.txt`, under `ActionArtifacts/default/RunAllTests`. |
| Native iOS correctness and semantics | Xcode MCP `RunAllTests`, KitchenMemory scheme/default plan, Testing, iPhone 17 Pro Max simulator, iOS 26.5 (23F77): **183/183 passed** (177 hosted + six UI), zero failures/skips/expected failures in the saved result bundle. Bundle: `Test-KitchenMemory-2026.09.07_15-52-12--0500.xcresult`, under Xcode DerivedData `KitchenMemory-gfynnkkjuswkoreftcgcjkgwadkr/Logs/Test`. Summary artifact `7B773401-A861-47E4-9D07-9AF33CF3462D`. |
| Strict lint | SwiftLint 0.65.0, `lint --strict --no-cache`: **0 violations across 346 Swift files**. `/private/tmp/km124-cleanup-lint.log`. No baseline, policy relaxation, or new exclusion. |
| Repository contracts | **79 Ruby tests / 292 assertions** and **seven Python tests** passed; localization, project/resource membership, software inventory, and untagged release checks passed. |
| Production builds | Signing-disabled Production builds passed for generic macOS (arm64 + x86_64) and iOS (arm64). `/private/tmp/km124-production-macos.log` and `/private/tmp/km124-production-ios.log`. These are compilation evidence, not signed distribution artifacts. |
| Static analysis | Testing configuration, native macOS and generic iOS: **both Analyze actions passed**. `/private/tmp/km124-analyze-macos.log` and `/private/tmp/km124-analyze-ios.log`. |
| Spec review | Independent review of `f242c31...bbb1f23`: **0 actionable findings**. Checked accepted behavior, graph collision ownership, draft persistence/retry, Session restoration, resources, serialized/migration/sync contracts and scope. |
| Engineering review | Independent review of the same pinned candidate: **0 actionable findings**. Checked actual call paths, protocol dispatch, meaningful retained assertions, platform/resource wiring, dead code, documented standards and baseline code smells. |

The MCP iOS summary reported 185 tests after switching from My Mac. The actual
saved iOS result bundle reports 183, excluding the two Mac-only tests; its
platform, runtime, and integer counts were checked with
`xcrun xcresulttool get test-results summary --path <bundle>` and take precedence
over the bridge summary. Both report a passing action. The native Mac count
remains 185.

The coverage decrease from the earlier 13,846-line ledger is exactly 29
executable lines removed with the unused constructor. No reachable behavior was
excluded, and the gate still requires every remaining durable executable line.
The one constructor-only graph test was retired; traversal and evidence-owner
collision assertions remain. Historical suite counts elsewhere are dated
snapshots; the fresh result above is authoritative for this candidate.

Production logs retain dependency debug-map duplicate-object warnings from
Swift Collections and the AppIntents metadata tool's no-dependency notice. The
builds succeeded; no source/compiler error, lint waiver, or product workaround
was introduced for these diagnostics. Signing was disabled deliberately for
these build/Analyze checks; archive signing and distribution are separate gates.

The final architecture/dead-code pass and both independent reviews have no
unresolved in-scope actionable findings. Every required local gate above passed.
Both reviewers also checked this evidence record and its policy boundaries;
the final iOS result was filled from the completed platform bundle afterward.
The draft PR submits this candidate and evidence for the governed Cloud checks
and maintainer review. Merging and distribution remain separate actions.

## Accessibility and distribution obligations

The bounded Mac ordinary-use evidence from [#122](accessibility-alpha-library-evidence.md)
and [#123](accessibility-alpha-shell-evidence.md) is explicitly carried forward
for the unchanged ordinary-use interactions on Xcode 26.6/macOS 26.6.2. The refactor removes unused paths/resources and identical
initialization; it changes no navigation, control semantics, copy, layout, or
runtime policy. The fresh Mac semantic and hosted suite passed. This reuse does
not extend the original walkthrough's scope. Native semantic tests do not
certify VoiceOver,
focus, comprehensive layout, or ordinary iOS use. An iOS ordinary-use walkthrough
remains required if an alpha distributes iOS; the broader matrix remains beta
work under #168. Cloud UI testing remains suspended under #155. Distribution,
signed artifacts, production schema operations, and maintainer release acceptance
are separate from this refactor pass.
