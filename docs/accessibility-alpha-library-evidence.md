# Alpha Recipe Library accessibility evidence

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

This is the bounded alpha validation for
[Issue 122](https://github.com/ctwelve/KitchenMemory/issues/122), under
[the accepted accessibility policy](accessibility-engineering.md). It does not
accept the provisional UI for beta or replace the release maintainer's
candidate-specific acceptance.

## Candidate and scope

Application source: `16072e8b0fb006ea71c7c21c2f860da60cff74a1`, version 0.2.16.
Inspection and native validation: 2026-09-07, Xcode 26.6 (17F113), macOS 26.6.2
(25G83), My Mac. This slice changes documentation only; application, test, and
package inputs remain those of the identified source revision.

## Source inspection

| Surface | Evidence inspected | Bounded conclusion |
| --- | --- | --- |
| Library and Recipe rows | `RecipeLibrarySidebar`, `RecipeRow` | Native list/navigation links retain Recipe titles; decorative thumbnails are hidden; the library has a localized accessible name. |
| New and Import | `LibraryToolbar`, `ToolbarIconLabel`, `RecipeLibraryCommands` | Icon-only toolbar actions supply explicit localized labels; native menu commands provide keyboard shortcuts and availability. |
| Reading | `RecipeDetailView` | Title and section headings, explicit content containment, decorative-image hiding, and named metadata representations preserve readable structure. |
| Authoring | `RecipeEditorView`, `EditorTextField`, ingredient/instruction editors | Native labeled inputs and named save/close/discard actions; validation messages remain visible and save availability follows the model. |
| Import and scaling | `RecipeURLImportView`, `RecipeScalingView` | Named URL/fetch actions and scaling controls; no coordinates or identifiers used as substitutes for labels. |

Source annotations support the runtime check; they do not establish VoiceOver
focus, spoken coherence, or comprehensive accessibility compliance.

## Native tests

Xcode's MCP `RunAllTests` action ran the KitchenMemory scheme and its default
KitchenMemory plan on My Mac in Testing configuration. Result: **185 passed,
zero failed, skipped, expected failures, or not run** (179 hosted application
tests and six existing UI tests). The full summary was generated at
2026-09-07T20:01:00Z; artifact identifier
`5422D6F5-5B42-4DE1-8C4E-9B1E9D9BBD64`.

The six UI checks cover top-level navigation, organization management, Recovery,
Settings, startup-failure recovery, and the existing six-language doubled-text/
right-to-left shell smoke. Their success does not claim layout or VoiceOver
acceptance. Cloud UI tests remain suspended under Issue 155.

## Ordinary-use Mac walkthrough

An agent-operated walkthrough used native controls, keyboard input, the
accessibility tree, and a visual observation in the same Testing product, in
English (en-US). This was not a human assistive-technology audit.

1. Launched with `--ui-testing --ui-testing-cloud-sync-disabled` and
   `-ApplePersistenceIgnoreState YES`. Verified the launch plan uses in-memory
   persistence, volatile Recipe drafts/preferences and Session presentation, and
   no personal CloudKit synchronization. Bundled Recipes supplied synthetic
   reading content.
2. Entered `Red Engine` in Search Recipes. The Library filtered to the matching
   bundled Recipe; selecting it opened its named detail destination, content,
   equipment, ingredients, instructions, and source. Ordinary scrolling exposed
   readable ingredient content.
3. Invoked New Recipe with Command-N. The editor exposed Title and Summary fields
   and a named Save Revision action, initially disabled for the empty title.
4. Entered a synthetic title and summary. Save Revision became enabled.
   Command-S opened the saved Recipe detail with those values. Clearing the
   prior search exposed its selected row in the Library.
5. Quit the disposable application after the walkthrough.

The Testing product requires Xcode's framework search context. Direct launch
initially failed to locate KitchenKit; supplying `DYLD_FRAMEWORK_PATH` pointing
to that product's `Contents/ReexportedBinaries` allowed the isolated walkthrough.
This is evidence from a test product, not an outside-Xcode distribution install
check. Xcode's signed native Test action passed without this manual adjustment.

## Result and remaining boundaries

No core-path accessibility barrier was identified in this bounded inspection and
walkthrough. No application changes or extra UI scripts were justified. Existing
native semantics and tests were retained; this evidence-only slice does not
allocate a new product version or change the SBOM.

The walkthrough chose manual creation, satisfying the create-or-import path;
network import was not exercised. iPhone/iPad walkthroughs, the full device and
input matrix, VoiceOver focus/grouping/spoken behavior, platform audits,
accessibility text sizes, appearance/contrast/motion combinations, and extensive
shipping-language layout review remain unverified here. They belong to
[beta acceptance](https://github.com/ctwelve/KitchenMemory/issues/168) after the
comprehensive UI design pass. Runtime text grouping can differ from source-level
containment annotations; the source table does not certify heading navigation.

The release maintainer must still accept the actual distributed candidate and
its platform scope under [release evidence policy](accessibility-engineering.md).
Later relevant interface or environment changes reopen affected checks. Business
logic and persistence behavior remain owned by lower-level tests; this
application-only validation does not claim a fresh standalone framework coverage
run. Raw local test logs and screenshots are not committed.
