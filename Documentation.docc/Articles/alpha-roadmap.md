# Alpha roadmap

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


- Status: Accepted direction
- Date: 2026-08-11

This roadmap divides the remaining work between the completed local-persistence
foundation and a full working alpha. It is intentionally outcome-oriented: each
slice should leave the app more useful on its own and have clear acceptance
criteria.

## Alpha definition

Kitchen Memory reaches alpha when one household can locally save or import
recipes faithfully, correct them without re-entry, scale usable quantities, and
cook from the application without returning to the source webpage.

The alpha validates the recipe loop:

```text
Manual entry or webpage URL
            ↓
     Review and correction
            ↓
       Saved recipe revision
            ↓
         Scale and cook
            ↓
  Cooking-session record of reality
```

The app remains local first throughout this work. Each slice preserves original
source text and keeps canonical recipe editing distinct from a cooking session.

## Completed slices

### Slice 1 — Proof of concept

Established that the project direction, Apple-native approach, and basic recipe
experience were viable.

### Slice 2 — Skeleton

Created the SwiftUI application, domain/application boundaries, sample content,
accessibility foundation, tests, and continuous integration.

### Slice 3 — Local persistence

Added SwiftData storage, first-launch kitchen setup and sample seeding, a local
recipe library, manual creation and editing, and immutable recipe revisions.

### Slice 4 — Structured recipe editing

Made manual entry genuinely useful rather than a text-only fallback.

The editor now handles metadata, yield, times, source attribution, multi-section
ingredients and instructions, and optional structured ingredient details. It
preserves original ingredient wording, keeps incomplete recipes valid, and saves
edits as immutable revisions that retain their structure after relaunching.

### Slice 5 — Import engine

Added a pure `KitchenMemoryImport` module for deterministic Schema.org
`Recipe` JSON-LD discovery and normalization. It accepts captured HTML or JSON-LD,
collects candidates across blocks and `@graph`, retains source-faithful JSON-LD
evidence,
maps recipe metadata, normalizes instruction shapes, and conservatively interprets
ingredient quantities without losing their original wording. Checked-in fixtures
cover ambiguous, malformed, nested, partial, structured, relative-URL, and unsafe
input families.

### Slice 6 — URL import and review

Connected the deterministic engine to a person-facing acquisition workflow.
Kitchen Memory now accepts a webpage URL, fetches it through a bounded ephemeral
`URLSession`, automatically advances one clear candidate or presents a choice,
and opens the result in the structured editor for review before saving. Imported
revisions retain bounded JSON-LD source evidence and visible source attribution.
The fetcher runs no page scripts, stores no cookies, downloads no images, limits
redirects, response bytes, and candidate fan-out, and rejects obvious local or
credential-bearing destinations.

### Slice 7 — Scaling and recipe reading

Made recipes adaptable to a selected working yield without changing the saved
recipe revision. Exact and ranged linear ingredient quantities now scale with
rational arithmetic, while fixed, written, manually reviewed, and otherwise
unsafe amounts remain intact with visible guidance. Recipes with approximate or
ranged numeric yields expose honest scaling bases, and structured yield editing
can make previously text-only yields scalable.

The reading presentation provides accessible working-yield controls, preserves
the base yield for context, refreshes after an immutable revision is saved, and
reminds cooks that equipment does not scale automatically.

## Remaining slices

### Slice 8 — Cleanup and refactor pass

Make the completed foundation cheaper to change before adding another major
workflow.

- Collect coverage for the shared test plan and establish the durable
  business-logic source boundary.
- Reach complete coverage of meaningful executable business logic and document
  any narrow exclusions that cannot represent product behavior.
- Move any business rules that remain embedded in SwiftUI views into testable
  domain or application operations.
- Keep UI automation to smoke tests for launch, sidebar navigation, Settings,
  and destructive-reset confirmation.
- Remove obsolete UI and accessibility audit machinery tied to replaceable
  editor and reading presentations.
- Reconcile engineering documentation and CI guidance with the new testing
  boundary.

This slice does not redesign the editor or treat the current English interface
as final. In-page editing, String Catalog adoption, localization proofing, and
comprehensive accessibility validation follow once the relevant interface work
is stable.

**Complete when:** every meaningful business-logic branch is covered or has a
narrow documented exclusion, the coverage report can distinguish durable logic
from presentation code, and the UI suite contains only the agreed shell smoke
tests.

### Slice 9 — Cooking sessions

Support real cooking without silently changing the maintained recipe.

- Start and resume a session for a specific recipe revision and working scale.
- Provide full-recipe and step-by-step cooking presentations.
- Persist ingredient and step checkoffs.
- Record quick notes, skips, substitutions, and other deviations.
- Finish or abandon a session while retaining its history and recipe-revision
  reference.

**Complete when:** a cook can prepare a recipe entirely from the app, return
later to a session, and see what happened without altering the canonical recipe.

### Slice 10 — Alpha hardening

Prove that the completed loop is dependable enough for household use.

- Reach complete business-logic coverage, including migration, error, recovery,
  and source-preservation behavior.
- Expand importer fixtures and domain/application regression tests while keeping
  UI automation to application-shell smoke tests.
- Establish String Catalogs and complete the internationalization pass after the
  relevant interface and product language stabilize.
- Audit the stable, finished workflows for accessibility on supported Apple
  platforms.
- Validate macOS and iOS builds and document local backup/export expectations.
- Run an alpha acceptance set of roughly twenty varied real recipes.

**Complete when:** all acceptance recipes import or enter successfully, retain
their meaningful content after relaunch, scale safely where supported, and can be
cooked through in the application.

## Sequence and boundaries

```text
Structured editing
  → Import engine
    → URL import and review
      → Scaling and reading
        → Cleanup and refactor
          → Cooking sessions
            → Alpha hardening
```

Pantry holdings, shopping lists, planned cooks, meal planning, synchronization,
OCR, and social features are intentionally outside the alpha. The domain seams
for them remain important, but they should not delay validation of the complete
recipe import, correction, scaling, and cooking loop.
