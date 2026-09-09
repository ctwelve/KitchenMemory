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
The [0.1 runbook and outcome](release-engineering-0.1.md) are historical evidence.

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
- The `Tag to release/` Cloud workflow uses the `KitchenMemory` scheme and
  `Production` for iOS and macOS Archives with normal signing and production
  entitlements. Both prepare App Store Connect distribution; the macOS archive
  has a notarization post-action. No TestFlight group or post-action is configured.
- Inspect the signed products: versions, build numbers, universal Mac/iOS
  architecture, entitlements, schema readiness, privacy manifests, dependency
  notices and embedded frameworks, localized metadata, credits, icons, and launch
  resources. Reconcile packages with [DEPENDENCIES.md](../DEPENDENCIES.md) and
  the SBOM. Source-input checks do not replace signed-product inspection.
- Install and launch the notarized Mac artifact outside Xcode. Preserve its
  checksum and attach that exact verified artifact to the matching GitHub
  release. Every public release from 0.2.1 onward requires the downloadable Mac
  product; a source-only release is incomplete.
- Before beta, establish tester distribution, clean-install and update checks,
  stabilized data and interface contracts, and the deferred acceptance matrix.

The [0.1 tag-import failure](release-engineering-0.1.md#01-outcome) and explicitly
accepted local Mac archive are an exception for that candidate. If a service
fails again, retain its evidence and establish a candidate-specific recovery
path without weakening tag protection or claiming absent actions passed.
