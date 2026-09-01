# 0.2.2 release evidence

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: candidate validation in progress
- Candidate version: 0.2.2
- Evidence opened: 2026-08-31
- Accepted release source: pending
- Immutable release tag: `release/0.2.2` pending
- Production environment: V4 deployed 2026-08-31

This patch release carries the V4 ownership repair from the rejected 0.2.1
candidate and makes convergence idempotent. Once a compatible personal Kitchen
has settled, later CloudKit notifications do not replace its ownership marker
or rewrite records that already belong to it.

## Required evidence

| Gate | Result | Bounded record |
| --- | --- | --- |
| Synthetic cross-Kitchen regression | Passed locally | Owner-guarded convergence leaves one personal Kitchen; reset and Cooking Session start both succeed. |
| Repeated-convergence regression | Passed locally | The released implementation failed the new test; the repair preserves the canonical ownership marker across repeated convergence and leaves one ownership row. |
| Different-owner preservation | Passed locally | Explicitly different ownership stops convergence without mutating the foreign Kitchen. |
| V1/V2/V3 to V4 migration | Passed locally | All historical stores remain readable; V3-to-V4 preserves content without inventing an owner, and V4 adds only Kitchen ownership evidence. |
| Exact KitchenKit coverage | Passed locally | Complete KitchenKit suite passed with 8,452/8,452 executable business-logic lines covered; 118 live Apple-runtime adapter lines are explicitly excluded. |
| iOS application validation | Passed locally and in PR CI | The iPhone 17 Pro simulator app and UI plan completed in Xcode; the governed PR iOS Test action passed in 28m52s. |
| macOS application validation | Passed locally with runner exception and in PR CI | Local assertions completed before the known runner wedged fetching coverage profiles; the governed PR macOS Test action passed in 8m38s. |
| V4 Production schema preview and deployment | Passed | Development initialization and the additive Production deployment added only `CD_KitchenOwnershipRecord`, its generated indexes, and standard grants. No existing type or field changed. |
| Physical production-store stabilization | Passed locally | The patched Production build settled at one Kitchen and one ownership marker, remained at 0% CPU, and produced no further ownership-row churn across repeated delay. |
| Required merge build | Pending | The final 0.2.2 release commit must pass the protected `Merge to main` production build before tagging. |
| Tagged archives and notarization | Pending | The immutable tag must produce iOS and macOS archives and a notarized Mac product. |
| Installed notarized artifact | Pending | The tagged Mac artifact must pass signing, Gatekeeper, stapling, extraction, install, launch, reset, and Cooking Session checks. |
| GitHub release attachment | Pending | The verified notarized ZIP and checksum must be attached to the 0.2.2 prerelease before publication. |

Evidence remains bounded to synthetic identifiers, counts, and conclusions. It
must not retain or publish recipe content, CloudKit user record IDs, private
store paths, or raw production database material.
