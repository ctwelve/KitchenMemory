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
| #188 | In-place simple/advanced editing, per-ingredient precision, native multiline text and undo, real section headings, recoverable proposals, explicit publication. Framework and hosted model tests; native Mac editing walkthrough and maintainer acceptance below. |
| #189 | Integration checks and documentation below. The maintainer completed the remaining checks and accepted this phase on 2026-09-22. |

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
section/ingredient identities, active-text recovery, saving retained precision
without resolving proposals, explicit acceptance of replacement details,
mode switching, and interleaving native text undo with later precision changes.
The UI suite checks named top-level destinations and editor controls, including
destination availability across hidden, temporarily revealed, and pinned sidebar
modes. The maintainer confirmed these primary-navigation accessibility checks as
core UI on 2026-09-22; [ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md)
records the bounded scope. Business workflows are not duplicated in UI automation.

The standalone KitchenKit runner passed **584/584 tests** and the exact coverage
gate: **14,208/14,208 business-logic executable lines**, with the existing 130
Apple-runtime adapter lines excluded. Fresh result bundle:
`/private/tmp/KitchenMemoryCoreCoverage.kZIn0E/Tests.xcresult`.

The full Xcode-managed Mac application plan passed **198/198 tests**, including
the named editor-control check after adding explicit native field labels. Result:
`Test-KitchenMemory-2026.09.22_18-33-36--0500.xcresult`
(Xcode action artifacts, `RunAllTests`).

The initial iPhone 17 / iOS 27 application plan passed **195/196 tests**. The
expanded German/RTL Settings check failed because the new organization preferences
pushed the lazily materialized iCloud switch below the visible form. The test
helper now scrolls the identified Settings form before its unchanged native
switch/name assertions. Initial result:
`Test-KitchenMemory-2026.09.22_18-37-26--0500.xcresult`
(in the project DerivedData `Logs/Test` directory). Xcode completed this run after
the bridge’s five-minute response timeout; the finalized bundle supplied the result.
The focused expanded-text/RTL check then passed all six shipping locales in
`Test-KitchenMemory-2026.09.22_18-45-51--0500.xcresult`
(Xcode action artifacts, `RunSomeTests`). Thus every one of the 196 iPhone tests
has passed across the full run and focused correction; no single all-green
iPhone full-plan rerun is claimed. The ordinary Settings semantics check also
passed after helper cleanup on iPhone and Mac, respectively:
`Test-KitchenMemory-2026.09.22_18-50-56--0500.xcresult` and
`Test-KitchenMemory-2026.09.22_18-52-39--0500.xcresult`
(Xcode action artifacts, `RunSomeTests`).

Localization, documentation navigation, project structure, software inventory
and changed Swift-source lint passed independently. Parallel Standards and Spec
reviews against `26a1eb7` have no remaining code findings after correcting Save
to retain precise values without requiring proposal acceptance.

## UI correction and maintainer acceptance

The final UI batch keeps one native sidebar button, adds Mac pointer reveal to
that control, and retains native leading-edge navigation on iOS, including the
right edge in RTL layouts. Interpretation choices now appear below the ingredient
field in a highlighted, animated card with Reduce Motion support and a native
accessibility announcement. Simple-editor instruction sections and steps have
distinct surfaces and heading levels. Ingredient rows retain their full wrapped
height in the two-column reader.

Focused Xcode-managed checks passed: Mac sidebar hover and named navigation
(2/2), iPhone leading-edge navigation (1/1), forced-RTL right-edge navigation
(1/1), and iPhone editor control semantics (1/1). Native Mac previews verified
the editor in dark and increased-contrast light appearance, and reproduced then
resolved ingredient truncation. Mac and iOS builds passed; final ingredient-row
validation used the Mac build and preview. These bounded checks do not establish
comprehensive assistive-technology acceptance.

On 2026-09-22, the maintainer reported completing all #189 checks and accepted
the feature as sufficiently developed for this phase. The earlier pending items
above describe the agent's own evidence boundary, not outstanding phase-acceptance
requirements. This acceptance does not claim a release or beta readiness.

Any subsequently discovered input or accessibility barrier is a product issue,
not an exemption under parked #155. [#168](https://github.com/ctwelve/KitchenMemory/issues/168)
continues to own beta-wide acceptance, including later Cooking Session and
other supported-workflow stabilization.

## Closure-review corrections

The final review found that single-line paste without a trailing newline could
remain uninterpreted while the native Ingredients field retained focus. A hosted
native-adapter regression reproduced the missing quantity and ingredient on Mac
before the correction. These checks host the real text adapter with disposable
text, rather than adding an editor workflow to UI automation. Native heading
undo also exposed an AppKit path that changes text storage without invoking the
text-change delegates; undo completion now reconciles the retained draft snapshot.
The focused-field paste regression also failed on iPhone before its correction.
UIKit's programmatic insertion does not deliver the keyboard replacement delegate,
so paste and Add Section explicitly synchronize the same draft after native insertion.

Focused Xcode-managed checks passed on Mac (5/5) and iPhone 17 / iOS 27 (5/5):
single-line ingredient paste, single-line heading paste with native undo/redo and
section-identity retention, deferred interpretation while typing, and the two
existing precision/undo checks. A separate Add Section adapter regression passed
on iPhone (1/1). Results in Xcode `RunSomeTests` action artifacts:
`Test-KitchenMemory-2026.09.22_22-09-25--0500.xcresult` (Mac),
`Test-KitchenMemory-2026.09.22_22-17-15--0500.xcresult` (iPhone), and
`Test-KitchenMemory-2026.09.22_22-19-29--0500.xcresult` (iPhone Add Section).

The final full Xcode-managed Mac application plan passed **203/203 tests**, including
the sidebar UI checks and all four native ingredient-adapter regressions:
`Test-KitchenMemory-2026.09.22_22-20-11--0500.xcresult`
(Xcode `RunAllTests` action artifacts). The final Mac and iPhone builds emitted
no warnings. Changed-source lint, documentation, localization and project-structure
checks passed. Follow-up Standards and Spec reviews found no remaining actionable
findings in the corrections; the keyboard test exercises the native delegate
sequence, not a hardware/software keyboard interaction walkthrough.

During this review, Xcode 27's Mac test host failed before XCTest connected:
its generated runpath searched `Contents/MacOS/ReexportedBinaries`, while Xcode
embedded the signed KitchenKit copy in `Contents/ReexportedBinaries`. A clean
rebuild reproduced the failure. The shared macOS linker setting now includes
`@loader_path/../ReexportedBinaries`, allowing both application and test bundles
to find their signed copy without disabling library validation or signing the
standalone development framework by hand. Xcode-managed hosted tests launched
successfully after this correction.
