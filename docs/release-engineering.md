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

## Versioned slice discipline

Each product slice commits its next semantic `MARKETING_VERSION` when work
begins. A patch may identify a bug fix or coherent feature work smaller than a
minor release. An accepted version may be skipped publicly. Every application
configuration must agree; the source `CURRENT_PROJECT_VERSION` remains `1` and
Xcode Cloud assigns distributed build numbers.

The root `RELEASE` marker records the last submitted version and may trail an
untagged working version. Only an intentional release commit advances it to the
selected marketing version. Attach the matching annotated
`release/<major>.<minor>.<patch>` tag to that exact commit and submit commit and
tag together. `RELEASE` must remain build-visible: its change lets Xcode Cloud
import a fresh source event for the Archive workflow.

`Tools/check-release-version.rb` is read-only. Tagged Archive actions require
`RELEASE`, all application marketing versions, and the numeric tag suffix to
agree. Untagged branch actions skip the release-only check; untagged Archives,
malformed tags, and mismatches fail. CI never writes versions back to `main`.

## Candidate gates

1. Pin the candidate and its live issue prerequisites. Apply the
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
