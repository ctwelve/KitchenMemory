# Apple platform and automation architecture

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


The product uses separate native SwiftUI application targets for iPhone and
iPad, and for Mac, with a display-centric tvOS client planned for a later phase.
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
compromised interface. See <doc:0006-shared-ui-for-foundation-slices>.

## Native product targets and destinations

`KitchenMemory iOS` is the native iPhone and iPad product.
`KitchenMemory macOS` is the native Mac product. Their shared 0.1 source layer
does not make them one runnable, archive, entitlement surface, or launch-screen
contract.

The iOS target supports iOS devices and iOS Simulator only. Mac Catalyst, Mac
Designed for iPhone or iPad, and visionOS Designed for iPhone or iPad are
explicitly unsupported. The macOS target supports native macOS destinations
only. This keeps Xcode and Xcode Cloud destination lists aligned with products
the project actually builds and accepts. A future Catalyst, visionOS, or tvOS
target must be an explicit product decision with its own interaction,
capability, testing, and release contract. See
<doc:0009-separate-native-app-targets>.

The tvOS client should emphasize legibility at kitchen distance, simple remote
navigation, clear progress through instructions, timers, and reliable access to
recipes selected elsewhere. It is not intended to provide the full recipe editor,
database administration, bulk import, or pantry-management surfaces of the Mac
app.

## Architectural aim

The current SwiftUI application crosses durable product boundaries through
`RecipeLibraryModel`, which delegates to the same `KitchenMemoryLogic` operations
that future automation and platform-specific interfaces will use:

```text
SwiftUI views
   ↓
RecipeLibraryModel
   ├── RecipeLibrary ────────┐
   ├── RecipeEditor ────────├──→ RecipeRepository
   ├── KitchenResetService ──┘
   └── RecipeImportService ───→ KitchenMemoryImport
```

`RecipeLibraryModel` is application glue, not the only permitted client. A
Safari share extension, file importer, AppleScript command, Shortcut, or batch
tool should call the relevant Logic operation directly and exchange domain
values or structured results. Automation must not manipulate persistence
objects or UI elements. This keeps every client independent of SwiftData,
CloudKit, and a particular window layout.

## Current module boundaries

### KitchenMemoryDomain

Plain Swift domain values and rules:

- Kitchens, recipes and revisions, ingredients, pantry knowledge, plans,
  sessions, sources, media, and organization.
- Scaling and validation.
- Stable application identities independent of persistence and sync frameworks.
- No SwiftUI, SwiftData, CloudKit, document scanning, or Apple Events.

The domain should be usable from the app, extensions, tests, and a potential
command-line companion.

### KitchenMemoryImport

The deterministic and bounded web import pipeline:

- Discovers and decodes Schema.org `Recipe` JSON-LD.
- Normalizes recipe candidates and preserves bounded source evidence.
- Conservatively interprets ingredient lines without discarding original text.
- Fetches person-entered URLs through a bounded, ephemeral URLSession adapter.
- Produces reviewable candidates without saving them.

Import produces a draft. Saving that draft is a separate product-logic decision.
This distinction is essential for unattended batch processing: ambiguous cards
can land in an inbox rather than being silently turned into bad recipes.

### KitchenMemoryPersistence

Repository interfaces and mapping expressed in domain terms. The first
implementation uses SwiftData, but callers do not receive storage-framework
model objects. CloudKit integration remains behind the application boundary.

### KitchenMemoryLogic

Product operations and presentation-independent workflow state that coordinate
the domain, importer, and store. The implemented boundary includes:

```text
RecipeLibrary          Kitchen-scoped reads and revision history
RecipeEditor           create and revise immutable recipes
RecipeImportService    interpret URL-import results for review
KitchenBootstrapService / KitchenResetService
RecipeEditSession      transient structured edit state
RecipeImportSession    transient import and candidate-selection state
RecipeScalingState     transient working-yield selection
```

File import, search, export, batch work, and cooking sessions will extend this
same boundary when their slices arrive.

### KitchenMemory application layer and native targets

The shared `KitchenMemory/` layer contains the SwiftUI interface,
`RecipeLibraryModel` composition glue, bundled sample resources, and
localization catalogs, with membership in both native app targets.
Platform-owned resources, entitlements, and future presentation code belong in
`KitchenMemoryIOS/` or `KitchenMemoryMac/`; reusable recipe behavior does not.
See <doc:implementation-architecture> and <doc:localization-architecture>.

An eventual tvOS target should consume `KitchenMemoryDomain` and the read/cook-oriented
Logic operations while supplying its own focused presentation layer. Its
future existence must not force television interaction constraints into the
Mac, iPhone, or iPad interface.

## Comprehension and modularity

Keep modules aligned with durable responsibilities rather than creating one
module per entity or feature screen. Within them, prefer small types, explicit
data flow, domain vocabulary, and the fewest layers that preserve the accepted
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
shared `KitchenMemoryLogic` use cases allow all three to coexist:

- AppleScript for rich Mac automation and querying.
- Shortcuts/App Intents for approachable cross-device actions.
- Automator via Run AppleScript, Shortcuts, Services, or a future command-line
  companion.

## Current foundation and next implications

The implemented 0.1 feature baseline already provides UI-independent domain
values, reviewable import drafts, stable recipe/source identities, SwiftData and
personal iCloud synchronization behind the persistence boundary, localized
sample content, and shared Logic operations. Release engineering should preserve
those boundaries while it:

1. proves the existing private, local-first iCloud path on real devices and
   rehearses production schema promotion;
2. verifies the established String Catalogs and localized asset-backed recipe
   packs under release conditions;
3. produces signed, installable, diagnosable iOS and macOS candidates; and
4. records a repeatable release procedure before 0.2 feature development.

After that baseline is established, platform feature work can replace
provisional modal editing with interaction models suited to Mac and mobile, add
cooking sessions without mutating maintained recipe revisions, introduce
batch-capable import interfaces before scan/OCR inputs, and keep fixtures
extensible to files and scans as well as webpages.
