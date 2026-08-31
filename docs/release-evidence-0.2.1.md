# 0.2.1 release evidence

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: candidate validation in progress
- Candidate version: 0.2.1
- Evidence opened: 2026-08-31
- Accepted release source: pending
- Immutable release tag: `release/0.2.1` pending
- Production environment: V4 deployed 2026-08-31

This patch release repairs the 0.2.0 production-library collision in which a
legacy Kitchen and the deterministic personal Kitchen could retain physical
rows for the same stable sample identities. Reset then rejected those recipes
as belonging to another Kitchen, and Cooking Session start could resolve the
wrong physical owner.

## Required evidence

| Gate | Result | Bounded record |
| --- | --- | --- |
| Synthetic cross-Kitchen regression | Passed locally | Owner-guarded convergence leaves one personal Kitchen; reset and Cooking Session start both succeed. |
| Different-owner preservation | Passed locally | Explicitly different ownership stops convergence without mutating the foreign Kitchen. |
| V1/V2/V3 to V4 migration | Passed locally | All historical stores remain readable; V3-to-V4 preserves content without inventing an owner, and V4 adds only Kitchen ownership evidence. |
| Exact KitchenKit coverage | Passed locally | Complete KitchenKit suite passed with 8,433/8,433 executable business-logic lines covered; 118 live Apple-runtime adapter lines are explicitly excluded. |
| iOS and macOS application validation | Passed locally | macOS 26.6.2: 134/134 tests, including 17 UI smokes. iPhone 17 Pro simulator on iOS 26.5: 133/133 tests, including 16 UI smokes. |
| V4 Production schema preview and deployment | Passed | Development initialization succeeded for candidate `a3e96fd`. Apple's deployment diff contained one additive `CD_KitchenOwnershipRecord` type, its generated 14 indexes, and the standard `_creator`, `_icloud`, and `_world` grants; no existing type or field changes. CloudKit Console confirmed deployment and recorded the five expected Production history entries on 2026-08-31. |
| Physical 0.2.0 production-store repair | Pending | The installed candidate must converge the diagnosed store, reset successfully, and start a Cooking Session. |
| Notarized macOS artifact | Pending | The tagged artifact must pass signing, Gatekeeper, stapling, extraction, install, and launch checks. |
| GitHub release attachment | Pending | The verified notarized ZIP and checksum must be attached to the 0.2.1 prerelease. |

Evidence remains bounded to synthetic identifiers, counts, and conclusions. It
must not retain or publish recipe content, CloudKit user record IDs, private
store paths, or raw production database material.
