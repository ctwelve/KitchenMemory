# 0.3 engineering evidence

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

[Issue 126](https://github.com/ctwelve/KitchenMemory/issues/126) assembles the
engineering candidate for a later beta wayfinder. This record does not declare
the UI stable, decide the next milestone, or authorize distribution. The
maintainer selected **macOS-only 0.3-alpha distribution**; iOS remains supported
and retains its engineering checks.

## Candidate and reproduction

Recorded September 7, 2026. Documentation baseline:
`7fe3971f42c192e4e0d4e940a8f92a11ebdb9406` (merged PR 175).
The shipping source, tests, resources, project, configurations, plans, and pins
are byte-for-byte unchanged from
`d701bcd3865a058f41bb5711a386b8a0d3a4186f`, the final #125 candidate.
The separate acceptance harness now opens the application's current V7 schema
and emits its selected version. It is absent from shipping targets and archives.
Harness source: `2fcd2d562d4059207fa7f728db6310c11deb0a88`. The containing
PR identifies the versioned evidence revision.

| Environment | Actual selection |
| --- | --- |
| Toolchain | Xcode 26.6 (17F113); Apple Swift 6.3.3, swiftlang 6.3.3.1.3. |
| Mac | Apple silicon, arm64; macOS 26.6.2 (25G83), My Mac. |
| iOS native tests | iPhone 17 Pro simulator; iOS 26.5 (23F77). No physical iPhone/iPad walkthrough. |
| Framework | KitchenKit scheme, KitchenKit.xctestplan, Testing, native Mac canonical coverage runner. |
| Hosted and UI | KitchenMemory scheme, KitchenMemory.xctestplan, Testing, Mac and iOS; Xcode-managed Test actions. |
| Cloud CI | KitchenMemoryCloud.xctestplan, hosted tests only; governed PR and Production workflows. |
| Ordinary use | Current Testing Mac product, disposable synthetic fixture, Cloud sync disabled. |
| Managed Cloud | Separately signed Develop harness, personal iCloud account, fresh disposable V7 replicas on one Mac; development container only. |
| Signed archives | KitchenMemory scheme, Production, generic macOS universal arm64/x86_64 and iOS arm64; 0.3.0 (1). |

[Dependency evidence](release-dependencies-0.3.md) owns the exact archive hashes,
license/privacy inspection, reproducible archive procedure, and pin review.
[Package.resolved](../KitchenMemory.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)
and the [SBOM](../SBOM.spdx.json) pin six source packages and eight inventory
components: Defaults 9.0.9, Collections 1.6.0, Algorithms 1.2.1, Numerics 1.1.1,
SwiftSyntax 603.0.2, and SwiftLintPlugins/SwiftLint 0.65.1. Fresh resolution and
both archive checkouts matched those exact revisions. No new recipient of data
or runtime dependency is introduced by this packet.

## Engineering gates

The final #125 saved result bundles were reread for this packet, and the product
input comparison above passed. Reuse is limited to those unchanged inputs;
harness build and scenario checks below are fresh.

| Gate | Result |
| --- | --- |
| Exact durable logic | 568/568 tests; 13,817/13,817 executable lines. The same 130 runtime-adapter lines remain excluded under ADR 0007. |
| Native Mac | 186/186 passed: 180 hosted and six bounded semantic UI tests, Xcode action 1799-9. |
| Native iOS | 184/184 passed: 178 hosted and six bounded semantic UI tests, Xcode action 1799-10. |
| Result integrity | Both native bundles and the framework bundle report zero failures, skips, and expected failures; platform bundle counts take precedence over bridge summaries. |
| Strict lint | Fresh SwiftLint 0.65.1 run: zero violations across 347 Swift files. |
| Repository contracts | Fresh 92 Ruby tests / 334 assertions and seven Python tests passed; documentation, localization, project/resource membership, inventory/SBOM, and untagged release checks passed. |
| Analyze | Native macOS and generic iOS passed on unchanged analyzed source. |
| Signed payload | Both Production archives passed deep, strict signature verification; complete notices and the two expected privacy manifests match reviewed source. Runtime payload and linker inputs exclude build tools. |
| Independent review | Standards and Spec reviews corrected two scenario-attribution claims; zero remaining actionable findings. |
| Merged baseline CI | PR 175 checks and both actual-merge Production builds passed. Strict PR source-policy and trusted Xcode Cloud PR checks remain required. |

Reproduce source gates with the checks invoked by
[ci_post_clone.sh](../ci_scripts/ci_post_clone.sh); run the canonical framework
coverage script and the native Xcode workflow described in
[the coverage contract](adr/0007-business-logic-coverage-and-ui-smoke-tests.md) and [the Xcode agent workflow](agents/xcode.md).
Archive reproduction and signed payload inspection are in the dependency record.
These are engineering artifacts signed with Apple Development certificates;
Developer ID export, notarization, Gatekeeper installation, and eventual
installed-artifact acceptance remain separate release steps.

## Synthetic data scenarios

All fixtures below contain synthetic data. Tests use disposable stores, explicit
old-schema fixtures, or controlled clocks; no ordinary personal library is reset.

| Scenario | Evidence and bounded result |
| --- | --- |
| Fresh install | RecipeLibraryStartupTests exercise undecided empty startup, accepting/declining bundled content, explicit fixture installation, retry, and the pending first-run choice becoming irrelevant after a local Recipe is saved and explicitly refreshed (a simulation, not remote delivery). The fresh Mac walkthrough below also passed. |
| Migrated store | KitchenMemorySchemaSynchronizationTests create real V1/V2/V3 schema stores and reopen through the current V7 migration plan: Recipe content and deletion/restoration evidence survive; no owner is invented. Interrupted V2 migration remains recoverable. Authority-save tests verify idempotent backfill and reject unknown/cross-owned graphs. This does not promise survival of every historical alpha store; ADR 0016 remains the alpha reset boundary. |
| Offline | Durable local transaction/history tests and Session/Recipe draft relaunch tests preserve pending evidence. Managed reconnection is recorded separately below. |
| External refresh | SwiftDataCookingSessionRepositoryTests read every classification from an external writer. PersistentStoreChangeObserverTests prove the persistence-queue callback reaches the main actor; hosted CookingSessionExternalRefreshTests separately prove composition reloads the read context. Live transport evidence is bounded below. |
| Deletion aging | RecipeRetentionTests and RecipeRetentionEvidenceTests advance controlled clocks through expiry and the five-year tombstone horizon; unknown/recent dates remain recoverable, late children preserve recovery, shared media is retained, and late evidence becomes a new Recovery draft rather than silently resurrecting content. |
| Recovery | Partial Session closure/restoration fixtures classify as Unavailable until complete; conflicting roots classify as Recovery. Authority and retention tests reject malformed or unavailable graphs. Startup failure/retry is exercised in the Mac walkthrough. |
| Relaunch | RecipeDraftRelaunchTests, CookingSessionRelaunchTests, Folder/Tag persistence and checkpoint tests reopen persisted state; retained local outbox work remains retryable. These are persistent-store checks, distinct from the volatile ordinary-use fixture. |

The named tests are included in the passed suites above. The signed acceptance
harness's deterministic matrix passed all ten checkpoints across E1, E2b, E3, E4a, E4b, E5,
and E7, including intermediate deleted/partial states. Build it explicitly from
the candidate before running; use new replica names and run UUIDs, then follow
[the harness procedure](../Tools/SessionCloudKitAcceptance/README.md).
A successful Cloud operation alone never proves receipt: only complete expected
receiving-store evidence and row content can do so.

Fresh managed V7 E4b runs passed in both orders (A offline/B online, then
B offline/A online). Each offline replica reopened with managed CloudKit; each
fresh receiver verified the exact expected evidence multiset and row content.
Every store reported schema 7.0.0. Reopening the verified receiving store in a
new process also passed exact retained evidence with zero new Cloud operations
or remote-change notifications. The additional E3 foreground-notification phase
ended **inconclusive after its 300-second observation window**: callbacks
arrived, but the expected synthetic Session was not observed. It did not
establish live notification-driven refresh. A subsequent E3 relaunch of that
same receiving store **passed exact evidence and content** after additional
Cloud operations; this does not retroactively pass the foreground phase or
establish that the evidence was already present before relaunch. The separately
passed observer/composition tests and E4b retained-store relaunch retain only
their stated scope. Earlier V3 runs are excluded from current-schema evidence.
No Production schema initialization/promotion was performed. Development
transport cannot establish Production schema readiness or physical multi-device
behavior; the full historical transport/device matrix is not claimed as rerun.

## Locales and bundled Recipes

All six supported locales—en-US, en-GB, es-MX, fr-CA, de-DE, and it-IT—passed
catalog, bundled Recipe-pack content/structure, and fallback checks in the source
contracts and compiled-resource suites. Catalog checks establish coverage and
format contracts, not human linguistic quality. The
[accepted alpha translation device/layout waiver](localization-alpha-validation.md)
remains explicit: per-language physical-device/layout and comprehensive
accessibility validation are unverified, deferred to #168. Locale-authentic
Recipe curation remains [#127](https://github.com/ctwelve/KitchenMemory/issues/127).

## Mac ordinary-use walkthrough and acceptance

A fresh September 7 walkthrough used the current Mac Testing product on the
recorded OS, with disposable bundled Recipes and Cloud sync disabled. It passed:

- Startup, finding and reading a bundled Recipe's ingredients/instructions.
- Creating a synthetic Recipe, editing title/summary, and saving it back to the
  Library with the saved detail visible.
- Starting a Cooking Session, stopping it, and resuming it to Active.
- Opening Settings and reaching the named sample-content, privacy, and reset
  controls without changing ordinary user settings.
- Relaunching with the explicit startup-failure fixture, reaching the explanatory
  recovery screen and invoking Try Again; after removing the injection, a fresh
  launch returned to the Library and readable Recipe detail.

No core-path barrier was observed in this bounded English Mac pass. The fresh
semantic suite also checks the named top-level Library, Settings, startup
recovery, Sessions, Deleted Items, and Recovery destinations. This evidence does
not certify VoiceOver, focus order, comprehensive keyboard navigation, touch,
all text sizes, window layouts, appearances, languages, or ordinary iOS use.
The UI remains provisional. [The alpha policy](accessibility-engineering.md)
requires any known core-path barrier to block distribution even if tests pass.

**Maintainer acceptance: accepted September 7, 2026.** The maintainer explicitly
accepted the Mac-only alpha engineering packet at
`4b4f62859ba4e0913b0ea6da2d8db216a10ee58f`, including the recorded limits. The
inconclusive foreground-delivery observation is accepted as nonblocking for
this scoped packet; its result remains inconclusive, not a pass.

No release tag, App Store submission, tester group, beta distribution, or feature
promise is made. This acceptance does not replace the eventual signed,
installed-artifact and Production-readiness checks in the release procedure.

## Explicit remaining boundaries

- [#168](https://github.com/ctwelve/KitchenMemory/issues/168) owns comprehensive
  UI design, stabilization, beta accessibility and localization/layout evidence.
  Deferred matrix rows are unverified; they are never counted as passes.
- [#155](https://github.com/ctwelve/KitchenMemory/issues/155) tracks suspended
  Cloud UI testing. Local Xcode semantic checks and hosted Cloud checks remain
  required. These are the current open accessibility/testing gate tickets; no
  observed unresolved core-path barrier is recorded by this packet.
- [Device retirement](records-maintenance.md#device-retirement-boundary) remains
  beta-wayfinder work. No device roster or global retirement guarantee exists.
- iOS distribution, TestFlight/friends-and-family delivery, and its ordinary-use
  walkthrough are deferred by the maintainer's Mac-only alpha decision. Expanding
  distribution reopens those platform acceptance obligations.
- Production schema review/promotion and notarized Mac distribution remain
  deliberate release operations. The development Cloud exercise and inspected
  engineering archives provide no implicit authorization or pass for them.

Only concise conclusions and repository metadata are retained here; private
Recipe content, account identifiers, store locations, and raw logs are excluded.
