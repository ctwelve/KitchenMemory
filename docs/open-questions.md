# Open questions

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->


These are decisions to explore through prototypes and real recipes rather than
settle abstractly.

## Product

- Which post-1.0 release should introduce multi-person Kitchen sharing?
- Should an imported recipe be a private snapshot, a linked copy, or explicitly
  selectable between the two?
- How prominent should source updates be after a user has edited an import?
- Are personal notes part of the recipe or a separate per-cook annotation?
- Do family edits overwrite one shared recipe, create revisions, or create forks?

## Recipe model

- Can ingredient and instruction sections share one hierarchy, or should they
  remain independent as websites commonly publish them?
- Do we need alternate ingredient groups such as “either A or B” in the initial
  model?
- How should component yields work—for example, a sauce recipe embedded in a
  larger dish?
- Should temperatures and equipment become structured values early?
- What is the smallest useful representation of package sizes?

## Parsing and import

- Which ingredient parser provides a useful starting point, and can it run fully
  on-device?
- How should parser confidence be calculated and communicated without creating a
  cleanup chore?
- When several `Recipe` objects exist, what ranking signals are reliable?
- Should remote images be copied locally by default or retained as external URLs?
- What source material is appropriate to retain for private use and export?
- Which feed formats and polling model are worth supporting first, and should
  feeds create inbox candidates or saved drafts by default?

## Organization

- Are tags flat identities presented in groups, or truly hierarchical objects?
- Which recipe classifications deserve structured fields in addition to tags?
- How should shared kitchens resolve folder and tag renames concurrently?

## Platform

- Native SwiftUI for iPhone, iPad, and Mac is the chosen initial application
  platform. A display-centric tvOS cooking client is planned for a later phase.
- Which combination of managed SwiftData synchronization, Core Data CloudKit
  integration, and direct CloudKit APIs best supports a shared Kitchen?
- How should a shared Kitchen map to CloudKit record zones or hierarchies?
- Which collaboration conflicts require visible domain-level resolution rather
  than ordinary persistence merging?
- Which stable identifiers and commands should form the first AppleScript
  dictionary?
- Should unattended folder ingestion run inside the app, through a separate
  command-line companion, or both?

## Fuzzy pantry—deliberately deferred

- Which qualitative amount vocabulary feels natural: `a little`, `some`,
  `plenty`, or ingredient-specific alternatives?
- Can one holding combine an exact container count with a fuzzy contents amount
  without making ordinary entry cumbersome?
- Is “usually have” a property of an ingredient, a household preference, or a
  replenishment policy on the kitchen's pantry item?
- Does cooking automatically change pantry state, suggest a change, or leave it
  untouched?
- How quickly does pantry knowledge become stale?
- Can the app provide useful shopping advice without requiring users to maintain
  it after every meal?
- When do two observations represent separate holdings versus duplicate records
  of the same physical package?
- Should pantry cleanup be periodic, event-driven, or only user-initiated?

## Cooking sessions and recipe evolution

- When selected Session Entries become maintained Recipe work, should the person
  create a new revision, a named variant, or a new Recipe?
- How should repeated Session Entries trigger suggestions without becoming
  nagging?
- Which session media may be promoted to recipe media, and who may do so for a
  shared recipe?
- Are session reviews, durable recipe ratings, comments, and lightweight
  reactions distinct enough to justify separate concepts?
- Should photographs and video sync at original quality, optimized quality, or
  according to kitchen policy?

## Planned cooks and readiness

- What user-facing verb best introduces readiness: Plan, Prepare, Get Ready, or
  something else?
- Does choosing “have” merely decide this planned cook, or should the interface
  separately offer to refresh the pantry observation?
- How are partial requirements represented when some is present and the remainder
  should be purchased?
- Which compatible quantities may combine automatically across planned cooks?
- Are advance preparation items explicitly authored, derived from recipe steps,
  or both?
- How should undated planned cooks coexist with a weekly calendar?
- When is a planned cook considered ready, and must every ingredient receive a
  decision?
- What happens to shopping-list completion when a planned cook is cancelled or
  rescaled after items have been purchased?
