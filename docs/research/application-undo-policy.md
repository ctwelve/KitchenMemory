# Application-operation undo and redo proposal

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Date: 2026-09-25 (America/Chicago). Source baseline: `40a8b54`, after #234.
Status: **policy agreed on 2026-09-25; implementation and proofs remain pending**.
Origin: [#191](https://github.com/ctwelve/KitchenMemory/issues/191).
Delivery gate: [#204](https://github.com/ctwelve/KitchenMemory/issues/204).

This record delivers the operation inventory, native-facility evaluation, paper
failure exercises, agreed first slice, and implementation-ticket drafts. The
maintainer accepted all eight policy decisions, then amended the memory-only
lifetime to durable history and selected a shared UndoKit framework backed by
local Core Data. [ADR 0022](../adr/0022-shared-durable-undo-framework.md) records
that agreement and governs implementation. This change adds no undo behavior or
persistence format. Merging it does not satisfy #204.

Review path: [operation matrix](#operation-matrix),
[framework fit](#data-structures-and-helper-framework-fit),
[failure traces](#paper-exercises-and-expected-outcomes),
[decisions](#agreed-decisions), and
[ticket drafts](#proposed-implementation-tickets).

## Recommendation

Start with **Move Recipes, Add Tag, and Remove Tag on already saved Recipes**,
including a selected batch. They have concrete native menu names, existing
semantic commands, and one local domain transaction. First prove durable history
recovery and native routing; then add conditional compensation at the organization
storage seam. The separate history database introduces a recovery boundary, not
an atomic transaction spanning both stores. Do not offer undo merely by calling
the opposite menu action with whatever state happens to be current.

The proposed next waves are local structured draft/media edits, Recipe
Save/Selection and disposition, and eligible Active Session activity. Keep native
text undo working throughout. Start, Finish, Continuation, organization merges,
pruning, and Kitchen reset are not automatically reversible just because a button
has an apparent opposite. Their treatment is explicit in the matrix.

## Verified implementation inventory

The following are current source observations, not evidence that app-operation
undo already works. The source scan found native text undo integration but no
application-operation `registerUndo` calls in `KitchenMemory` or `KitchenKit`.

| Seam and source | Existing guarantee and consequence for undo |
| --- | --- |
| [NativeIngredientText](../../KitchenMemory/Features/RecipeLibrary/NativeIngredientText.swift), [IngredientTextCoordinator](../../KitchenMemory/Features/RecipeLibrary/IngredientTextCoordinator.swift), [RecipeIngredientTextEditing](../../KitchenKit/Logic/RecipeIngredientTextEditing.swift) | #188 routes text and `# ` heading edits through native controls with matching identity history. History is transient; replacement and teardown currently call `removeAllActions()` on the text manager. Sharing that manager with app operations without proving isolation could erase their history. |
| [RecipeEditingDraft](../../KitchenKit/Logic/RecipeEditingDraft.swift), [RecipeDrafts](../../KitchenKit/Logic/RecipeDrafts.swift) | Drafts own local contents and recovery. Ordinary edits can remain live after a failed persistence attempt; leaving is vetoed. Save freezes a command before publication; publication can succeed while draft cleanup fails. Frozen drafts reject edits. |
| [RecipeLibrary](../../KitchenKit/Logic/RecipeLibrary.swift), [RecipeRepository](../../KitchenKit/Persistence/RecipeRepository.swift), [ADR 0017](../adr/0017-use-additive-recipe-authority-evidence.md) | Save and Selection append immutable authority. `select` exists at the repository seam, but there is no app-level undo-selection operation. Selecting an earlier Revision must not delete a Save or manipulate a mutable current pointer. |
| [RecipeOrganization](../../KitchenKit/Domain/RecipeOrganization.swift), [organization repository](../../KitchenKit/Persistence/RecipeOrganizationRepository.swift), [organization presentation](../../KitchenMemory/Features/RecipeLibrary/RecipeOrganizationModel.swift) | A prepared batch carries stable identities; a fresh local transaction accepts all members or none. A failed command remains available for exact retry. There is no undo-specific compare-and-accept precondition or accepted-operation history. |
| [Folder projection](../../KitchenKit/Domain/FolderProjection.swift), [Tag projection](../../KitchenKit/Domain/TagProjection.swift), [Tag preparation](../../KitchenKit/Domain/TagLibrary.swift) | Folder placement is a causal register. Tags use observed assignment identities: Remove Tag removes the assignments observed when prepared. Deletion and aliases/merges have no restore/unmerge operation. Visible membership alone does not prove no intervening change occurred. |
| [Recipe disposition](../recipe-disposition.md), [retention](../recipe-retention.md) | Restore resolves observed deletions; another deletion can keep a Recipe hidden. Pruned identities cannot be restored. Recovery copies content into a new draft and eventually a new Recipe. |
| [Sample pack](../sample-pack.md) | Enable/disable is an atomic semantic request with receipts and preservation rules, not a snapshot toggle. Disabling preserves edited samples; enabling may create organization or restore only eligible samples. An opposite request is not an exact inverse. |
| [CookingSessionDelivery](../../KitchenMemory/Features/CookingSession/CookingSessionDelivery.swift), [CookingSessions commands](../../KitchenKit/Logic/CookingSessions+Commands.swift), [Session disposition](../../KitchenKit/Logic/CookingSessions+Disposition.swift) | Delivery owns pending identities, ordered retry, accepted draft effects, and retirement. Acceptance differs from terminal retirement. New Facts append evidence; Finished Sessions cannot accept ordinary activity. Session restoration requires the observed deletion frontier. |
| [KitchenMemoryApp](../../KitchenMemory/Composition/KitchenMemoryApp.swift), [PreparedApp](../../KitchenMemory/Composition/PreparedApp.swift), [navigation](../../KitchenMemory/Composition/RecipeLibraryNavigation.swift) | Windows consume a shared prepared graph. Focus effects are window-specific; navigation can be vetoed by draft storage. A shared model cannot infer which window should receive an undo registration. |
| [CloudSyncSettings](../../KitchenMemory/Features/Settings/CloudSyncSettings.swift), [organization settings](../../KitchenMemory/Features/Settings/OrganizationSettingsSections.swift), [records maintenance](../records-maintenance.md) | Cloud preference changes apply to the next launch and reconnection needs confirmation. Local feature visibility differs from synchronized ordering/Unfiled/Untagged preferences. Maintenance and reset are separate destructive authorities. |

## Data structures and helper-framework fit

There are three different costs: native presentation, durable history bookkeeping,
and domain evidence validation. The [helper comparison](native-undo-facilities.md)
informed the agreed choice: a project-owned **UndoKit** framework using native
UndoManager integration and a small, local-only Core Data store. KitchenMemory
and Folio are independent consumers; their domain adapters retain validation and
acceptance. [ADR 0014](../adr/0014-prefer-native-capabilities-and-evidence-based-dependencies.md)
still permits focused helpers when they remove demonstrated complexity, but this
decision adds no third-party module.

| Work | First candidate | Boundary |
| --- | --- | --- |
| Native Undo/Redo routing, names and groups | Foundation UndoManager through UndoKit | Native callbacks are a live presentation of eligible semantic history. Do not serialize closures or execute historical commands merely to rebuild native availability. |
| Durable identities, reversal payloads, groups, cursor and recovery state | UndoKit-owned local Core Data store | Host supplies storage location and history policy; app adapters own domain payload meaning. Durable records are necessary for recovery, not a second authority for domain acceptance. Exact schema and migration remain U0 work. |
| Before/after placement, changed Recipe IDs and Tag assignment identities | Standard Dictionary/Set keyed by existing stable IDs | These are compensation data, not copied SwiftData objects or arbitrary whole-app snapshots. |
| Stable ordered identity collections | Existing Swift Collections OrderedCollections when order plus keyed access is actually needed | Preserve canonical identity ordering used in command digests; library insertion order is not a new authority rule. |
| Bounded FIFO pending delivery or worklist traversal | Existing DequeModule; existing HeapModule where priority is required | Reuse the shipped delivery/evidence machinery. Neither structure chooses an inverse or supplies transaction atomicity. |
| Collection differences and structural sharing | Standard CollectionDifference or a focused package only after draft/media profiling | An array diff does not encode authored precision, causality, lifecycle or delete/restore consent. Do not add persistent-tree complexity to a small group of IDs without measurements. |
| SwiftUI/AppKit/UIKit binding and responder adapters | UndoKit native integration with host adapters | A convenient binding wrapper is insufficient if it registers attempted writes before domain acceptance. The interface must also be usable by Folio's Cocoa/Objective-C applications. |

The repository already pins Collections 1.7.0 and Algorithms 1.2.1; this record
changes neither pins nor products. See the [inventory](../../DEPENDENCIES.md).
The first implementation spike must prove Core Data recovery, native callback
ordering, grouped failure behavior, and the two consumer boundaries. The
[storage investigation](durable-undo-storage.md) identifies platform constraints.
Framework packaging, implementation language, schema, retention mechanics and
public API remain design work; the framework decision does not preselect them.
A later helper adoption still needs the normal license, privacy, transitive
dependency, SBOM and signed-build review.

## Operation matrix

Classes: **N** native text history; **L** local semantic reversal; **C** new
compensating durable intention; **X** excluded from proposed Undo/Redo. “Later”
means a candidate needing its own implementation and acceptance, not shipped
support. Names below are proposed action names; localized resources supply the
native Undo/Redo labels rather than concatenating English prefixes.

| Operation | Class / proposed wave | Inverse, eligibility, and action name |
| --- | --- | --- |
| Typing, paste, cut, text deletion; ingredient `# ` conversion | N / existing #188 | Native control history plus ingredient semantic identities. Preserve current lifetime; no second snapshot registration. Other text controls need native evidence rather than an assumption of coverage. “Typing” and native editing names. |
| Ingredient/section add, remove, reorder; precision and interpretation choices | L / later draft wave | Identity-aware draft operation restoring only affected structure/proposal/precision. Do not replace the entire `RecipeEditSession` or override newer text. “Add Ingredient”, “Move Section”, “Change Ingredient Details”. |
| Instructions, Equipment, yield, duration and other nontext form changes | L / later draft wave | Restore affected values/identities in the same unfrozen draft; native typing stays N. “Move Instruction”, “Change Yield”. |
| Hero/gallery add, replace, remove, reorder; image descriptions | L / later draft wave | Retain exact prior media identity/order/bytes needed for local reversal; no reimport, download or metadata regeneration. Text descriptions use native text history where supplied. “Replace Image”, “Remove Image”, “Move Image”. See [media contract](../recipe-media.md). |
| New draft, staged import, accept import candidate, recovery draft | L / deferred | Membership/phase restoration needs captured local records and no frozen publication. Intake and Recovery retain their distinct meanings. No automatic reverse network request. “Accept Import” is a future candidate. |
| Close or resume draft; simple/advanced editor switch | X | Navigation/presentation, not content reversal. Close retains the draft. Mode changes still retire native ingredient history as documented. |
| Discard draft | X / proposed first policy | Keep explicit confirmation. Future undo-discard would retain private text/media after discard and needs an explicit retention/lifetime decision. Never reconstitute a frozen Save from a generic snapshot. |
| Save an existing Recipe Revision; select an existing Revision | C / later Recipe wave | New Selection choosing the prior accepted Revision, only when current authority still matches the expected frontier and content is available. The newer Revision remains retained. “Save Revision”, “Select Revision”. Redo appends another Selection, not the original Save again. |
| First Save / new Recipe | C / deferred | Possible inverse is ordinary Recipe deletion, not erasing identity/history. Initial Folder/Tag creation/assignment may be atomic with Save; do not promise undo removes shared organization. Needs a distinct “Create Recipe” policy. |
| Reconciliation choices before Save | L / later draft wave | Restore prior comparison choice and affected draft state without losing unchosen text. “Choose Revision” / “Choose Ingredients”. |
| Save reconciliation | C / deferred | Several prior Selection heads may have been competing; choosing an arbitrary parent is not an inverse. Require a policy for re-exposing comparison versus an explicit new Selection. |
| Delete / Restore Recipe | C / later disposition wave | Undo Delete resolves only that action's observed deletion; concurrent deletion can leave the Recipe hidden. Undo Restore adds a new Deletion after validating unchanged disposition. No resurrection of pruned payload. “Delete Recipe”, “Restore Recipe”. |
| Move saved Recipes to Folder or Unfiled | C / **first slice** | Capture each Recipe's prior placement; compensate in one batch after scope/target checks. Mixed original Folders must be restored individually. “Move Recipe” / “Move Recipes”. |
| Add / Remove Tag from saved Recipes | C / **first slice** | Capture which memberships actually changed and their evidence. Preserve pre-existing membership and concurrent assignment identities. New compensation identities for each undo/redo; no toggling current UI state. “Add Tag”, “Remove Tag”. |
| Rename Folder/Tag; reparent Folder; manual ordering | C / later organization wave | Restore prior value/anchor only if affected identities and expected evidence still match; validate cycles, missing anchors and aliases. “Rename Folder”, “Move Folder”, “Reorder Tags”. |
| Create Folder/Tag | C / deferred | Deleting it can affect later contents, descendants or users of the Tag. Only a separately agreed unused-identity policy could make this reversible. |
| Delete or merge Folder/Tag, including collision resolution | X / proposed policy | No restore/unmerge command today. New objects would have different identities and cannot honestly undo aliases or subtree deletion. Retain explicit confirmation and recovery vocabulary. |
| Synchronized organization ordering / Unfiled / Untagged settings | C / later organization wave | New policy command guarded against intervening choices. Distinct from local visibility. “Change Folder Order”, “Show Unfiled”. |
| Local Show Folders/Tags, expansion, search, selection, reading scale, privacy display | X / proposed policy | Keep explicit settings/navigation controls; exclude from content history. Search field text may have native text undo. Viewing a Recipe or changing a reading scale creates no authored inverse. |
| Cloud synchronization preference and reconnection consent | X | Explicit Settings action, including existing confirmation and relaunch. Undo cannot imply disconnection of the running store or withdraw already synchronized evidence. |
| Enable/disable Sample Pack; install missing samples | X / defer reconsideration | Use the existing explicit reversible pack workflow. An opposite setting may target different content and is not a complete undo receipt. |
| Start Cooking Session / Continue Finished Session | X / proposed policy | Stop or Delete remains an explicit different intention. No removal of the root, snapshot, lineage or copied Entry draft; no automatic “uncontinue”. |
| Stop / Resume Session | C / later Session wave, decision required | Opposite lifecycle Fact only with matching lifecycle/frontier and no intervening activity. “Stop Cooking”, “Resume Cooking”. Never infer cancellation from navigation. |
| Ingredient/instruction progress; working scale | C / later Session wave | Append resulting prior state/scale, only while Active with matching evidence and no blocking pending command. Do not remove original Facts or compound scaling. “Mark Ingredient”, “Complete Step”, “Change Cooking Scale”. |
| Unsubmitted Entry typing / target changes / discard | N or L / later Entry wave | Preserve native typing; identity-aware local target changes are candidates. Discard excluded initially like Recipe drafts. Fix known pending-submission text loss/duplication before adding Entry undo. |
| Submit / revise / retarget / withdraw Entry | C / deferred Entry wave | Submit may compensate with withdrawal; revision/retarget with a new Fact. Withdrawal has no general restore operation in the current command vocabulary. Define whether redo retains Entry identity before implementation; do not silently submit another Entry. |
| Set / clear Outcome | C / later Session wave | New Fact restoring previous optional value, only while Active and unchanged. “Set Outcome”, “Clear Outcome”. |
| Finish, Submit-and-Finish, copy/discard-and-Finish | X | Closure is immutable. Neither undo text nor undo a prior Fact may reopen or mutate a Finished Session. Keep explicit Continuation; clipboard side effects cannot be rolled back. |
| Delete / Restore Session | C / later disposition wave | Preserve lifecycle; new deletion/restoration with exact consent frontier. Already-restored retirement is not new domain acceptance and earns no fake inverse. |
| Choose competing Session Closure / resolve recovery | X / defer reconsideration | Explicit evidence resolution, not restoration of a mutable field. A generic inverse must not manufacture a Finished history. |
| Kitchen reset, pruning, orphan reclamation, ownership convergence, Cloud import | X | No Undo registration. Reset/owner/store boundaries invalidate affected history; pruning never recreates payload from an undo cache. External delivery is not a user's local action. |

## Proposed native integration and ownership

The [native-facilities investigation](native-undo-facilities.md) cites Apple API
contracts. `UndoManager` manages local invocation history, grouping, names, and
redo. It does not supply domain transactions, conflict policy, a durable journal,
or a success/failure acknowledgment for an undo handler.

UndoKit owns durable history storage and native-manager integration. Host adapters
supply semantic payloads, scope identity, eligibility, acceptance and recovery
evidence. KitchenKit continues to prepare/accept domain operations; its persistence
continues to own atomic domain acceptance.
Do not attach a SwiftData context's automatic object undo to the Recipe or Session
record graph: physical row reversal would bypass immutable authority and receipts.
UndoKit must not infer domain success from a Core Data save or from native stack
movement. It does not own a synchronized undo log or replace command delivery.
A future conditional organization operation is a deep extension of its existing
seam. Domain receipts remain authoritative when reconciling the separate stores.

The host chooses the database location: KitchenMemory uses app-local storage;
Folio can embed a separate history database inside each native document package.
Local-only means UndoKit does not synchronize its store through CloudKit. It does
not forbid Folio from carrying history with a saved or transferred document under
its own history/omission policy. A host must coordinate document saves, copies,
restoration and store closure; copying a live database filename alone is not a
document-save contract.

Folio's [accepted document-history contract](https://github.com/Folio-Suite/Folio/blob/main/docs/architecture/semantic-history-contract.md)
requires document-wide accepted-action ordering, branching history, checkpoints
and deliberate history omission. KitchenMemory's scene ownership, conservative
invalidation and 100-group limit are host policies, not framework-wide constants.
This KitchenMemory decision does not implement or amend Folio's contract.

Proposed flow for the first slice:

1. The initiating scene supplies its undo context explicitly to the operation
   adapter. Shared observable models do not retain a last-seen global manager.
2. Capture exact pre-state, changed Recipe IDs, and owner/store/Kitchen context;
   prepare one ordinary organization command. Before submitting an undoable
   mutation, durably prepare the recovery metadata needed to associate that exact
   command with its inverse. Existing pending retry remains the delivery path.
   A prepared journal record is not an accepted undo action. U0 must prove this
   handshake; a failed preparation must not start the mutation.
3. After confirmed local acceptance, capture its post-state/evidence and finalize
   its accepted history outcome durably, then expose one native inverse group
   with its localized action name. No-op members are absent from the reversal
   set. Retrying the same accepted identity cannot
   register twice. A later navigation veto does not revoke this acceptance.
4. Undo validates the current scope token and affected target eligibility inside
   the same local transaction that accepts a newly identified compensation. A
   view-level check followed by an unconditional write is insufficient. Return
   typed accepted, stale/ineligible, or failed status through the operation seam.
5. Only synchronous confirmed success registers the reciprocal action during
   the native undo callback; redo likewise authors a fresh compensation and
   registers its reciprocal. Exact retries retain the same compensation identity.
   Replaying the original command as redo would coalesce, not redo the operation.
   Each compensation also uses the durable preparation/finalization handshake.

These steps describe the required acceptance boundary, not a completed protocol.
Interruption between domain acceptance and history finalization must reconcile
the exact command outcome before enabling history. Reopening must recover the
same accepted group/cursor without duplicate compensation; an unproved outcome
blocks affected actions rather than guessing from visible values. Unknown schema,
failed migration or unreadable history must not silently become a fresh empty
store. U0 must specify recovery, error presentation and safe host behavior.

**Scope token proposal:** the first slice may conservatively compare the complete
observed organization evidence fingerprint, plus affected Recipe eligibility,
rather than invent fine-grained merge logic. This capability does not exist yet.
The adapter maintains one expected current token for its active scene timeline;
each successful forward/undo/redo operation updates it. Individual records keep
their prior/result values, not an immutable token that makes an older action
impossible to undo after its successor was compensated. Intervening changes from
another scene, an untracked same-scene operation, or external refresh invalidate
the timeline. Refresh immediately following the adapter's own accepted command
keeps the token only if no additional evidence appeared. A content-only local
Save need not invalidate organization history if Recipe eligibility is unchanged.
Fingerprint generation, receipt-first exact retries, and comparison/acceptance
must be specified and tested together. Compaction may conservatively invalidate
history; stale tokens must never be accepted because visible values happen to match.

Managed CloudKit can deliver after the transaction. The guard protects against
locally observed interference, not future remote delivery or a global lock.
Unknown concurrent evidence follows the existing organization convergence policy.
A later imported assignment is never silently absorbed into the compensation's
observed set. Conservative invalidation is preferable to claiming global undo.

### Native routing and lifetime proposal

- Maintain a scene-local app-operation timeline scoped to owner, store and Kitchen.
  Never undo an operation from another window just because it shares the graph.
  A relevant mutation in another scene invalidates this scene's app history.
- While a native text editor owns the responder chain, its manager handles text
  Undo/Redo. Do not double-register the same edit as an app operation. Outside
  text focus, app Undo/Redo resolves through the scene's semantic adapter. Menus,
  keyboard and mobile affordances must reach that same adapter.
- Before sharing any manager, prove the ingredient control's current teardown
  cannot clear app history. A dedicated text manager or proven target-specific
  cleanup is a prerequisite, not an assumed SwiftUI behavior. Do not change
  `groupsByEvent` globally on a manager also serving text controls.
- A future structured draft history belongs to that draft's identity and editing
  lifetime, not the visible list row. If a shared draft is edited from another
  scene, invalidate incompatible app records; do not overwrite its newer values.
  Save freeze, Discard, replacement, and editor retirement are history barriers.
- Persist eligible app-operation history in UndoKit's app-local Core Data store.
  Backgrounding, system scene disconnection, process termination, force-quit and
  ordinary relaunch do not themselves invalidate it. Restore the same logical
  scene's timeline only after validating owner/store/Kitchen identity, accepted
  outcomes and current eligibility. Never assign it to an unrelated new scene.
  U0/U1 must establish stable scene identity and restoration behavior.
- Explicit scene disposal, owner/store change, Kitchen reset and relevant
  interference invalidate affected history durably. Prepared-graph recreation
  for the same valid scope alone is not a history barrier. Clearing callbacks on
  teardown releases live references; it does not delete valid durable history.
  Native text history keeps its existing lifetime; this policy does not serialize
  native controls' text stacks or extend the deferred draft/media scope.
- One user command or atomic batch is one explicit app group. Do not coalesce
  across target identities, scenes, Save, lifecycle changes or external updates.
  A bulk compensation uses one callback for one atomic command, not one callback
  per Recipe. Native typing keeps native coalescing. Later sliders may coalesce only one
  continuous gesture; first-slice moves and Tag actions remain separate groups.
- New accepted user actions invalidate redo in their active app timeline. External
  changes create no inverse group. First-slice relevant external refresh invalidates
  both directions, even if that conservatively removes still-safe operations.
- Do not automatically navigate or move focus on undo. Update projections; present
  a concise result/refusal in the initiating scene. A separately chosen “Show”
  action uses ordinary navigation and its draft-preservation veto.

### Failure policy proposal

A native undo handler is synchronous and has no Boolean “put this group back”
contract. Do not start a `Task`, return, and pretend later acceptance happened
inside the original undo group. Proposed conservative policy:

- Preflight known ineligibility disables the action; execution rechecks it.
- A stale target or rejected inverse mutates no content, registers no redo, and
  durably invalidates app-operation history for that scope with an explanation.
  Do not fall through to an older action or retry using refreshed consent.
- A storage failure or ambiguous outcome retains the *exact* compensation at the
  existing pending-operation seam, blocks new operations there, and clears the
  app timeline durably. Existing explicit retry/discard rules apply; no rollback
  command is invented. If retry later proves acceptance, refresh content but begin a new
  app timeline. Do not claim the original native redo group survived.
- Ordinary process interruption is distinct from a reported failed inverse.
  Reconcile prepared/finalized history against the exact accepted-command evidence
  before restoring availability. Never blindly replay an old intention to rebuild
  history. A reported failure's invalidation must survive relaunch; if recording
  that invalidation fails, the recovery protocol must prevent the old timeline
  from becoming actionable until the outcome is resolved. Prove this boundary in U0.
- Clear only adapter-owned records on a shared manager. Native text actions must
  survive unrelated app failures. If target-specific removal or grouping cannot
  uphold that, separate the managers before shipping.

This costs actionable history after a reported inverse failure, but avoids losing
authored content or showing false redo. Durable recovery from process interruption
is required; preserving the original native group after reported asynchronous
failure is not promised for the first slice.

## Paper exercises and expected outcomes

These are design traces against the cited contracts, **not executed tests**.
Names such as `M1`, `U1`, `D1` denote distinct retained command identities.

| Case | Trace and required outcome |
| --- | --- |
| Ordinary undo/redo | Recipes R and S begin in F and G. M1 moves both to H; register one “Move Recipes”. U1 restores R→F and S→G atomically. Redo M2 moves both to H. M1/U1/M2 remain evidence; replay U1 coalesces and does not add another history entry. |
| Successive undo | M1 moves R F→G; M2 moves R G→H. Undo M2 authors U2 H→G and updates the scope token. Undo M1 can then author U1 G→F. A token permanently tied to M1's original post-state would wrongly reject this sequence. Redo follows native order with fresh identities. |
| Existing Tag membership | R already has tag T; S does not. “Add Tag” should change only S (or retain an explicit no-op classification for R). Undo must not remove R's original membership. A bulk opposite `remove` over the original selection is incorrect. |
| Incoming Tag assignment | Local add creates assignment A; another device adds B. If B is known before undo, invalidate/refuse. If B arrives afterward, U removes only the assignments captured for the inverse and B remains. The visible tag may remain; report local compensation, never “removed everywhere”. |
| Incoming or intervening move | M1 moves R F→G. Another scene/device moves R→H, or F is deleted/merged. Undo sees a mismatched scope/identity and refuses. Do not prepare a fresh ordinary move from H merely to make undo succeed. |
| Failure at member 2 of a batch | U1 intends R→F, S→G; validation/write for S fails. Existing transaction rolls back R too. No redo registration, retain U1 only under the existing failure/retry rules. No per-member native groups and no best-effort partial local success. Remote incremental delivery is separately handled by refresh. |
| Ambiguous commit / cleanup failure | U1 may have committed although local cleanup/read failed. Retry its same identity before evaluating a new frontier guard; an accepted receipt proves the old command, not a new reversal. Never mint U2 to “try again”. Native history remains cleared after this recovery. |
| Edit after Save | Save V2 over V1 succeeds; a draft based on V2 acquires unsaved text or another Selection arrives. Proposed Undo Save refuses until that work is explicitly handled; it must not discard the draft or choose V1 over a competing frontier. With no interference, append a Selection of V1 and retain V2/media. |
| First Save and failed draft cleanup | First Save is accepted but its local draft remains frozen. Do not register twice after retry, call Discard an undo of Save, or delete the Recipe to clean up a draft. First-Save undo is deferred pending its separate policy. |
| Session activity followed by Stop/Finish | Progress P1 is accepted, then Stop or Finish changes eligibility. A stale Undo P1 is disabled/refused. Stop may later have its own guarded Resume compensation; Finish never does. Undo must not auto-Resume or auto-Continue to satisfy an earlier action. |
| Pending Entry edit | Submitted text A is pending; the person types B, then retries or submits again. #214 characterizes existing loss/duplication here. Do not snapshot this defect into undo semantics; fix it before Entry undo and prove exact text/identity preservation. |
| Draft/media write failure | Removing an image changes live draft contents but local persistence fails. Existing draft semantics retain the latest live state and block leaving. A later draft-undo slice needs a typed live-change/storage result and retained bytes, rather than claiming mutation did not happen. Until specified, it is outside the first slice. |
| Reset / owner switch / pruning | Invalidate affected timeline and callbacks at reset preparation; if reset fails, retained data remains but history can stay cleared. New owner/store never sees prior actions. An expired deletion's pruned Recipe can only use explicit Recovery into a new identity, never Undo Restore from cached bytes. |
| Navigation veto after acceptance | M1/U1 commits but showing its destination would fail to preserve another draft. Keep the accepted operation and its reciprocal history; leave focus/selection unchanged. Navigation failure is not delivery failure. |
| Termination before domain acceptance | A prepared history record exists but its domain command has not been accepted. Reopen into reconciliation, not a fabricated Undo group. Preserve exact identity; resolve through the existing delivery contract before allowing dependent work. |
| Termination after domain acceptance | M1 or U1 committed before history finalization. Its authoritative receipt establishes the outcome; finalize the group/cursor once. Reopening never applies the command a second time or forgets the accepted reversal. |
| Ordinary relaunch / new scene | Restore eligible Undo and Redo for the same logical scene after checking identity and current evidence. Do not mutate content while rebuilding native availability or transfer history to a newly created scene. |
| Invalidation followed by termination | Reset/interference/failure invalidates history, then the process stops. Reopening cannot resurrect old actions; failed invalidation storage leaves the scope blocked pending reconciliation. |
| Folio package copy or failed migration | A coordinated package save/copy must retain a coherent domain/history boundary, including required SQLite journal state. An unsupported schema or failed migration preserves recoverable originals and reports unavailable history; it must not silently erase the database. This is a reuse proof, not Folio delivery under #191. |

## Agreed decisions

The maintainer agreed to all eight decisions on 2026-09-25, then explicitly
amended decisions 4 and 7 to require durability and selected the reusable Core
Data-backed framework. [ADR 0022](../adr/0022-shared-durable-undo-framework.md)
records the accepted direction. Implementation details and the final #204
acceptance scope remain open.

1. **First scope:** saved-Recipe Folder moves and Tag add/remove, single or
   atomic bulk, after durable recovery and native routing/failure probes. Keep
   creation, deletion, merge and first Save outside this first PR series.
2. **History ownership:** scene-local, owner/store/Kitchen-scoped app history;
   native text takes responder priority, and structured draft history is tied to
   one draft lifetime. Another scene's relevant mutation invalidates local history.
3. **Interference:** conservatively refuse and clear affected history on relevant
   external evidence, rather than rebase across it or overwrite current state.
   A new explicitly confirmed operation is available through normal controls.
4. **Failure and recovery:** durably invalidate actionable app history after a
   rejected/failed inverse; retain exact pending compensation for existing retry.
   Ordinary interruption/relaunch must instead reconcile the durable history with
   accepted outcomes and preserve eligible actions. Unproved outcomes block use.
5. **Save meaning:** later Undo Save of an existing Recipe means a new Selection
   of its prior Revision, preserving history; first Save and reconciliation Save
   need separate policy. Active drafts and competing heads veto automatic reversal.
6. **Lifecycle and destructive exclusions:** no Undo Finish, Start, Continuation,
   organization merge/delete, draft discard, Sample Pack request, reset or pruning
   in the proposed initial policy. Separately approve any expansion; Stop/Resume
   and Active activity are later candidates, not permission to rewrite Finished work.
7. **Bounds and UX:** at most 100 app groups per KitchenMemory scene, persisted
   locally through UndoKit, localized action names and no automatic navigation.
   Preserve eligible history across relaunch for the same logical scene.
   Draft-media history needs a separate byte budget before that wave; do not
   evict a still-needed draft payload.
8. **1.0 scope:** use the matrix to select the required waves under #204. Research
   and a small first slice do not establish “app-wide” acceptance. Explicitly
   approve the final exclusions and native/accessibility evidence for that gate.

**Shared framework and storage:** UndoKit owns a local-only Core Data history
store and native integration, with a host-selected location. KitchenMemory keeps
the database in app storage; Folio can keep a separate database inside each
document package. Domain interpretation and acceptance stay in each app's domain
Kit. Folio's document-wide, branching, optionally omitted history must remain
possible without inheriting KitchenMemory's scene scope or bounded retention.
No third-party module, synchronized history service, storage schema or final
distribution/API design is selected here.

## Proposed implementation tickets

These are **ticket drafts**, not newly published issues or ready-for-agent work.
Publish the agreed slices with native dependency edges before claiming them.
References U0–U7 below are local planning identifiers, not GitHub issue numbers.

| Draft | Bounded outcome / acceptance | Depends on |
| --- | --- | --- |
| U0 — Prove shared UndoKit storage and recovery | Define the reusable Cocoa-compatible boundary and versioned local Core Data model. Prove on-disk preparation/acceptance/finalization and invalidation recovery, stable scope/command identity, duplicate-free reopening, preserved Undo/Redo position, schema failure and migration behavior. Exercise app-local storage and a minimal document-package host, including safe save/copy and a seam for Folio's branching/omission policy. Select framework packaging/API with both consumers; do not implement Folio product features here. | ADR 0022; agreed storage/domain recovery test seams |
| U1 — Prove native undo routing and failure behavior | A disposable signed Mac/iPhone/iPad probe demonstrates focused text versus app history, two windows sharing one graph, action names, explicit batch grouping, synchronous success, failed handler invalidation, and text teardown. Restore native availability from eligible persisted history without replaying mutations; prove scene restoration versus disposal. Record actual menu/keyboard/mobile behavior. | U0; decisions 2–4; agreed test seams |
| U2 — Conditional organization compensation | Extend the existing organization seam to capture reversal values and compare eligibility/evidence inside atomic acceptance. Cover mixed Folder origins, no-op Tags, exact retries after ambiguous acceptance, successive undo and concurrent evidence. Typed outcomes; no UI, second persistence authority or unreviewed format change. Inspect checkpoint/receipt compatibility before claiming no schema impact. | Decisions 1, 3–4; U1 informs callback/result requirements |
| U3 — Ship native Move/Tag undo and redo | Connect one initiating-scene adapter and the durable UndoKit store to existing menu/drop/bulk operations; expose only accepted commands once, use U2 for both undo/redo, keep navigation independent, localize action names and failure messages in all shipping locales. Prove interruption recovery and ordinary relaunch as well as the regression plan and signed native checks. | U0, U1, U2; decisions 2, 7 |
| U4 — Local structured draft and media undo | Enumerate nontext operations in the matrix; preserve identities, precision/proposals, private bytes and unrelated edits. Define live-state versus failed-storage outcomes, memory limits and draft lifecycle invalidation before implementation. Retain #188 text behavior. | U1, U3 routing; decisions 2, 4, 7; dedicated draft-seam agreement |
| U5 — Saved Recipe and disposition compensation | Add guarded prior-Revision Selection and observed Recipe/Session Delete/Restore compensation. Keep first Save and reconciliation Save excluded until separately decided. Exercise missing payload, concurrent deletion/selection and drafts; never restore pruned identity. | U3; decisions 3–6 |
| U6 — Active Session undo | Add eligible progress/scale/Outcome and agreed Stop/Resume compensation through CookingSessions and CookingSessionDelivery; preserve ordering and identity. Pending work, conflicts and Finish block reversal. Entry undo is a separate child after fixing pending-text/duplicate defects and settling withdrawal/redo identity. | U3; decision 6; Session-seam agreement |
| U7 — Accept the selected app-operation matrix | Reconcile implemented rows with #204, record exclusions, lower-level evidence and Mac/mobile native accessibility checks. Test native text coexistence, window focus, names and failure explanations across supported locales. Human release acceptance remains governed by ADR 0019/0020. | Selected U3–U6 scope; decision 8 |

## Regression and evidence plan

No production code or tests are changed by #191. Existing tests were inspected,
not rerun as proof of a feature that does not exist. The implementation tickets
must confirm their seams before test-first work; these are proposed seams and
behavior examples, not blanket TDD approval inherited from #214.

| Seam | Required lower-level evidence |
| --- | --- |
| UndoKit + real on-disk Core Data store + host recovery adapter | Inject interruption before/after history preparation, domain acceptance, history finalization, compensation and invalidation. Recover the exact group and Undo/Redo position once; never expose attempted/unproved work. Prove failed migration/unreadable store preserves evidence, stable scope isolation, retention, and no resurrection after durable invalidation. Exercise both app-local and document-package storage, including coherent copies with journal state and Cocoa interoperability. |
| Organization preparation and production repository | Normal/redo/failure paper cases above; inject failure at every member; no-op membership; one invalid Recipe aborts all; transaction-level stale guard; receipt-first identical retry; altered identity payload rejected; compaction and late remote receipts preserve existing policy. Extend [repository tests](../../KitchenKitTests/Persistence/RecipeOrganizationRepositoryTests.swift). |
| App native-manager adapter + volatile/production command store | One group per accepted action; zero groups for failure/no-op; two successful actions followed by two undos/redos; native reverse order; new action invalidates redo; second scene and owner/store/reset invalidate; delayed stale callbacks cannot mutate; no `Task`-based fake native redo; navigation veto does not undo acceptance. Existing [navigation tests](../../KitchenMemoryTests/Composition/RecipeLibraryNavigationTests.swift) supply the veto seam. |
| Draft module + real file store | Live/persisted text after failure; no whole-draft clobber; native history survives unrelated app invalidation; frozen Save/cleanup retry cannot duplicate groups; exact media bytes/identity; memory eviction never removes authoritative draft state. Preserve [draft failure](../../KitchenKitTests/Logic/RecipeDraftFailureTests.swift), [publication](../../KitchenKitTests/Logic/RecipeDraftPublicationTests.swift), and [ingredient history](../../KitchenKitTests/Logic/RecipeIngredientTextEditingTests.swift) coverage. |
| Recipe authority/disposition | New Selection rather than payload rewrite; competing head refusal; deletion frontier race; existing draft veto; tombstone refusal; no inverse of first Save/reconciliation until decided. |
| Session command/delivery | Accepted versus terminal-retired versus pending; new reciprocal Fact identity; same retry identity; current lifecycle/frontier checked at acceptance; Finish immutability; draft effects persisted before retirement. Retain [delivery tests](../../KitchenMemoryTests/Features/CookingSession/CookingSessionDeliveryTests.swift) and the [known-defect characterizations](../../KitchenMemoryTests/Features/CookingSession/CookingSessionDeliveryCharacterizationTests.swift). |

Native evidence is distinct from these tests: run through the
[Xcode application workflow](../agents/xcode.md), verify actual responder routing,
localized menu names, keyboard and supported mobile actions, VoiceOver labels and
focus, and two-window behavior. Keep UI automation focused under
[ADR 0007](../adr/0007-business-logic-coverage-and-ui-smoke-tests.md); native and
human acceptance cannot be inferred from a green command test or this paper study.
