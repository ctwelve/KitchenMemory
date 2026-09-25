# Release engineering

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Use this guide for an intentional candidate or publication. Working versions,
submitted releases, and published artifacts are separate states. The current
public artifact is recorded in the root [README](../README.md); source versions
come from the Xcode project and the [software inventory](../DEPENDENCIES.md).
The [0.1 runbook and outcome](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-engineering-0.1.md) are historical evidence.

## Release tiers and versions

Use three-part `major.minor.patch` versions for the app, inventory, `RELEASE`,
and `release/<major>.<minor>.<patch>` tags. Release scope determines the checks;
a fourth version component is not used. This policy is recorded in
[ADR 0020](adr/0020-scale-release-assurance-to-scope.md).

| Tier | Version and purpose | Acceptance |
| --- | --- | --- |
| Major | Major increment, leaving beta, or post-beta major architectural change | Full tests, assurances, and release procedures; explicit human review and sign-off across every aspect. Complete localization, code review, stable and fully tested UI, product website, and App Store preparation are among the readiness requirements. LLM-performed localization is accepted; human locale reviewers can be added as the audience grows. |
| Minor | Minor increment; post-beta feature release | Programmatic review is accepted and trusted. Validate the feature scope and affected integration, persistence, UI, localization, and distribution risks. Major architectural changes require a major release. |
| Patch slice | Patch increment for each coherent slice; usually unpublished | Apply slice acceptance and normal integration checks. A breaking bug may justify publication at this level through the short urgent process. |
| Patch bug fix | Patch increment strictly for a bug fix | Use the focused bug-fix release process below; do not rerun the full release-engineering audit solely because a release is being published. |

The assurance level should fit this personal project; major releases still need
complete preparation and explicit human acceptance, without importing an
unrelated safety-critical or large-commercial-product process.

Each slice or bug fix commits the next unused patch version when work begins;
accepted versions may be skipped publicly. Every application configuration must
agree. The source `CURRENT_PROJECT_VERSION` remains `1`; Xcode Cloud assigns
distributed build numbers.

The root `RELEASE` marker records the last submitted version and may trail an
untagged working version. An intentional release commit advances it to the
selected app version. Attach the matching annotated tag to that exact accepted
commit. Keep `RELEASE` build-visible so Xcode Cloud imports the Archive event.
`Tools/check-release-version.rb` requires the tag, marker, and all application
versions to agree; untagged Archives, malformed tags, and mismatches fail.

## Focused bug-fix release

1. Keep product changes strictly within the fix. Retain a reproduction and
   focused regression evidence; reuse still-applicable validation from the fix.
   Version, release notes, and necessary release metadata accompany it.
2. Align versions and inventory, pass structural and release checks, and ensure
   affected products compile. Honor the existing required PR checks; no blanket
   architecture/dead-code audit, exact-coverage rerun, or comprehensive UI matrix
   is required solely for this release. Broaden checks when the changed risks
   justify them, and record material omissions honestly.
3. Merge through the governed PR lane, verify the exact merge's applicable
   Production builds, and create its immutable annotated release tag.
4. Verify the tagged archive and signed distribution product: version/build,
   signing/notarization, expected entitlements, and a short launch check. Publish
   the verified Mac download and checksum with concise bug-fix release notes.
   An unchanged schema does not require new CloudKit administration.

Post-beta, retain release branches for supported major, minor, and patch lines
so fixes can be backported. The current set of supported lines determines which
branches remain; do not treat these maintenance branches as disposable merged
integration branches. Establish their exact names and CI routing when that
support begins. Alpha does not require speculative backport branches.

## Broader candidate gates

These gates apply according to the release tier above. The full preparation
loop belongs to major-release assurance or an explicitly requested broader
audit; a minor release uses trusted programmatic review scoped to its changes.

1. Pin the candidate and its live issue prerequisites. When required, apply the
   [release-preparation loop](release-preparation.md), preserving measured
   findings, dispositions, validation, and independent review in a draft PR.
2. Pass the [CI contract](continuous-integration.md): structural and inventory
   checks, exact durable coverage, native application correctness, applicable
   local UI checks, Build, and Analyze. Correct release-blocking failures and
   retain regression evidence.
3. Validate persistence, migrations, local recovery, and private iCloud behavior
   for the candidate's changed risks. Review additive schema evolution using
   [the iCloud guide](personal-icloud-synchronization.md). Development-container
   initialization never authorizes promotion of `iCloud.net.ctwelve.KitchenMemory`.
4. Apply the [accessibility alpha/beta gate](accessibility-engineering.md),
   [localization contract](localization-architecture.md), and
   [privacy review](privacy.md). Record omitted devices, locales, assistive
   technologies, and recovery exercises as omissions, never passes.
5. Review the actual merge commit on `main` and its applicable iOS and macOS
   Production Build results before creating a release tag.

Keep a candidate-specific ledger with source SHA, environment, exact artifacts,
results, known blockers, accepted reductions, and remaining obligations. Use
synthetic data and bounded conclusions; never commit private debugging material,
account data, raw schema exports, or private screenshots. Earlier ledgers in
[the history index](history.md) are examples, not reusable passing evidence.

## Publication and distribution

Publication and Production schema promotion are deliberate release-operator
operations. Neither a working-version change nor this guide initiates them.

- Release tags are immutable evidence: never move, reuse, delete, or recreate a
  tag to replay a failed service event. The candidate must already be on `main`
  with required Production evidence. [GitHub enforcement](continuous-integration.md#github-enforcement-boundary)
  restricts creation separately from readiness and immutability.
- The `Tag to release/` Cloud workflow uses the `KitchenMemory Release` scheme and
  `Production` for iOS and macOS Archives with normal signing and production
  entitlements. Both prepare App Store Connect distribution; the macOS archive
  has a notarization post-action. Required `ProductionTesting` actions exercise
  framework, app-hosted, and UI tests on both platforms. No TestFlight group is configured.
- Inspect the signed products: versions, build numbers, native Apple silicon Mac
  and iOS architectures, entitlements, schema readiness, privacy manifests, dependency
  notices and embedded frameworks, localized metadata, credits, icons, and launch
  resources. Reconcile packages with [DEPENDENCIES.md](../DEPENDENCIES.md) and
  the SBOM. Source-input checks do not replace signed-product inspection.
- Install and launch the notarized Mac artifact outside Xcode. Preserve its
  checksum and attach that exact verified artifact to the matching GitHub
  release. Every public release from 0.2.1 onward requires the downloadable Mac
  product; a source-only release is incomplete.
- Before beta, establish tester distribution, clean-install and update checks,
  stabilized data and interface contracts, and the deferred acceptance matrix.

The [0.1 tag-import failure](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-engineering-0.1.md#01-outcome) and explicitly
accepted local Mac archive are an exception for that candidate. If a service
fails again, retain its evidence and establish a candidate-specific recovery
path without weakening tag protection or claiming absent actions passed.

## Automated Cloud artifact collection

The release collector is being introduced on `release-eng/cloud-release-handoff`.
On 2026-09-24, the dedicated Apple API key and GitHub environment were configured,
and the collector downloaded and passed every artifact check against historical
Cloud build 429 (`release/0.3.1`, commit `ebc64869fdd8059e7455cdb79a2838675d573966`).
This was a local collection proof; it did not modify that published release or
repeat install/launch acceptance. The first tag-triggered GitHub collection and
draft upload remain pending integration and the next release. GitHub protection
and Cloud routing are recorded in the [CI contract](continuous-integration.md#github-enforcement-boundary).

`.github/workflows/release.yml` starts collection when Xcode Cloud posts a
successful `KitchenMemory | Tag to release/` commit status. GitHub supports this
through its [status event](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#status).
The workflow must be merged into the default branch before this trigger is active.
No tag-triggered polling runner or external webhook relay is required.

The completion event supplies a source SHA and Cloud build ID. The resolver
requires one release tag at that SHA; the collector independently verifies main
validation and the configured Apple workflow's latest successful tag/commit build.
The event alone is not trusted as release evidence. Incomplete builds fail promptly,
and a stale event cannot collect an older attempt. Manual dispatch with the existing
tag is the recovery path for missed events or delayed artifact availability; it
also performs a single readiness check, without polling. Collection runs serialize
to avoid competing draft uploads. A published release is never modified.

The `release-collection` GitHub environment needs `ASC_KEY_ID`, `ASC_ISSUER_ID`,
and `ASC_PRIVATE_KEY` secrets, plus the `ASC_RELEASE_WORKFLOW_ID` variable.
Use a dedicated App Store Connect API key with the least role Apple permits for
reading Cloud build artifacts. Keep private keys and signed download URLs out
of repository files, logs, and release evidence.

Only Apple's `STAPLED_NOTARIZED_ARCHIVE` artifact is eligible. The collector
requires an unambiguous artifact and checks the actual app's bundle identity,
version, Developer ID team, Hardened Runtime, sandbox and Production CloudKit
entitlements, both Mac architectures, signature, notarization ticket, and
Gatekeeper assessment. It retains the original download bytes and creates a
SHA-256 checksum and a provenance record identifying the exact Cloud run and
artifact. Unexpected packaging fails for inspection rather than guessing.

The collector prepares a **draft** GitHub Release. It can resume missing uploads;
existing assets must match byte for byte, and published releases are never
modified. Before publishing, complete the install/launch acceptance and the
applicable release-tier checks above, then replace the provisional draft notes
with reviewed release notes. No TestFlight audience or public iOS distribution
is established by artifact collection.

API contract references: [Cloud build runs](https://developer.apple.com/documentation/appstoreconnectapi/build-runs)
and [Cloud artifacts](https://developer.apple.com/documentation/appstoreconnectapi/artifacts).

## 0.3.4 alpha candidate

The maintainer requested a simple release of the current accepted code on
2026-09-24. This candidate gathers the accepted adaptive navigation, recipe
reading and ingredient-editing slices, package algorithm improvements, and the
macOS/iOS 26.5 baseline with GitHub development CI. It remains an alpha, with
focused integration and distribution checks rather than a new major-release audit.

The immutable `release/0.3.3` candidate archived successfully in Cloud build 481,
but failed required production tests and was not published. PR #227 corrected
hosted test linkage and production diagnostics expectations, and applied Apple's
macOS Cloud test-host signing workaround. Its full local optimized release plans
passed 813 iOS and 815 macOS tests; all required GitHub checks also passed.
Cloud confirmation of the signing workaround remains pending.

The release marker is aligned with the 0.3.4 application and inventory. Required
PR checks and exact post-merge GitHub validation must pass before the annotated
`release/0.3.4` tag is created. The collector must verify the newly tagged product
and record its source SHA, Cloud build, artifact identity, and checksum.
Historical build 429 is tooling evidence only.

Publication remains pending the new artifact's standalone launch check and
reviewed alpha release notes. This candidate does not claim beta readiness,
the deferred comprehensive UI/accessibility matrix, or a new TestFlight audience.


## 0.3.5 alpha candidate

The maintainer requested release of the accepted platform-27 changes on
2026-09-25. PR #229 merged as `26ec95aff0f8ae037d2f307c20f1f7c9123156dc`;
its full development validation and the exact merge's push-to-main validation
both passed (GitHub runs 36183534076 and 36186410808). The maintainer also
reported a successful manual iOS smoke test.

The earlier immutable `release/0.3.4` tag belongs to the failed Cloud candidate;
it is not moved or reused. This version-only candidate advances the application,
release marker, and software inventory to 0.3.5. It includes iOS/macOS 27 minimums,
updated dependencies, conventional dynamic KitchenKit linkage, and accessibility
checks driven through named controls. No persisted schema change is introduced.
The separate development-CI naming cleanup remains outside this candidate.

After this preparation merges, require its exact main validation before creating
`release/0.3.5`. Cloud production tests, signed Archives, notarized artifact
collection, standalone Mac install/launch acceptance, and reviewed alpha release
notes remain outstanding. Local checks and earlier candidates do not substitute
for those results. No new TestFlight audience is requested.
