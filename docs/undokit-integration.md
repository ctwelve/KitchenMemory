# UndoKit integration and consumer qualification

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

The historical consumer qualification in KitchenMemory [#236](https://github.com/ctwelve/KitchenMemory/issues/236) qualifies
the independently maintained **UndoKit 0.2.2** source package at revision
`9d04950fb314846e701890ac3095d28056820918`. That qualification does not implement production Recipe
undo or close the [delivery gate](https://github.com/ctwelve/KitchenMemory/issues/204).
The [accepted policy](adr/0022-shared-durable-undo-framework.md) continues to own
operation eligibility, lifecycle, scope and domain authority.

## Production foundation: #237

[#237](https://github.com/ctwelve/KitchenMemory/issues/237) adds durable Folder
history for moving one saved Recipe, including a move to Unfiled. A placement
no-op creates no history group or receipt. Tag changes and bulk moves remain
separate delivery work; this foundation does not close the app-wide #204 gate or
expand [ADR 0022's accepted policy](adr/0022-shared-durable-undo-framework.md).

KitchenKit owns the typed change, eligibility checks and compensation through
`RecipeOrganizationHistory` and `RecipeOrganizationHistoryRepository`. The
SwiftData adapter checks current Recipe, Folder and causal evidence inside the
same transaction that accepts the assignment and its complete-token receipt.
An exact retained receipt resolves an already accepted outcome before checking
later interference; recovery does not replay an accepted action.

### Persistence compatibility

The current SwiftData schema remains **V7**. Existing organization action records
carry two additive versioned namespaces: `organization-history-receipts-v1` and
`organization-history-recoveries-v1`. Their version-1 payloads contain the full
frozen delivery and outcome witness. The existing `organization-batches`
`BatchReceipt` format and ordinary organization pending-command format remain
unchanged. No existing schema declaration or receipt payload is repurposed.

Each local UndoKit history database has a separate
`History.sqlite.organization-pending.json` sidecar. Its version-1 envelope freezes
the scope, token, member, command, effect and inverse intent before host delivery;
it also retains a proved terminal inverse rejection. Retry uses that exact
frozen delivery. Missing receipts remain unresolved unless rejection is durably
proved. Recovering a rejected compensation uses the separate recovery receipt
namespace and retires actionable history instead of inventing Redo. Explicitly
discarding a proved rejected compensation retains current domain organization.
These local history files do not replace the authoritative SwiftData receipts.

### Scope and invalidation

The app registry retains local history under Application Support's
`RecipeOrganizationHistory`, scoped by owner, store, Kitchen and initiating logical
scene. Scene disconnection closes presentation without disposing eligible history;
explicit disposal writes a durable marker. Owner/store/Kitchen changes and reset
retire the prior generation, with an invalidation-intent marker blocking restoration
if the generation write fails.

Eligibility uses Recipe membership/deletion/restoration evidence and relevant
source/target Folder evidence. Interference conservatively clears the initiating
scope's actionable history when any retained anchor is ineligible; it does not
attempt to salvage unrelated groups within that scope. Domain acceptance repeats
the checks even if the presentation previously reported Undo available.

This section describes the working implementation, not completed #237 acceptance.
The dated #236 results below remain historical qualification evidence and do not
prove the production adapter, scene wiring or current test tree passed.

## Supply route and ownership

The maintainer approves either the Swift package or the available XCFramework.
This slice retains the source package: its exact pin is inspectable, it builds
with KitchenMemory's toolchain, and subsequent beta fixes can be qualified through
the existing resolver/inventory workflow. XCFramework availability is not a
blocker. Adopting that route later would require matching its binary resources,
signing and toolchain evidence; do not mix two UndoKit supply routes in one process.

The dynamic `UndoKit` package product links to KitchenKit. The application embeds
and signs it beside KitchenKit, rather than nesting it inside KitchenKit. The
Testing-only demonstrator and hosted test bundle also link that same product;
they do not add another source route or independently open its database.
`Package.resolved`, [the inventory](../DEPENDENCIES.md), SBOM and bundled notices
record the exact source and license. KitchenMemory's macOS/iOS 27 floors remain
unchanged. Source inspection and a build do not establish physical-device or
distribution signing acceptance.

The qualification host is compiled only with `TESTING`. Its native screen is
selected only by `--ui-testing --undo-qualification <UUID>`. It writes synthetic
collection values and receipts under `Application Support/UndoQualification/<UUID>`
in the disposable test app's container. Its UUID-only argument cannot select a
Kitchen database or arbitrary path. The screen's cleanup action closes its
history owner before removing that test directory. The UI tests retain the same
UUID across process termination and remove the successful fixture afterwards.
Failed runs can retain synthetic diagnostic files in this test-only directory.

UndoKit owns the local Core Data store, preparation, ordering, finalization,
retention, recovery and native binding mechanics. The host owns typed collection
meaning, guarded whole-group acceptance, inverse values and authoritative receipts.
The demonstration atomically replaces one JSON file containing domain values and
full-token receipts. That single-writer demonstration contract is not a new
Recipe repository, persisted organization format or production receipt design.
The production Folder foundation is described above; Tag and bulk compensation
remain separate work in #238–#239.

## Public integration contract

Declare one `HistoryOperation` per host family with versioned command/effect
codecs and a canonical sorted-key fingerprint. Retain its exact registration and
`HistorySessions` owner. Submit through the session's typed `HistoryCommands`;
do not recreate lookalike registrations per action. Persist complete
`HistoryToken` identity and member effects with domain acceptance. Outcome lookup
reloads authoritative receipts without repeating the action. A missing receipt
proves rejection only under this demonstrator's intact, exclusive single-writer
contract; production adapters must establish their own proof.

Native callbacks synchronously admit requests through the supplied UndoManager
facade. Domain work and finalization complete asynchronously; await
`waitForNativeOperations()` before observing completed state. Do not register
another reciprocal callback or claim the semantic inverse finishes inside the
native callback. AppKit/UIKit bindings preserve focused local text priority,
including refusal to fall through from an empty local stack to an older app action.

Install `session.setNativeActionNameResolver(_:)` to map retained host presentation
metadata to localized action names. Reinstall it after reopening or a language
change. The framework owns native label refresh; hosts retain meaning and
localization. The synthetic test stores an action identifier, resolves it to an
English label, then reopens with a French resolver without changing domain values.

The host must map each logical scene plus owner/store/Kitchen boundary to stable
history scope and working identities. Independent test windows use independent
stores and identities. Disconnecting a presentation does not dispose its history.
Explicit disposal adopts a coherent baseline and retires the generation; old
command handles must remain unusable. The tests prove the framework primitives,
not production account-change or scene-restoration wiring.

`maxUndoGroups: 100` limits actionable depth, not retained detail or disk bytes.
The separate consolidation proof creates a coherent host checkpoint and requests
`targetDetailedGroups: 100`. Production must coordinate checkpoint/resource
retention and handle protected material, capacity refusal and cleanup failures;
setting the depth alone does not satisfy the retention policy.

## Executable proofs

The native application plan includes:

- `UndoKitQualificationTests`: typed ordered identities, native Undo/Redo and
  reopening without replay, with host-resolved native action names.
- `UndoKitRecoveryQualificationTests`: accepted reply loss, durable authoritative
  recovery, unresolved outcomes remaining blocked, synchronous native admission
  before suspended host completion, and durable inverse rejection without false
  Redo or fallback to an older action.
- `UndoKitBoundaryQualificationTests`: all-or-nothing batch rejection, proved
  pre-write host failure, 100-group retention/depth, generation disposal and
  unreadable-store refusal without replacement, including attempts to reopen a
  retained store with a mismatched working identity or unknown scope.
- `UndoKitNativeRoutingTests`: local text priority, empty-local-stack isolation,
  independent windows and restored/disposed presentation history.
- `UndoKitRelaunchTests`: actual application termination/relaunch after finalized
  acceptance and after unacknowledged host acceptance, with duplicate-free recovery.

Run these through [Xcode's Test action](agents/xcode.md). The app/UI tests use
signed native hosts. Their synthetic control names are explicit localization
contract exceptions, compiled out of distributed builds; they are not the
shipping localized action-name proof.

## Qualification evidence, 2026-10-19

Toolchain: Xcode 27.1 (`27A9275`), Apple Swift 6.4. KitchenMemory's working slice
is 0.3.18. The following baseline used UndoKit 0.2.1; results for the updated
0.2.2 pin are recorded separately below.

| Check | Observed result |
| --- | --- |
| KitchenKit standalone clean workflow, native arm64 Mac, macOS 27.0.1 | 606 tests passed; 14,666/14,666 business-logic executable lines covered, with the existing 130 runtime-adapter exclusions; ordinary-consumer interface and 13 forbidden mutation routes passed |
| Native Mac Testing bundle inspection | KitchenKit links `@rpath/UndoKit.framework/Versions/A/UndoKit`; UndoKit is embedded beside KitchenKit in the app; its compiled Core Data model and privacy manifest are present in `UndoKit_UndoKit.bundle`; deep strict app signature verification and strict UndoKit verification pass with normal certificate-trust access |
| Full native Mac application plan, macOS 27.0.1 arm64 | 291/291 tests passed, no failures or skips, including all 14 qualification checks and both review-requested immediate-admission/mismatched-identity proofs; completed xcresult read directly after the bridge response timeout |
| iPhone SE (3rd generation) simulator, iOS 27.0 | Initial 12 checks passed across the first run and focused correction of the UIKit typing-group test; the test now leaves UIKit's private groups under UIKit's control |
| iPad (A16) simulator, iOS 27.0 | 11 passed; the unacknowledged-acceptance relaunch scenario stalled during simulator app launch and was explicitly stopped after the bridge's 300-second timeout; its retained result reports “Testing was canceled” |
| Review-ready CI, commit `55e69f28c83c2dccd26acf665db01f4901e4a103` | [All required lanes passed](https://github.com/ctwelve/KitchenMemory/actions/runs/39338571118): repository contracts, KitchenKit tests/coverage, both production builds and signed/native app/UI tests on Mac and iPhone simulator |
| Independent review | Standards policy finding resolved through ADR 0007's narrow process-lifecycle exception; spec proof-scope findings resolved by the two additional admission/identity checks, which passed in the full Mac run |

The full Mac result also reports six internal QoS-inversion runtime warnings;
it is not a warning-free performance qualification. Local native builds included the
maintainer's approved icon scale adjustment, now committed in this slice. These
local results do not replace required review-ready CI on the final committed tree. No physical device,
distribution archive, human assistive-technology walkthrough or actual history
SQLite write-fault result is claimed. An iOS-device product build remains separate
from simulator qualification. The incomplete iPad run is not a pass.

## UndoKit 0.2.2 update

[UndoKit #73](https://github.com/Folio-Suite/UndoKit/issues/73) is fixed by the
0.2.2 ordinary-session resolver. The consumer regression check first failed on
0.2.1 with empty native names at submission, Undo, Redo and reopen. The source
pin and inventory now select the published 0.2.2 revision above. Its package
manifest, license and privacy declaration are unchanged from 0.2.1. The
strengthened native Mac roundtrip check passed on 0.2.2, including the
English Undo/Redo names and French name after reopening. Independent standards
and spec reviews found no concrete defects in this update. Full updated-tree
checks remain required before merge. This resolves the upstream API
gap; it does not establish shipping KitchenMemory translations or human menu
acceptance.

| Updated 0.2.2 check | Observed result |
| --- | --- |
| Signed native Mac application plan | 291/291 passed, zero failures/skips; the name regression also passed again after extracting its shared metadata lookup |
| KitchenKit standalone clean workflow | 606 passed; 14,666/14,666 business-logic lines covered; consumer-interface and forbidden-route checks passed |
| Repository contracts, scoped pinned SwiftLint and diff whitespace | Passed |
| Independent standards/spec review | Clear for the 0.2.2 delta |

These updated local results do not replace review-ready CI on the final commit.

## Bounded acceptance, 2026-10-21

### Agreed scope

The maintainer selected recovery between two individually atomic stores as the
remaining persistence proof: the host may have accepted an action while history
has not finalized it. Power-loss simulation and lower-level SQLite write-fault
qualification are not required for this consumer gate. The accepted-reply-loss
scenario creates that committed-host/unresolved-history mismatch and proves
recovery by the exact durable receipt, without replay, across repeated reopening.
Existing refusal tests cover unreadable history and mismatched identities;
pre-effect rejection proves the host stays untouched.

The maintainer waived physical-iPad and hardware-keyboard acceptance because the
iPad is unavailable and no hardware keyboard is available. Jeeves IV is the
available iPhone 16 Pro Max on iOS 27.0.1. These waivers do not claim those checks
passed. The maintainer subsequently confirmed that touch gestures and VoiceOver
both worked on Jeeves IV. Mac native menu routing and accessible names/focus
were checked through the actual application UI.

The 2026-10-21 Xcode `Develop` build for **Any iOS Device (arm64)** succeeded
with the pinned 0.2.2 package. The app retains its iOS 27.0 minimum; KitchenKit
links `@rpath/UndoKit.framework/UndoKit`, embedded beside it in the app.
`UndoKit_UndoKit.bundle` contains the compiled `History.momd` and privacy manifest.
Deep strict app signature verification passed with normal certificate-trust
access.

### Completed evidence

| Check | Observed result |
| --- | --- |
| Physical iPhone 16 Pro Max, iOS 27.0.1, signed Xcode qualification checks | 13/14 initially passed; the new recovery assertion incorrectly equated an unresolved durable outcome with active admission (`snapshot.hasPending`). After asserting the documented suspended session status instead, the focused recovery rerun passed 1/1, including exact receipt identity and duplicate-free repeated reopening |
| Full signed native Mac application plan | 290/291 passed; the existing `testAttentionEvidenceExposesAccessibleRecoveryNavigation` UI check failed once and passed its focused rerun 1/1. All UndoKit qualification checks passed in the full run. The result also recorded eight internal QoS-inversion warnings |
| Final Mac qualification checks after the responder correction | 14/14 passed, zero failures/skips, including native routing, recovery and both application relaunch scenarios |
| Actual Mac Edit menu, Testing host | Apply produced `Bread, Soup; accepted: 1`; Edit > Undo produced `Soup, Bread; accepted: 2`; Edit > Redo produced `Bread, Soup; accepted: 3`. Native menu availability changed correctly and focus stayed on Collection history. The Mac fixture uses a focusable responder forwarding to the existing facade because read-only NSTextView editing validation disables its Undo menu |
| Human iPhone acceptance | Maintainer confirmed gestures and VoiceOver both worked; exact walkthrough order was not required |
| Repository contracts, scoped pinned SwiftLint, independent standards/spec review | Passed; both review axes reported zero findings, including the final Mac responder change |

### Short native walkthrough

Use the Testing app's qualification screen with the same disposable UUID across
relaunches (`--ui-testing --undo-qualification <UUID>`):

1. Apply once: the state becomes `Bread, Soup; accepted: 1`.
2. Focus **Collection history**. On Mac use Edit > Undo and Edit > Redo; on
   iPhone use the system three-finger Undo/Redo gestures. Undo restores
   `Soup, Bread; accepted: 2`; Redo returns `Bread, Soup; accepted: 3`.
3. Relaunch with the same UUID. The values and available history survive; a
   relaunch alone must not increment the accepted count.
4. With VoiceOver, reach and activate Apply/Undo/Redo and read the state. Check
   that names, availability and focus make the action and result understandable.
5. Select **Remove test files** when finished. Record platform, observations and
   any refusal or unexpected focus change in #236.

The follow-up [PR #271](https://github.com/ctwelve/KitchenMemory/pull/271) records
this bounded acceptance and closes #236 when integrated. Required CI still
applies to that PR's final tree. Comprehensive beta accessibility remains
[#168](https://github.com/ctwelve/KitchenMemory/issues/168). Qualification does not
expand the approved operation matrix, change production domain schemas, implement
production Recipe undo or authorize a KitchenMemory release.
