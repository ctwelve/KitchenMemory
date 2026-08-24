# 0.1 release evidence

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Active
- Candidate version: 0.1.0
- Evidence opened: 2026-08-24

This ledger is a practice run of disciplined acceptance for an early alpha. It
records enough evidence to exercise the release process and expose weak gates;
it does not claim that 0.1 has met every criterion expected of a public 1.0.
The release gates and exit criteria are defined in <doc:release-engineering>;
this article records what was actually exercised, where it ran, and which
source state earned the result.

An alpha may deliberately use a smaller representative exercise or defer a
gate whose cost is disproportionate to what the candidate can establish. Mark
that decision explicitly rather than silently treating the gate as passed.
The twenty-recipe corpus and human review of every translated locale are 1.0
gates, not 0.1 blockers.

Evidence applies only to the identified commit and environment. A later change
invalidates every result whose behavior or artifact it can affect. Use the
following result vocabulary consistently:

- **Passed** — the expected result was observed and its evidence is recorded.
- **Pending** — execution has started but has no final result.
- **Not run** — no release claim has been made.
- **Blocked** — execution cannot continue; identify the blocking defect.
- **Deferred** — deliberately outside this candidate stage, with its later gate
  named explicitly.

## Privacy of evidence

Do not commit private recipe content, source URLs, preserved JSON-LD, account
details, device identifiers, screenshots containing private material, or raw
logs that expose them. Give corpus entries neutral labels and record only the
smallest non-private description necessary to identify the exercised shape.

Store private diagnostic artifacts only for the immediate investigation, then
delete them. A public regression test must use synthetic or otherwise
non-private data derived to reproduce the behavior. See <doc:privacy>.

## Automated baseline

| Evidence | Source state | Result | Record |
| --- | --- | --- | --- |
| Pull-request iOS tests | `2c9d250` | Passed | [Xcode Cloud action](https://appstoreconnect.apple.com/teams/69a6de82-7580-47e3-e053-5b8c7c11a4d1/apps/6803723477/ci/builds/ff3d4d7d-c62a-4444-8871-1e0645519d55/action/828e664c-fcc7-4d7a-abce-55502f10f94a), 2026-08-23, 5m43s |
| Pull-request macOS tests | `2c9d250` | Passed | [Xcode Cloud action](https://appstoreconnect.apple.com/teams/69a6de82-7580-47e3-e053-5b8c7c11a4d1/apps/6803723477/ci/builds/ff3d4d7d-c62a-4444-8871-1e0645519d55/action/44c6c924-d185-41d3-b743-385705c792dc), 2026-08-23, 3m48s |
| Branch iOS Build and Analyze | `2c9d250` | Passed | [Xcode Cloud build](https://appstoreconnect.apple.com/teams/69a6de82-7580-47e3-e053-5b8c7c11a4d1/apps/6803723477/ci/builds/06689fa7-9abf-4f3d-9786-c6a9911120b6), 2026-08-23 |
| Branch macOS Build and Analyze | `2c9d250` | Passed | [Xcode Cloud build](https://appstoreconnect.apple.com/teams/69a6de82-7580-47e3-e053-5b8c7c11a4d1/apps/6803723477/ci/builds/06689fa7-9abf-4f3d-9786-c6a9911120b6), 2026-08-23 |
| `main` iOS and macOS Production builds | `b5937b6` | Passed | [Xcode Cloud build](https://appstoreconnect.apple.com/teams/69a6de82-7580-47e3-e053-5b8c7c11a4d1/apps/6803723477/ci/builds/c90d9ae3-850e-4bbf-ad22-689f55d15dcf), 2026-08-24 |
| Release-version contract | `b5937b6` | Passed | Marketing version 0.1.0 and the committed Xcode Cloud seed policy checked by every Cloud action; local contract passed 7 tests and 17 assertions on 2026-08-24 |
| Privacy-manifest policy contract | `b5937b6` | Passed | Focused local test passed 1/1 on macOS 26.6.2 with Xcode 26.6, 2026-08-24 |
| Localization-catalog contract | `b5937b6` | Passed | Focused local test passed 1/1 on macOS 26.6.2 with Xcode 26.6, 2026-08-24 |
| Archive-tag version simulation | `b5937b6` | Passed | The `release/0.1.0` tag-to-marketing-version contract validated across five application configurations, 2026-08-24; no artifact or Cloud-assigned build number exists yet |
| Local ProductionValidation non-UI suite | `d90fb85` | Passed | 252/252 tests on macOS 26.6.2 with Xcode 26.6, 2026-08-24; includes domain, import, persistence, app composition, privacy-manifest, and localization-catalog contracts |
| Signed local macOS UI smoke suite | `a02694a` | Passed | 10/10 tests on macOS 26.6.2 with Xcode 26.6, 2026-08-24; includes privacy-safe startup recovery, supported locales, localization stress modes, settings/privacy, recipe navigation, and the 280/320-point sidebar behavior |
| Unsigned Production bundle preflight | `a02694a` | Passed | Fresh macOS and generic iOS builds succeeded on 2026-08-24; both report version 0.1.0, source build-number seed 1, and minimum OS 26.0; privacy manifest matched source byte-for-byte and all three locale bundles were present |

These rows establish the release-engineering infrastructure baseline. They do
not replace installation, synchronization, localization, accessibility, archive,
or recovery acceptance.

## Supported-device matrix

Fill in exact public OS versions and device classes. Do not record serial
numbers, UDIDs, Apple IDs, or other account identifiers.

| Device class | Installation | OS | Candidate | Result | Evidence note |
| --- | --- | --- | --- | --- | --- |
| iPhone 16 Pro Max | Clean | Record at execution | Unassigned | Not run | Paired device available 2026-08-24; private device name and identifier omitted |
| 12.9-inch iPad Pro (3rd generation) | Clean | Record at execution | Unassigned | Not run | Paired device unavailable 2026-08-24; private device name and identifier omitted |
| Apple-silicon Mac | Clean, outside Xcode | macOS 26.6.2 | Unassigned | Not run | Current development Mac; clean artifact installation remains unproven |
| iPhone or iPad | Update over an older candidate | Unassigned | Unassigned | Deferred | Required after beta distribution exists |

## Recipe acceptance

For 0.1, exercise the bundled example recipes plus a small number of varied,
non-private additions. The walkthrough should include manual entry or editing,
an ordinary import, a deliberately imperfect import, relaunch, revision,
scaling, reading, and source review. Record the exact small set used, but do not
inflate its size into a broad corpus claim.

The following twenty-recipe corpus is retained as a 1.0 gate and is deferred
for this alpha candidate.

Exercise twenty recipes without committing their private contents. Each group
contains four corpus entries; label them `C01` through `C20` in execution notes.

| IDs | Required shape | Result | Evidence note |
| --- | --- | --- | --- |
| C01–C04 | Manual entry: sparse, incomplete, multi-section, and metadata-rich | Deferred | Required for 1.0 acceptance |
| C05–C08 | Straightforward Schema.org imports from varied publishers | Deferred | Required for 1.0 acceptance |
| C09–C12 | Partial, nested, multi-candidate, or otherwise messy imports | Deferred | Required for 1.0 acceptance |
| C13–C16 | Exact, ranged, approximate, written, and intentionally unscalable quantities | Deferred | Required for 1.0 acceptance |
| C17–C20 | Long-form and authored-language examples across the release locales | Deferred | Required for 1.0 acceptance |

For every entry, exercise the applicable path through import or entry, review,
save, relaunch, revision, scaling, reading, and source review. Record a concise
non-private discrepancy whenever preserved meaning, ordering, identity, or
authored language differs from the input.

## Synchronization and recovery

Use clean installations signed into the same test iCloud account. A displayed
“available” state is not proof that a particular record synchronized; verify the
resulting library graph and stable identities on both devices.

| Scenario | Expected result | Result | Evidence note |
| --- | --- | --- | --- |
| Create on device A | Complete recipe graph appears on device B | Not run | — |
| Revise on device B | Immutable revision history converges on device A | Not run | — |
| Work offline, then reconnect | Local work remains usable and later converges | Not run | — |
| Concurrent revisions | Both immutable revisions survive deterministically | Not run | — |
| Delete a recipe | Deletion converges without restoring unrelated samples | Not run | — |
| Interrupt synchronization | UI reports honest progress or failure and recovers | Not run | — |
| Remove or restrict the iCloud account | Local behavior remains intelligible; no false success | Not run | — |
| Relaunch during recovery | Stored content and recovery state remain coherent | Not run | — |
| Compare stable identities | Kitchen, recipe, revision, child-row, media, and sample IDs survive | Not run | — |
| Review generated V1 schema | Clean-install schema matches the frozen model | Not run | — |
| Promote the production schema | Promotion is recorded and irreversible fields are reviewed | Not run | Required only after every preceding V1 gate passes |

## Person-facing quality

| Surface | Required review | Result | Evidence note |
| --- | --- | --- | --- |
| `en-US`, `fr-CA`, and `es-MX` alpha check | Automated catalog contract plus developer review of representative layouts and fallback behavior | Not run | Human review is not claimed for 0.1 |
| `fr-CA` and `es-MX` human review | Native-language review of meaning, tone, plurals, and authored samples | Deferred | Required before 1.0 acceptance |
| Durable application shell | VoiceOver, keyboard/focus, Dynamic Type where applicable | Not run | — |
| Settings and privacy display | Clear state, recovery language, privacy accuracy | Not run | — |
| Import and review | Error identification, source preservation, accessible controls | Not run | — |
| Recipe reading and scaling | Reading order, working yield, unsafe-scaling guidance | Not run | — |
| Failure and recovery states | Empty, partial-sample, offline, restricted, and sync failure | Not run | — |
| Diagnostic output | No recipe content, source URLs, account data, or unnecessary identifiers | Not run | — |

The provisional editor is not required to prove a final 0.2 interaction model,
but any barrier that prevents ordinary 0.1 use is release blocking.

## Archive and distribution

| Gate | Result | Evidence note |
| --- | --- | --- |
| Privacy manifest matches the release binary and bundled dependencies | Not run | — |
| Version, credits, license, localized metadata, icons, and launch assets | Not run | — |
| Immutable `release/0.1.0` tag created from the accepted candidate | Not run | Create only after earlier gates pass |
| Xcode Cloud-assigned artifact build number recorded | Not run | Known only after the protected release tag produces an accepted artifact |
| Signed iOS archive | Not run | — |
| Signed and notarized macOS archive | Not run | — |
| Notarized Mac artifact installs and launches outside Xcode | Not run | — |
| TestFlight installation and update path | Deferred | Distribution is intentionally not configured yet |
| Production-schema, archive, and submission procedure rehearsed | Not run | — |

## Known issues and blockers

| Kind | Status | Record |
| --- | --- | --- |
| Toolchain diagnostic | Accepted | macOS 26.2 Swift/XCTest actor-isolated teardown can abort application-hosted tests; CI uses the latest runtime. See [swiftlang/swift#87316](https://github.com/swiftlang/swift/issues/87316). |
| Toolchain diagnostic | Accepted | Xcode 26.6 may emit `DebuggerVersionStore` messages while an iOS or macOS UI-test fallback launcher proceeds; assertions remain ordinary failures. See <doc:continuous-integration>. |
| Release blocker | None recorded | Add every unresolved data-loss, source-corruption, ordinary-use, or false-sync-success defect here. |

## Execution order

1. Assign the available supported devices and run representative clean-install
   checks, beginning with a direct installation on physical iPhone hardware.
2. Exercise the small 0.1 recipe set locally before introducing
   synchronization; retain the twenty-recipe corpus for 1.0.
3. Run the alpha-appropriate subset of the two-device synchronization and
   recovery matrix, recording every omitted scenario as deferred rather than
   passed.
4. Correct release-blocking defects with regression coverage and re-establish
   affected automated evidence.
5. Complete the 0.1 developer localization, accessibility, privacy, and
   diagnostic review; retain native-language review for 1.0.
6. Review and promote the production CloudKit schema.
7. Create the immutable release tag, inspect the archives, and verify the
   notarized Mac artifact outside Xcode.
8. Configure and rehearse beta distribution before inviting testers.
