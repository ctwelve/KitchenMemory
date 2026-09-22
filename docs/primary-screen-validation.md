# Primary-screen slice validation

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

This is bounded development evidence for [#182](https://github.com/ctwelve/KitchenMemory/issues/182)
and [#189](https://github.com/ctwelve/KitchenMemory/issues/189), recorded on
2026-09-22. It is not a release or beta acceptance record. The integration branch
is `slice/182-primary-screen`; the review baseline is `26a1eb7`.

## Implementation map

| Ticket | Implementation and evidence |
| --- | --- |
| #183 | Prototype accepted by the maintainer before implementation. |
| #184 | Three-column native library, temporary Organization overlay, preserved destination/selection/draft state, and organization Settings ownership. Presentation-model tests and named destination navigation. |
| #185 | Pinned contextual search, full folder paths, visible tag constraints, reset semantics and recipe rows. Model filtering/selection tests and Mac search/reset walkthrough. |
| #186 | Conservative locale-aware ingredient interpretation, exact quantities and package amounts, source annotations and identity-based precision reconciliation. Framework parser/import/reconciliation tests. |
| #187 | Recipe-pane width and scaled text choose stacked or side-by-side Ingredients and Instructions, in the same reading order. Model composition checks and native Mac reading at wide and constrained widths. |
| #188 | In-place simple/advanced editing, per-ingredient precision, native multiline text and undo, real section headings, recoverable proposals, explicit publication. Framework and hosted model tests; native Mac editing walkthrough. Mobile interaction remains pending. |
| #189 | Integration checks and documentation below. Acceptance remains open until the pending native checks are completed. |

Current behavior is documented in [native organization](recipe-library-organization.md)
and the [Recipe domain model](recipe-domain-model.md). KitchenKit still owns
editing state and publication; the app owns native bindings, navigation and
text undo history. These remain within the existing architecture decisions;
no historical SwiftData schema or CloudKit deployment changed.

## Native evidence and limits

On macOS 27, Xcode built and launched the Develop app. The walkthrough exercised:

- Wide reading with Ingredients leading Instructions, and stacked reading with a constrained recipe pane.
- Persistent search, a no-match result, changing the folder without clearing the query, and Reset Filters retaining the folder.
- Creating a local draft; ordinary ingredient text, pasted lines and `# Sauce`; a real Sauce section in Advanced Editor; returning to simple editing with the same text.
- Add Ingredient Section, Command-Z and Shift-Command-Z for native text/section undo and redo. Repeat checks after the precision-history correction.
- Quitting and relaunching, opening Drafts and recovering the same authored text and annotations.
- Hiding Organization, temporarily revealing it across the list/detail boundary, changing folder context and returning to the selected recipe. A native half-screen tile retained selection and the two-column reading surface.
- Meaningful native labels for title, Ingredients, editor mode and publication controls; keyboard text entry and non-color quantity/unit/supporting-text distinctions.

The walkthrough used the existing Comfort folder, not a nested folder. The exact
nested-folder + unfinished existing-recipe edit + narrow tiled-window exercise
remains a manual acceptance item. Hosted tests cover those navigation and draft
state transitions independently, but do not substitute for that complete native
exercise.

An iPhone 17 simulator running iOS 27 built and launched successfully through
Xcode. Device Hub accessibility inspection timed out. Xcode's alternative
interaction workflow required an unavailable `device-interaction` skill, so its
session was closed. No successful mobile typing, paste, section undo, or wide
iPad interaction is claimed from that launch. Physical devices, actual enlarged
text/VoiceOver traversal and the complete mobile editing walkthrough remain
unverified.

The Mac Develop store retains one unpublished **Editor verification draft** from
this walkthrough. No Revision was published from it.

## Automated validation

Framework and hosted tests cover retained reviewed fields, locale parsing,
section/ingredient identities, active-text recovery, explicit conflict choices,
mode switching, and interleaving native text undo with later precision changes.
The UI suite checks only named top-level destinations and editor controls;
business workflows are not duplicated in UI automation.

The standalone KitchenKit runner passed **584/584 tests** and the exact coverage
gate: **14,209/14,209 business-logic executable lines**, with the existing 130
Apple-runtime adapter lines excluded. Fresh result bundle:
`/private/tmp/KitchenMemoryCoreCoverage.MFK8if/Tests.xcresult`.

Localization, documentation navigation, project structure, software inventory
and changed Swift-source lint are checked independently.

## Acceptance boundary

Keep #189 and the parent slice open until the remaining native exercises above
are accepted. Any discovered input or accessibility barrier is a product issue,
not an exemption under parked #155. [#168](https://github.com/ctwelve/KitchenMemory/issues/168)
continues to own beta-wide acceptance, including later Cooking Session and
other supported-workflow stabilization.
