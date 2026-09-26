# Cooking Session interface

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Accepted design; implementation and native interaction acceptance pending
- Agreed: 2026-09-26, after the maintainer's final confirmation of the #193 interview
- Design ticket: [#193](https://github.com/ctwelve/KitchenMemory/issues/193)

This is the agreed next interface for [Cooking Sessions](cooking-sessions.md),
not a claim that the current application implements it. The Session contract,
immutable Execution Snapshot, lifecycle, continuation, and recoverable delivery
remain authoritative. A Recipe is maintained intent; each cook has its own
Session. This interface does not introduce a new domain lifecycle or storage
schema. The [live roadmap](https://github.com/ctwelve/KitchenMemory/issues/190)
and native issue dependencies own delivery status and ordering.

## Reading and progress

Design primarily for a device propped up while both hands are busy cooking,
while retaining native Mac pointer and keyboard use. Keep the entire recipe
readable in authored order so the cook can read ahead. The interface is a
reading surface with lightweight controls, not a one-step wizard or an
administration form.

- Visually emphasize a current instruction independently of its progress.
  Initially suggest the first unfinished step; let the cook choose another
  without completing or reopening anything.
- Use generous, explicit progress controls, with an oversized checkbox as the
  prototype direction. Reading text must not toggle progress. Preserve the
  existing ingredient accounted/open and instruction complete/skip/reopen
  actions and their accessible state descriptions.
- Keep quick access to ingredients without losing the reading position. Show
  ingredients and instructions side by side when space permits; preserve a
  coherent single-column reading order at compact and accessibility text sizes.
- Completing the currently emphasized step advances emphasis to the next
  unfinished step after it. It may slowly scroll only enough to reveal that
  step. Do not wrap automatically to an earlier unfinished step or Finish when
  there is no next step.
- Touch or manual scrolling interrupts that movement immediately, without a
  snap, later restart, or swallowed control tap. Only another deliberate
  completion of the current step may initiate another automatic scroll.
- No other progress action, scale change, incoming update, or Resume triggers
  automatic scrolling. Explicit navigation/jump actions and restoring a screen
  the person reopens are separate expressions of intent.
- Under Reduce Motion, update emphasis without animated travel and offer an
  explicit jump. Keyboard and VoiceOver focus stay on the control just used;
  give a brief completion/next-step announcement and an explicit way to move.
  Input modality does not weaken the rule that the person controls navigation.

Keep the screen awake by default only while an Active cooking screen is
visible, with an easy override. Restore normal sleep behavior on leaving,
Stop, or backgrounding. This does not change Session lifecycle.

Remember each Session's emphasized step and reading position on that device,
including across relaunch. Restore position as closely as the current layout
allows; Stop/Resume keeps the current place. These are local presentation
preferences, not synchronized evidence or authority over another device's
reading position. Missing preferences fall back safely to ordinary reading.

## Notes and Outcome

Offer both a general Add Note action and contextual ingredient/step actions.
They open the same on-demand composer, with the contextual target preselected
when starting an empty draft. Existing notes remain discoverable beside their
targets and in the Session's notes. Preserve existing edit, retarget, and
withdraw capabilities.

There is at most one local Session Entry draft per Session. If a meaningful
draft already exists, any Add Note route reopens its exact text and existing
target. Never silently replace or retarget it. The person submits, discards, or
keeps editing before beginning another note. Dismissing the composer preserves
the draft. Different attempts at the same Recipe are different Sessions; do
not fetch another Session's draft merely because it was edited more recently.
The expectation of one or two concurrent cooks per Recipe is not a hard cap.
Recipe Editing Drafts remain separate.

Once a note is submitted, Retry refers to that exact retained submission and
identity. While it is pending, offer Retry instead of another Submit that
could create a duplicate. Text or target edits made after submission remain
the recoverable local draft and require a separate, deliberate submission
afterward. Retry never implicitly submits both versions. Intentionally creating
a later Entry with identical wording remains possible; text equality is not
submission identity. [#245](https://github.com/ctwelve/KitchenMemory/issues/245)
owns this correction before the new notes/Finish flow ships.

Place the optional Outcome near the finishing area. Choosing or clearing an
Outcome does not Finish; leaving it unset is valid. A Finished Session's
Outcome, notes, snapshot, scale, and progress are observational.

## Scaling and culinary judgement

Show a compact yield or scale summary near the title. Open detailed adjustment
on demand, with absolute presets **½×, 1×, 1½×, and 2× of the original snapshot**,
plus custom adjustment. Repeated taps do not compound a factor. Preserve the
existing explicit base selection for a range yield and always recalculate from
the immutable snapshot.

Allow factor-based scaling even when the Recipe has no numeric serving yield.
Show the factor without inventing a serving count. Missing yield alone does
not make a structured ingredient calculation uncertain.

At the first non-original scale that warrants explanation, show one relevant
banner per Session. Suggested wording, with only applicable clauses included:

> Serving yield isn't specified. Ingredient amounts are scaled where possible;
> marked amounts remain as written. Exercise your culinary judgement.

Remember its dismissal locally; changing presets must not repeatedly nag.
Contextual indicators remain available after dismissal and explain the actual
condition rather than giving every ingredient a generic warning:

- Exact linear quantities scale exactly; approximate quantities retain their
  approximation and ranges retain both endpoints.
- Fixed quantities stay fixed. Manual-review quantities invite judgement.
  Unparsed or unscalable authored amounts remain as written; do not invent
  precision for custom, missing, or textual quantities.
- Existing arithmetic failure remains an explicit failure of the scale change,
  not a partially successful calculation presented as complete.
- Cooking time, temperature, and authored method remain unchanged. Use small
  factual markers such as “Time kept as written” and “Temperature kept as
  written,” plus a discreet reminder to judge the method when scaling.
  Pan size, shape, oven behavior, and thermal mass can change the result;
  this interface does not calculate replacement cooking conditions.

Derive guidance from retained structured content and scaling behavior. There
is no new speculative parser that identifies which prose steps need adjustment.
AI-assisted recipe completion, nutrition, and better structured data are future
capabilities, not prerequisites or implied features of this slice.

## Lifecycle and failure handling

Ordinary navigation leaves the Session without changing its lifecycle. Keep
Finish visible in the cooking view; put Stop and Delete in a secondary menu.
A Stopped Session prominently offers Resume. Delete retains its existing
confirmation and reversible disposition semantics.

Use an in-view slide-to-finish as deliberate confirmation. Completing the slide
is the confirmation itself, not a request for a second generic confirmation.
Provide an equivalent named Finish action with confirmation for keyboard and
assistive technologies; essential completion must not depend on dragging.
Unchecked ingredients/steps do not prevent Finish and never cause it.

Unfinished notes and unresolved operations still require explicit handling:

- For an Active Session's meaningful draft, preserve the explicit add, copy,
  discard, or cancel choices. Add-and-Finish requires actual acceptance of the
  Entry before attempting Finish; terminal rejection is not acceptance.
- For a Stopped Session's meaningful draft, offer **Resume to edit note**,
  **Copy note and finish**, **Discard note and finish**, and **Cancel**.
  Resume opens the composer and abandons that Finish attempt; saving the note
  is followed by a new deliberate Finish. Never silently Resume. The number
  and wording of these choices may be simplified after hands-on prototype
  review without losing their preservation or consent boundaries.
- Keep ordinary save failures alongside the readable recipe in a persistent,
  compact explanation with Retry. Preserve the ordered pending work and draft
  across leaving/relaunch; do not offer an unsupported discard-and-finish path.
- If earlier unsaved work prevents accepting a Finish request, explain why the
  slide is unavailable. Finishing waits for local acceptance, not cloud upload.
- Once the explicit Finish request is retained, present “Finishing—waiting to
  save” when delayed and Retry on failure. Leaving or dismissing an explanation
  does not withdraw that request; do not label dismissal “Cancel Finish.” It
  retries with the same Closure identity, including after relaunch, and needs
  no second slide while its consent remains valid. Existing stale-closure
  rejection still requires a fresh explicit choice; no silent reauthorization.
- Remote Finish preserves a remaining draft for explicit continuation, copy,
  discard, or leaving unresolved. Continue maps its target through the captured
  baseline; it does not attach the note to an unrelated cook.

Normal local saves should be unobtrusive. Delayed saving is a rare recovery
case, not an excuse for constant ceremony. A pending Finish message is
presentation of an intention, not a fourth Session lifecycle state. Structural
Recovery and Deleted Items retain their existing, separate responsibilities.

## History and navigation

Group history into **Active**, **Stopped**, and **Finished**, newest first within
each group. Identify cooks with Recipe title, Session start date/time, and any
recorded Outcome; do not require custom names. Every Session stays reachable,
including older unfinished cooks and cooks whose source Recipe is absent or
deleted. Recent/current shortcuts may supplement the complete groups, never
truncate the only route to retained work. Recipe-specific history uses the
same arrangement filtered by retained provenance.

After Finish, keep the completed record visible, including snapshot, progress,
notes, and Outcome. It has ordinary Back navigation and explicit Continue;
active controls and “Up Next” prompts must not imply it is still editable.

Preserve the entry context through Finish and Continue. Back returns to the
overall or Recipe-specific history the person came from and preserves that
list's position. Entry directly from a Recipe retains its ordinary return
route. Continue creates a new Active Session from the existing domain baseline,
with readable predecessor lineage rather than raw identifiers. Neither routing
nor missing source Recipe data changes the inherited evidence contract.

## Inventory and implementation boundaries

The inventory for #193 examined the integrated #184/#209 navigation and the
#213/#214 ownership seams at main commit
[`e1f8751`](https://github.com/ctwelve/KitchenMemory/commit/e1f8751424922341c20cfbf55923d702e133b1e2).
These are observations of the old interface, not accepted future behavior:

| Existing surface | Gap addressed by this design |
| --- | --- |
| [Cooking view](../KitchenMemory/Features/CookingSession/CookingSessionView.swift) | Full note/Outcome and scaling forms precede the recipe; bottom actions compete with reading; Stopped incorrectly offers Add-and-Finish without Resume |
| [Progress rows](../KitchenMemory/Features/CookingSession/CookingSessionProgressRows.swift) | Entire rows change progress; first-open emphasis is derived, with no independent chosen step or saved reading anchor |
| [Entries](../KitchenMemory/Features/CookingSession/CookingSessionEntriesView.swift) | Composer is always present; contextual row entry points are absent |
| [History](../KitchenMemory/Features/CookingSession/CookingSessionHistoryView.swift) | Current plus five recent unfinished cooks can hide older work; repeated cooks lack useful identification; Finished exposes raw lineage identifiers |
| [History presentation](../KitchenMemory/Features/CookingSession/CookingSessionHistoryPresentation.swift) and [navigation](../KitchenMemory/Composition/RecipeLibraryNavigation.swift) | Finish/Continue do not consistently preserve the originating history scope; current reading position is not durably restored |
| [Delivery](../KitchenMemory/Features/CookingSession/CookingSessionDelivery.swift) | Ordered exact retry already exists; #245 corrects newer-draft clearing and accidental duplicate submissions; ordinary failures currently use a generic root alert |

Keep navigation in the existing navigation owner, ordered delivery in
`CookingSessionDelivery`, and cooking rules in KitchenKit. New reading
preferences and explanation dismissal belong to device-local presentation.
Inspect compatibility before extending that storage; retain old drafts,
pending-command decoding, and retry identities. No schema migration, stronger
crash-durability claim, or public-interface redesign is authorized by this
design record. The app working-version/inventory increment is release-policy
bookkeeping, not delivery of the new interface.

The bounded delivery graph has five pieces: a disposable native interaction
prototype; reading/progress/restoration after its acceptance; scaling after
the accepted reading layout; history/navigation independently; and
notes/Finish/recovery after prototype acceptance and #245. The live tickets
hold acceptance checklists and native blockers. A prototype is not production
architecture and must not modify real Kitchen data.

## Native evidence and acceptance

Apple documentation reviewed on 2026-09-26 supplies capability evidence:

- [ScrollPhase](https://developer.apple.com/documentation/swiftui/scrollphase)
  distinguishes programmatic animation and user interaction;
  [tracking](https://developer.apple.com/documentation/swiftui/scrollphase/tracking)
  can detect touch before movement, but is not emitted by every platform/input.
  This does not establish that every touch cancels an animation at its present
  position or preserves child control activation. Prove that natively.
- [Reduce Motion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)
  exposes the preference to avoid large animations. The no-travel/current-step
  alternative above is this product's accepted response.
- Apple's [gesture guidance](https://developer.apple.com/design/human-interface-guidelines/gestures/)
  calls for alternate input routes. [Named accessibility actions](https://developer.apple.com/documentation/swiftui/view/accessibilityaction%28named%3A_%3A%29)
  provide an API for assistive technologies; their presence alone does not
  prove that Finish is usable.

The prototype must demonstrate slow-scroll interruption without snapping,
restarting, or consuming intended taps; deliberate slide completion without
accidental activation during ordinary handling; and equivalent keyboard,
VoiceOver, and Switch Control completion. Exercise propped-up touch use,
constrained/wide layouts, accessibility text sizes, Reduce Motion, and the
Stopped-draft choices. Record exact devices, OS/toolchain, results, omissions,
and the maintainer's hands-on acceptance. A build or simulator screenshot is
not evidence of touch interruption or assistive-technology usability.

Implementation acceptance follows [accessibility engineering](accessibility-engineering.md)
and [ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md):

- Framework/hosted tests prove progress selection, absolute scaling and honest
  diagnostics, local restoration, draft preservation, exact retry, lifecycle,
  navigation scope, and finish failure/relaunch behavior.
- UI automation remains limited to named top-level semantics and destination
  reachability. Do not add coordinate drags, exact scroll positions, or duplicate
  cooking-workflow scripts to claim this design is accepted.
- Use the [Xcode application-test workflow](agents/xcode.md) for signed native
  tests. Native input/accessibility walkthroughs establish actual interaction
  quality; report unexercised cases rather than marking them passed.

No native prototype or new runtime acceptance is claimed by this design.
Completing #193 or its prototype does not satisfy the comprehensive beta gate
[#168](https://github.com/ctwelve/KitchenMemory/issues/168). Timers, app voice
features, Session media, pantry effects, Recipe promotion, and AI-assisted
recipe completion remain separately scoped.
