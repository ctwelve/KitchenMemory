# 0.3 durable coverage audit

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

This is the focused [#121](https://github.com/ctwelve/KitchenMemory/issues/121)
audit after Recipe authority, local drafts, recovery, retention, maintenance,
Folders, Tags, and collection presentation landed. It also includes the reversible
sample-pack boundary from #88. The framework code/test checkpoint is `f425398`, based on
merged `main` commit `4ffd57d`. Application fixture correction `6611e6c` and
subsequent audit documentation do not change that measured framework source. Counts are a dated snapshot, not a promise about
future commits.

## Durable logic and persistence

The clean macOS run on September 6, 2026 passed **568 framework tests**. Xcode
26.6 (`17F113`) on macOS 26.6.2 produced these exact integer counts:

| Responsibility | Covered / executable lines | Files |
| --- | ---: | ---: |
| Domain | 4,317 / 4,317 | 48 |
| Import | 1,941 / 1,941 | 6 |
| Logic | 3,148 / 3,148 | 23 |
| Persistence, excluding the two runtime bridges below | 4,440 / 4,440 | 23 |
| **Durable gate** | **13,846 / 13,846** | **100** |
| Apple runtime bridges, reported separately | 94 / 130 | 2 |

The persistence row includes the real SwiftData repository implementations run
against disposable in-memory containers. It is not omitted from the durable
gate. No new exclusions were introduced. The two existing whole-file exclusions
are enumerated by source responsibility under ADR 0007:

| Source | Observed lines | Responsibility outside the deterministic gate |
| --- | ---: | --- |
| `KitchenKit/Persistence/Cloud/CloudKitKitchenOwnerIDResolver.swift` | 3 / 13 | Real CKContainer account query; opaque account identity mapping remains deterministically tested. |
| `KitchenKit/Persistence/Cloud/PersonalCloudStatusMonitor.swift` | 91 / 117 | Real account status and Core Data CloudKit event delivery, including an Apple event type without a public initializer. Deterministic status reduction, stale-result rejection and notification scheduling have focused tests. |

These exemptions account for 130 executable lines, of which 36 were not reached
in this run. They are not blanket exclusions for Persistence or Cloud; the other
cloud-facing responsibilities remain in the exact gate. Expanding either file
with new product policy requires moving that policy into a deterministic seam,
not silently benefiting from its path exemption.

## Behavioral evidence

Exact line coverage is not branch coverage or proof of all possible histories.
The following deterministic suites supply the adversarial and preservation
checks behind the measured lines. Paths below are relative to `KitchenKitTests`.

| Boundary | Representative suites and adversarial evidence |
| --- | --- |
| Immutable save and authority projection | `Domain/RecipeAuthorityProjectorFailureTests.swift`, `Persistence/SwiftDataRecipeAuthoritySaveTests.swift`, `Persistence/SwiftDataRecipeAuthorityFailureTests.swift`: missing evidence, codec/digest failures, identity collisions, cross-Recipe ownership and immutable-payload rejection. |
| Local drafts and import handoff | `Logic/RecipeDraftFailureTests.swift`, `RecipeDraftPublicationTests.swift`, `RecipeDraftCompatibilityTests.swift`, `RecipeImportSessionTests.swift`: failed local persistence, retained publication identity, retries, relaunch compatibility and staging before publication. |
| Competing revisions and reconciliation | `Logic/RecipeReconciliationTests.swift`, `Persistence/SwiftDataRecipeRepositoryReconciliationTests.swift`: competing selection evidence, parent validation, conflict resolution and rejected acceptance. |
| Delete, restore and prune | `Logic/RecipeDispositionTests.swift`, `RecipeRetentionTests.swift`, `RecipeRetentionEvidenceTests.swift`: unavailable and conflicting authority, late child-only delivery, shared section dependencies, retention deadlines and deterministic expiration/restoration history. |
| Maintenance and interruption | `Logic/RecordsMaintenanceTests.swift`, `Persistence/RecordsMaintenanceRepositoryTests.swift`: cancellation, resumed cursors, failed candidates, clock correction, exact stale-observation boundary, malformed evidence and checkpoint reconstruction. Session evidence is preserved. |
| Folder hierarchy and checkpoints | `Logic/FolderReplicaTests.swift`, `FolderPolicyEdgeTests.swift`, `FolderCheckpointTests.swift`: reversed/rotated arrival, deep hierarchy, cycles, duplicate identities, invalid causality, retained receipts and late retries. |
| Tag observed removal and aliases | `Logic/TagReplicaTests.swift`, `TagPartialRemovalTests.swift`, `Persistence/TagAssignmentPersistenceTests.swift`: every arrival prefix, completed permutations, opposite concurrent merges, partial evidence, compaction and observed removal. |
| Organization authoring and collection | `Logic/RecipeOrganizationTests.swift`, `RecipeOrganizationDraftTests.swift`, `Persistence/RecipeOrganizationRepositoryTests.swift`: staged organization, atomic first-save acceptance, rejected batches, collisions, filtering and stable selection. Hosted `RecipeOrganizationModelTests` covers presentation restoration and explicit retry. |
| Reversible samples | `Persistence/SamplePackRepositoryTests.swift`, `Logic/SamplePackLibraryTests.swift`: rollback, localized matching, both concurrent-name arrival orders, edited and late-edited preservation, ordinary restoration, repeated reads, incomplete remote evidence and request ownership. Hosted `SamplePackSettingsTests` covers failure → refresh → same-identity retry and reset retirement. |
| Seeded properties | `Support/PropertyTestSeeds.json`, `Domain/PropertyTestHarnessTests.swift`, Session evidence/deletion property suites and scaling property suites: named seeds, reproducible generated corpora and a pinned harness vector. |

Fixtures use synthetic Kitchens, controlled evidence arrival, injected failures,
and explicit dates for decisions about time. No acceptance claim depends on
private Recipe content, live CloudKit completion, translated wording, or sleeping
until a retention boundary passes. Generated UUIDs identify independent fixtures;
ordering assertions derive the expected ordering from those identities.

## Application evidence and remaining gaps

Both final native runs used Xcode's own Test action on application checkpoint
`6611e6c`: **175/175 on My Mac** (170 hosted, 5 UI smoke) and **173/173 on
an iPhone 17 Pro Max simulator, iOS 26.5** (168 hosted, 5 UI smoke), with no
skips or expected failures. The Mac audit temporarily enabled coverage in the
local plan; the plan was restored byte-for-byte afterward.

| Mac application responsibility | Covered / executable lines | Files |
| --- | ---: | ---: |
| Composition | 1,109 / 1,398 | 14 |
| Features, including presentation models and views | 5,488 / 13,469 | 64 |
| PlatformAdapters | 213 / 310 | 4 |
| Resources | 89 / 143 | 2 |
| SharedPresentation | 5 / 53 | 1 |
| **Application checkout sources** | **6,904 / 15,373** | **85** |

These are diagnostic counts, not an application percentage gate. No generated
or outside-checkout files appeared in this application target's file inventory;
package, framework, and test targets were not added to its denominator. The
hosted run reached only 10,165/13,976 raw KitchenKit lines, further demonstrating
why it cannot substitute for the separate complete framework run.

The largest visible presentation gaps include `RecipeQuantityEditorViews.swift`
(0/666), `CookingSessionView.swift` (0/561), `RecipeURLImportView.swift` (0/502),
and `RecipeReconciliationView.swift` (0/423). Their underlying quantity, Session,
import and reconciliation behavior is exercised through framework and hosted
seams; the current smoke suite deliberately does not automate those feature
workflows. PlatformAdapters still has 97 unexecuted lines in this Mac snapshot;
that gap remains visible and is not described as covered by the durable result.
Its file breakdown is `StartupFrameObserver.swift` 52/55,
`KitchenOwnerIdentity.swift` 5/30, `AppStoreRefresh.swift` 16/42, and
`AppRecordsMaintenance.swift` 140/183. Presentation orchestration also remains
partial: `RecipeLibraryModel.swift` is 232/269 and `AppRuntime.swift` is 308/335.
These are visible follow-up seams, not part of the exact KitchenKit claim.

The first iPhone run exposed a fixture coupling: executing the full sample-pack
installation during shell setup added Folder/Tag rows and pushed Recipe links
outside the lazy accessibility viewport. The fixture now seeds only Recipes,
while dedicated hosted tests start empty and explicitly install the full pack.
The corrected iPhone run passed all five smoke tests. No scrolling scripts,
weakened assertions, or additional durable exclusions were introduced.

Local bundles:

- Mac audit: `Test-KitchenMemory-2026.09.06_22-23-07--0500.xcresult`.
- iPhone correctness: `Test-KitchenMemory-2026.09.06_22-19-42--0500.xcresult`.

Both were emitted under Xcode DerivedData's `Logs/Test` directory. As with the
framework artifact, reproduce these rather than relying on temporary build
output remaining on the original machine.

The UI smoke target establishes accessible top-level structure and navigation.
It does not claim feature workflow, focus order, VoiceOver usability, Dynamic Type,
or comprehensive assistive-technology coverage. Those boundaries remain in
[ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md) and #132.
Xcode Cloud UI execution remains parked under #155; local Xcode runs supply UI
runner evidence. Actual CloudKit transport and multi-device timing require their
separate acceptance workflow.

## Reproduce and interpret

Run `Tools/run-core-framework-coverage.sh` from the checkout. It creates a fresh,
isolated DerivedData directory, tests the complete `KitchenKit` scheme with
coverage, and then invokes `Tools/check-core-framework-coverage.sh` against its
result bundle. Do not edit framework sources, tests, project membership or
resolved packages during the run. The checker rejects missing targets, uncovered
durable lines, and source inputs newer than the bundle's build start.

For this audit, the bundle was
`/private/tmp/KitchenMemoryCoreCoverage.YbxkFX/Tests.xcresult`. It is local build
evidence and is not shipped or committed. Regenerate it on another machine;
temporary-directory survival is not part of the contract. Inspect its raw integer
report with `xcrun xccov view --report --json <bundle>` and group production files
by their `KitchenKit/Domain`, `Import`, `Logic`, and `Persistence` paths, removing
only the two exact runtime paths listed above from the durable subtotal.

The gate was observed rejecting the earlier sample-pack run with 17 uncovered
lines, then rejecting two remaining concurrent-name comparison closures. The
final run passed after behavioral tests exercised those cases. No denominator,
threshold, or exclusion was weakened to obtain a pass.

Native application and UI checks run through Xcode's Test action as described in
[the agent workflow](agents/xcode.md). Record platform, completed target counts,
and the result bundle separately from the standalone framework result. An app
percentage must never replace the durable gate.

For a separate application audit, temporarily set `defaultOptions.codeCoverage`
to `true` in the local `KitchenMemory.xctestplan`, then run the `KitchenMemory`
scheme's Test action in Xcode on My Mac. Export that completed bundle with
`xcrun xccov view --report --json <app-bundle>`. Restore the plan afterward:
ordinary hosted plans remain correctness gates without mandatory coverage
instrumentation. Group only checkout sources under `KitchenMemory/`; report
compiler-generated files separately and never fold test-target coverage into
application coverage. This Mac snapshot does not measure iOS-only code.
