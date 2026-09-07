# Apple platform and automation architecture

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->


The product uses one native multiplatform SwiftUI application target for iPhone,
iPad, and Mac, with a display-centric tvOS client planned for a later phase.
The Mac application is not merely an enlarged phone interface: it should grow
into a powerful library-management and automation environment while sharing the
same recipe domain and import engine.

## Platform roles

The platforms share a recipe domain, but they do not need feature parity.

| Platform | Primary role |
| --- | --- |
| macOS | Full library management, editing, import review, batch work, and automation |
| iPhone | Capture, shopping, quick edits, and cooking |
| iPad | Cooking, planning, and comfortable recipe editing |
| tvOS | Hands-off, display-centric cooking guidance |

## Current shared UI strategy

During the foundation slices, one basic SwiftUI interface exercises the shared
domain and application behavior on Mac, iPhone, and iPad. This is deliberately
development scaffolding rather than a requirement that the mature products
share screens or a presentation framework.

Keep the current interface coherent and accessible, and introduce small
platform differences when needed. Defer serious visual-editor architecture
until representative Mac and mobile interactions can be compared. The later
Mac product may use AppKit and Storyboards for precise interaction and visual
design, while mobile may retain SwiftUI, use UIKit, or adopt a hybrid. Whatever
the result, the platforms continue to share the product core rather than a
compromised interface. See
[ADR 0006](adr/0006-shared-ui-for-foundation-slices.md).

## Current navigation model

The shared sidebar has two first-class destinations: Sessions and Recipes.
Sessions is always reachable, including when no Recipe is selected. Its sidebar
preview is intentionally short, while the destination itself exposes the
device-local current convenience, every other ordinary Active or Stopped
Session, and immutable Finished history. A Recipe detail also links to Sessions
whose retained root names that Recipe provenance; this is a contextual filter,
not ownership by the current Recipe object.

Opening Active or Stopped work enters the cooking interaction. Opening Finished
history enters an observational detail with explicit continuation and immediate
lineage. The structure reserves a durable Sessions destination for later search,
folders, and tags without adding those schemas or presenting them as 0.2
features. Stable automation identifiers cover the destination, current/recent/
history groups, switching, Finished detail, lineage, and continuation.

## Native product targets and destinations

`KitchenMemory` is one native multiplatform target supporting iPhone, iPad, iOS
Simulator, and native Mac destinations. Destination selection still produces
separate platform binaries, bundles, entitlement surfaces, archives, and launch
behavior. SDK-conditional settings select four platform/configuration-specific
entitlement files; platform filters keep the localized launch storyboard and
launch asset catalog in iOS products only.

Mac Catalyst, Mac Designed for iPhone or iPad, and visionOS Designed for iPhone
or iPad are explicitly unsupported. This keeps Xcode and Xcode Cloud destination
lists aligned with products the project actually builds and accepts. A future
Catalyst, visionOS, or tvOS product requires an explicit decision with its own
interaction, capability, testing, and release contract. See
[ADR 0013](adr/0013-unified-native-multiplatform-app-target.md).

The tvOS client should emphasize legibility at kitchen distance, simple remote
navigation, clear progress through instructions, timers, and reliable access to
recipes selected elsewhere. It is not intended to provide the full recipe editor,
database administration, bulk import, or pantry-management surfaces of the Mac
app.

## Architectural aim

Current source and module ownership live in
[implementation architecture](implementation-architecture.md). Recipe and Session
intentions cross separate KitchenKit Logic interfaces; future automation should
consume those interfaces instead of reproducing view state or storage rules.
An eventual tvOS client would provide its own read/cook presentation over the
same core, without constraining Mac or mobile interaction.

## Comprehension and modularity

Keep compiler modules aligned with independently consumable products rather
than creating one per entity or feature screen. Within KitchenKit, preserve its
durable responsibilities through folders, interfaces, small types, explicit
data flow, domain vocabulary, and the fewest layers that maintain the accepted
boundaries.

This application does not need speculative infrastructure for hypothetical
scale. Optimize first for correctness and comprehension; measure before adding
performance complexity. Use comments to explain non-obvious framework idioms
and constraints, not to restate clear code.

## macOS as a first-class platform

The Mac experience should eventually take advantage of:

- Multiple windows and recipe tabs.
- Menu commands with complete keyboard shortcuts.
- Drag and drop for URLs, images, PDFs, and text.
- Dense tables, sidebars, inspectors, and batch editing.
- Quick Look previews and Spotlight indexing.
- Services and Share menu integration.
- AppleScript and Shortcuts actions.
- A recipe-import inbox for asynchronous and batch work.

SwiftUI can provide the shared application structure while allowing AppKit
bridges for capabilities that need them. Avoid hiding the domain behind view
state so AppKit and automation paths remain peers of the SwiftUI interface.

## AppleScript direction

Scriptability should expose a small semantic object model rather than reproduce
every database field.

An eventual vocabulary might read naturally:

```applescript
tell application "Kitchen Memory"
    set importedRecipes to import recipes from folder scansFolder
    repeat with importedRecipe in importedRecipes
        if review status of importedRecipe is needs review then
            add tag "recipe-card scan" to importedRecipe
        end if
    end repeat
end tell
```

Likely scriptable nouns:

- `recipe`
- `ingredient section`
- `ingredient line`
- `instruction section`
- `instruction step`
- `import job`
- `kitchen`

Likely commands:

- `import recipe from URL`
- `import recipes from files`
- `export recipes`
- `find recipes`
- `open recipe`
- `add tag`

The exact terminology should stabilize only after the native UI and use cases
have been exercised. Once published, an AppleScript dictionary becomes a public
API and should change conservatively.

## Recipe-card batch workflow

The motivating advanced workflow is a folder of scans:

```text
folder of scans
 → enumerate supported images/PDFs
 → group front/back or multipage cards
 → preserve the original files
 → OCR text and detect layout
 → infer recipe fields and sections
 → create import drafts
 → automatically save high-confidence drafts
 → place ambiguous drafts in the review inbox
 → emit a machine-readable result for automation
```

Important properties:

- Idempotent: repeating a job should detect already-imported source content.
- Resumable: one bad scan must not fail the whole folder.
- Auditable: every recipe retains its source files and import diagnostics.
- Noninteractive by default: automation returns results rather than opening a
  modal dialog for every uncertainty.
- Reprocessable: improved OCR or parsing may regenerate a draft without
  overwriting user edits.

Content digests and stable import-job identifiers should exist before this
feature ships, even if scanning itself comes much later.

## Automator and Shortcuts

Automator remains a useful integration point for existing Mac workflows, but a
Shortcuts action and scriptable app are the more durable product surfaces. The
shared KitchenKit Logic operations allow all three to coexist:

- AppleScript for rich Mac automation and querying.
- Shortcuts/App Intents for approachable cross-device actions.
- Automator via Run AppleScript, Shortcuts, Services, or a future command-line
  companion.

## Current foundation and next implications

The app already implements Recipe and Cooking Session authority, recoverable
editing drafts, private Recipe images, Folder/Tag organization, localized
sample content, and private managed synchronization. Batch import, scanning,
AppleScript, Shortcuts, and tvOS remain direction, not shipped interfaces.
[Current contracts](README.md#product-contracts) and the live issue graph define
the next accepted scope. The comprehensive UI design pass and beta acceptance
follow [the accessibility policy](accessibility-engineering.md).
