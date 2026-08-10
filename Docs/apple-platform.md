<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# Apple platform and automation architecture

The product is a native SwiftUI application for iPhone, iPad, and Mac, with a
display-centric tvOS client planned for a later phase. The Mac application is not
merely an enlarged phone interface: it should grow into a powerful library-
management and automation environment while sharing the same recipe domain and
import engine.

## Platform roles

The platforms share a recipe domain, but they do not need feature parity.

| Platform | Primary role |
| --- | --- |
| macOS | Full library management, editing, import review, batch work, and automation |
| iPhone | Capture, shopping, quick edits, and cooking |
| iPad | Cooking, planning, and comfortable recipe editing |
| tvOS | Hands-off, display-centric cooking guidance |

The tvOS client should emphasize legibility at kitchen distance, simple remote
navigation, clear progress through instructions, timers, and reliable access to
recipes selected elsewhere. It is not intended to provide the full recipe editor,
database administration, bulk import, or pantry-management surfaces of the Mac
app.

## Architectural aim

Every way of adding a recipe should call the same application capability:

```text
SwiftUI editor ───────────────┐
Safari share extension ──────┤
File importer ───────────────┼─→ ImportRecipe use case → Recipe library
AppleScript command ─────────┤
Shortcuts action ────────────┤
Folder/CLI batch importer ───┘
```

Automation must not manipulate persistence objects or UI elements directly.
It invokes stable use cases using transferable values and receives structured
results. This keeps AppleScript, Shortcuts, tests, and future tools from becoming
coupled to SwiftData, CloudKit, or a particular window layout.

## Proposed module boundaries

### KitchenMemoryDomain

Plain Swift domain values and rules:

- Kitchens, recipes and revisions, ingredients, pantry knowledge, plans,
  sessions, sources, media, and organization.
- Scaling and validation.
- Stable application identities independent of persistence and sync frameworks.
- No SwiftUI, SwiftData, CloudKit, document scanning, or Apple Events.

The domain should be usable from the app, extensions, tests, and a potential
command-line companion.

### RecipeImport

An asynchronous import pipeline:

- Input discovery and type detection.
- Schema.org JSON-LD decoding.
- Later: OCR, image cleanup, PDF handling, and ingredient interpretation.
- An `ImportDraft` result containing warnings, confidence, and source evidence.

Import produces a draft. Saving that draft is a separate application decision.
This distinction is essential for unattended batch processing: ambiguous cards
can land in an inbox rather than being silently turned into bad recipes.

### KitchenMemoryPersistence

Repository interfaces and mapping expressed in domain terms. The first
implementation uses SwiftData, but callers do not receive storage-framework
model objects. CloudKit integration remains behind the application boundary.

### RecipeApplication

Use cases that coordinate the domain, importer, and store. Candidate operations:

```text
createRecipe
updateRecipe
importRecipe
importFiles
listRecipes
findRecipes
exportRecipes
```

These operations form the conceptual automation API even before AppleScript is
implemented.

### RecipesApp

The SwiftUI interface and Apple-platform integrations. Platform-specific scenes
and commands belong here; reusable recipe behavior does not.

An eventual tvOS target should consume `KitchenMemoryDomain` and the read/cook-oriented
application use cases while supplying its own focused presentation layer. Its
future existence must not force television interaction constraints into the
Mac, iPhone, or iPad interface.

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
tell application "Recipes"
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
shared `RecipeApplication` use cases allow all three to coexist:

- AppleScript for rich Mac automation and querying.
- Shortcuts/App Intents for approachable cross-device actions.
- Automator via Run AppleScript, Shortcuts, Services, or a future command-line
  companion.

## Near-term implications

The first implementation does not need AppleScript support. It does need:

1. A domain module independent of UI and persistence frameworks.
2. An importer that returns drafts instead of saving directly.
3. Stable UUIDs for recipes, source captures, and import jobs.
4. Batch-capable import interfaces, even if the first UI imports one URL.
5. Fixtures that can later include scans as well as webpages.
