# 0.2 release evidence

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Slice 19 acceptance complete
- Candidate version: 0.2.0
- Evidence opened: 2026-08-30
- Slice 19 implementation source:
  `daaef9e897cc7a6ed966e686f6e748445bfc8916`
- Slice 19 exact-evidence source:
  `6056a425505c78827415ea282c7e586369c9fbab`
- Slice 19 reviewed harness source:
  `ea1b13fad07d955fe954b9590220b291cf26942d`
- CloudKit environment: Development only
- Production environment: Untouched

This ledger records the signed managed-CloudKit evidence for Slice 19 and the
remaining 0.2 acceptance work. A **Passed** result means the named receiving
store contained the exact expected domain-evidence multiset and row content;
framework operation success, account availability, notification delivery, and
record counts are never substitutes. **Pending** means no completion claim has
been made. A later behavior change invalidates the affected result.

The fixtures are synthetic. Committed conclusions omit account identifiers,
device identifiers, store paths, raw logs, database contents, and authored
private material. Disposable stores and build products remain local.

## Environment

| Component | Recorded environment |
| --- | --- |
| Mac | Apple-silicon MacBook Pro, macOS 26.6.2 (25G83) |
| iPhone | iPhone 16 Pro Max, iOS 26.6.1 (23G83) |
| Xcode | 26.6 (17F113) |
| Swift | Apple Swift 6.3.3 (`swiftlang-6.3.3.1.3`, Clang 2100.1.1.101) |
| macOS SDK | 26.5 |
| iOS SDK | 26.5 |
| Signing | Apple Development; separate Mac and iOS acceptance harnesses |
| Cloud container | Development container selected by the signed Develop configuration |

The separate harness is excluded from the Kitchen Memory project, schemes,
archives, and Production products. Its wrapper refuses non-Development
container configuration and stores outside an explicit disposable root.

## Automated implementation proof

| Evidence | Source state | Result | Record |
| --- | --- | --- | --- |
| KitchenKit exact coverage | `daaef9e` | Passed | 8,284/8,284 executable lines; 105 documented Apple-runtime adapter lines excluded |
| Signed macOS application tests | `6056a42` | Passed | 113/113 tests on macOS 26.6.2 with Xcode 26.6; includes the remote-change callback, composition-root refresh, and ordinary, Deleted, Unavailable, and Recovery reclassification |
| Strict lint | `6056a42` | Passed | Xcode build-tool plugin completed without warnings across the affected signed build and test targets |
| Harness deterministic matrix | `ea1b13f` | Passed | E1, E2b, E3, E4a, E4b, E5, and E7 reconstructed the exact expected evidence multiset and row content; fresh stores exercised every partial, Deleted, first, and final checkpoint |
| Signed iOS harness build | `ea1b13f` | Passed | Development application built, signed, and installed on physical iPhone with the iOS 26.5 SDK |
| Signed iPhone execution | `ea1b13f` | Passed | A physical iPhone 16 Pro Max on iOS 26.6.1 reconstructed exact E3 evidence in foreground, non-activated background, and terminated-then-relaunch phases |
| Standards and issue-spec reviews | `ea1b13f` | Passed | Both independent reviewers returned `CLEAN` after the typed scenario plan and complete intermediate-checkpoint matrix were added |

## Managed CloudKit transport

Every completed row used independent signed stores and a clean receiving store.
Scenarios with meaningful reconnect order were repeated in both orders. A
checkpoint passed only after reconstructing the expected domain evidence from
the receiving store.

| Scenario | Source state | Result | Receiving-store conclusion |
| --- | --- | --- | --- |
| E1 logical duplicate identity | `daaef9e` | Passed | Both orders retained both physical duplicate roots; identical content coalesced and the conflicting logical identity entered Recovery. |
| E2b independent immutable inserts | `daaef9e` | Passed | Both orders retained both Facts and reconstructed the same ordinary Stopped Session. |
| E3 terminated and relaunched | `ea1b13f` | Passed | A clean physical-iPhone receiver launched after sender export and reconstructed the exact root as an ordinary Active Session; notification timing was not treated as authority. |
| E3 foreground notification and import | `ea1b13f` | Passed | A clean physical-iPhone receiver was foreground-active before server arrival, observed persistent-store remote-change callbacks, and reconstructed the exact root and ordinary Active projection. |
| E3 background notification and import | `ea1b13f` | Passed | A clean physical-iPhone receiver launched without foreground activation, observed persistent-store remote-change callbacks, and reconstructed the exact root and ordinary Active projection. |
| E4a multi-record offline export | `daaef9e` | Passed | Both orders retained the root, Fact, Closure, Delete, and Restore. The partial prefix was Unavailable; the complete graph reconstructed the restored Finished Session. |
| E4b local-only reconnection | `daaef9e` | Passed | Both orders converged the local-only and cloud Facts without treating either replica as an authoritative backup. |
| E5 deletion transport | `daaef9e` | Passed | Both orders retained Delete, the independent offline Fact, Restore, and repeated disposition evidence; Deleted and restored checkpoints matched exactly without cascade or silent resurrection. |
| E5 clean third store | `daaef9e` | Passed | A fresh receiver imported server truth and rebuilt the same ordinary, Deleted, and Recovery classifications. |
| E7 event observability | `daaef9e` | Passed | A later export followed an earlier successful operation; only the clean receiver's exact evidence established receipt. |

Transport output is deliberately bounded to synthetic run and scenario
identifiers, classifications, row counts, short digests, operation counts, and
conclusions. The pass oracle compares complete in-memory evidence before
emitting that bounded summary.

## Generated and server schema

The V3 schema fixture is the frozen five-record family in
[the Cooking Session V3 persistence contract](cooking-session-v3-schema.md):
`CookingSessionRecord`, `SessionFactRecord`, `SessionClosureRecord`,
`SessionDeletionRecord`, and `SessionDeletionResolutionRecord`.

| Review | Source state | Result | Conclusion |
| --- | --- | --- | --- |
| Generated SwiftData model | `6056a42` | Passed | Exactly five entities; required attributes have declaration defaults; only the paired continuation source, optional Fact target, and paired Outcome fields are optional. |
| Relationships and constraints | `6056a42` | Passed | Zero relationships, uniqueness constraints, and external-storage attributes. |
| Encryption declaration | `6056a42` | Passed | No optional CloudKit field-level encryption requested, matching the frozen V3 decision. |
| Development initialization | `daaef9e` | Passed | The additive schema initialized through the separate signed harness. |
| CloudKit Console record types and fields | `ea1b13f` | Passed | Development contains the five expected `CD_` Session record types and every generated domain field. Remaining fields are normal managed-store metadata, move-receipt, and asset-companion fields. |
| CloudKit Console indexes | `ea1b13f` | Passed | Generated single-field indexes are present on all five types: Cooking Session 31, Fact 32, Closure 32, Deletion 24, and Deletion Resolution 23 queryable, searchable, or sortable entries in total. No custom compound index is required for correctness. |
| CloudKit Console security roles | `ea1b13f` | Passed | The five types use the standard managed private-database grants: `_world` Read, `_icloud` Create, and `_creator` Write. No custom role exists. |
| CloudKit Console encryption state | `ea1b13f` | Passed | No V3 field is marked encrypted, matching the frozen decision not to request optional field-level encryption. |
| Later Production runbook | `ea1b13f` | Passed | The bounded additive review, preview, abort, deliberate deployment, and post-deployment verification procedure is recorded in personal iCloud synchronization. |
| Production deployment | — | Not run | Slice 19 does not authorize or perform Production schema changes. |

## Open Slice 19 evidence

No Slice 19 evidence remains open. The read-only CloudKit Console review,
signed physical-iPhone E3 phases, and independent Standards and issue-spec
reviews are complete. Production schema initialization, preview, and deployment
remain deliberately outside this slice.

No iPad claim belongs to Slice 19. The iPad remains part of the final physical
product walkthrough defined by [the 0.2 acceptance contract](acceptance-0.2.md).
