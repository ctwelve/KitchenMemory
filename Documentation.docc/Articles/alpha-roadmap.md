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

Added a pure `KitchenMemoryImport` package layer for deterministic Schema.org
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

## Remaining slices

### Slice 7 — Scaling and recipe reading

Make recipes adaptable to the intended yield while remaining honest about
quantities that cannot be scaled automatically.

- Select a working yield from a recipe's usable numeric yield.
- Scale exact and ranged linear quantities with rational arithmetic.
- Leave text, fixed, and manual-review quantities intact and visibly explain why.
- Provide accessible, readable base and scaled recipe presentations.

**Complete when:** representative recipes scale predictably without converting
fractions to inaccurate floating-point text or silently changing ambiguous
amounts.

### Slice 8 — Cooking sessions

Support real cooking without silently changing the maintained recipe.

- Start and resume a session for a specific recipe revision and working scale.
- Provide full-recipe and step-by-step cooking presentations.
- Persist ingredient and step checkoffs.
- Record quick notes, skips, substitutions, and other deviations.
- Finish or abandon a session while retaining its history and recipe-revision
  reference.

**Complete when:** a cook can prepare a recipe entirely from the app, return
later to a session, and see what happened without altering the canonical recipe.

### Slice 9 — Alpha hardening

Prove that the completed loop is dependable enough for household use.

- Add migration, error, and recovery coverage for persisted local data.
- Expand importer fixtures and domain/application/UI regression tests.
- Audit the finished workflows for accessibility on supported Apple platforms.
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
        → Cooking sessions
          → Alpha hardening
```

Pantry holdings, shopping lists, planned cooks, meal planning, synchronization,
OCR, and social features are intentionally outside the alpha. The domain seams
for them remain important, but they should not delay validation of the complete
recipe import, correction, scaling, and cooking loop.
