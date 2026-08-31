# 0.2 release evidence

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Slice 19 acceptance in progress
- Candidate version: 0.2.0
- Evidence opened: 2026-08-30
- Slice 19 implementation source:
  `daaef9e897cc7a6ed966e686f6e748445bfc8916`
- Slice 19 exact-evidence source:
  `6056a425505c78827415ea282c7e586369c9fbab`
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
| Harness deterministic matrix | `6056a42` | Passed | E1, E2b, E3, E4a, E4b, E5, and E7 reconstructed the exact expected evidence multiset and row content |
| Signed iOS harness build | `6056a42` | Passed | Development application built and signed for physical iPhone with the iOS 26.5 SDK |
| Signed iPhone execution | `6056a42` | Pending | Build is ready; installation and exact receiving-store conclusion remain to be recorded on the unlocked physical device |

## Managed CloudKit transport

Every completed row used independent signed stores and a clean receiving store.
Scenarios with meaningful reconnect order were repeated in both orders. A
checkpoint passed only after reconstructing the expected domain evidence from
the receiving store.

| Scenario | Source state | Result | Receiving-store conclusion |
| --- | --- | --- | --- |
| E1 logical duplicate identity | `daaef9e` | Passed | Both orders retained both physical duplicate roots; identical content coalesced and the conflicting logical identity entered Recovery. |
| E2b independent immutable inserts | `daaef9e` | Passed | Both orders retained both Facts and reconstructed the same ordinary Stopped Session. |
| E3 terminated and relaunched | `6056a42` | Passed | A clean receiver launched after sender export and reconstructed the exact root as an ordinary Active Session without requiring a new notification. |
| E3 foreground notification and import | `6056a42` | Pending | The signed Mac attempt timed out without a content mismatch; a timeout is inconclusive. Physical-iPhone execution remains required. |
| E3 background notification and import | `6056a42` | Pending | Physical-iPhone execution remains required. |
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
| CloudKit Console record types and fields | `6056a42` | Pending | Read-only Development review remains to be recorded. |
| CloudKit Console indexes and standard security roles | `6056a42` | Pending | Read-only Development review remains to be recorded. |
| Production deployment | — | Not run | Slice 19 does not authorize or perform Production schema changes. |

## Open Slice 19 evidence

Slice 19 remains open until all three items below have a recorded conclusion:

- signed physical-iPhone E3 foreground, background, and relaunch receiving-store
  evidence;
- read-only CloudKit Console review of Development fields, indexes, security
  roles, and encryption state; and
- clean Standards and issue-spec reviews of the complete branch diff.

No iPad claim belongs to Slice 19. The iPad remains part of the final physical
product walkthrough defined by [the 0.2 acceptance contract](acceptance-0.2.md).
