# ADR 0020: Scale release assurance to scope

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Accepted
- Date: 2026-09-09

Release assurance follows the scope of the change, using three-part
`major.minor.patch` versions. Major releases, leaving beta, and post-beta major
architectural changes require full preparation and explicit human review and
sign-off across the release; LLM-performed localization is an accepted exception
to human localization review. Minor feature releases trust programmatic review.
Slices increment the patch and are usually unpublished; a breaking bug may
justify an urgent patch release. Bug-fix patches strictly follow a bug fix and
use focused regression, compilation, version, and distribution checks rather
than a blanket release-engineering audit. Post-beta, retain supported release
lines for backports.

The tier table and short publication path in [release engineering](../release-engineering.md)
are the operational contract. This amends [ADR 0018](0018-converge-release-preparation-on-evidence.md):
its comprehensive loop is available for major-release assurance and explicit
audits, not mandatory for every publication. Existing required CI checks,
immutable tags, truthful evidence, signing, and notarization remain applicable.
