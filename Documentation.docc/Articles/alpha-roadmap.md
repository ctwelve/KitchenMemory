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

Created the SwiftUI application, initial domain and use-case boundaries, sample content,
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

### Slice 8 — Cleanup and refactor pass

Made the completed foundation cheaper to change before adding another major
workflow.

The pass established exact line-coverage gates for `KitchenMemoryDomain`,
`KitchenMemoryImport`, `KitchenMemoryLogic`, and `KitchenMemoryPersistence`;
externalized deterministic property-test seeds; and reduced UI automation to
durable application-shell smoke tests. Product operations and pure edit, import,
and scaling workflow state now live in `KitchenMemoryLogic`. The application
composes those operations through `RecipeLibraryModel` and small platform
adapters instead of embedding business rules in SwiftUI.

The pass deliberately did not redesign the editor or treat the current English
interface as final. It made those later changes cheaper by separating durable
behavior from replaceable presentation.

## Remaining slices

### Slice 9 — Internationalization foundation

Make application language and bundled starter content correct for the initial
North American release.

- Establish String Catalogs for English, Canadian French (`fr-CA`), and Mexican
  Spanish (`es-MX`).
- Keep localization lookup and locale-aware formatting at the presentation
  boundary while logic returns semantic values and typed failures.
- Replace the domain's English display helpers and `"Ingredient"` sentinel with
  semantic validation plus application-owned localized formatters.
- Supply plural variants for count-bearing messages and test them with explicit
  locales rather than host settings.
- Extend the asset-backed sample-recipe pack with coherent localized recipe
  documents, deterministic locale fallback, and stable identity rules.
- Add optional authored-content language metadata to recipe revisions and carry
  it through drafts, imports, sample assets, and a versioned store migration.
- Preserve imported and person-authored recipe language instead of translating
  stored content as a side effect of changing the app locale.
- Document translator context, recipe-resource ownership, and the boundary
  between authored content and interface copy.

This slice internationalizes the existing experience without declaring its
editor layout final. Detailed localized UI automation, screenshot proofing, and
release-level accessibility audits still wait for stable platform interfaces.

**Complete when:** all durable user-facing copy is catalog-backed, count and
formatting behavior is verified for all three initial locales, every localized
sample asset passes structural and identity validation, and changing locale
cannot mutate existing recipe history.

### Slice 10 — Cooking sessions

Support real cooking without silently changing the maintained recipe.

- Start and resume a session for a specific recipe revision and working scale.
- Provide full-recipe and step-by-step cooking presentations.
- Persist ingredient and step checkoffs.
- Record quick notes, skips, substitutions, and other deviations.
- Finish or abandon a session while retaining its history and recipe-revision
  reference.

**Complete when:** a cook can prepare a recipe entirely from the app, return
later to a session, and see what happened without altering the canonical recipe.

### Slice 11 — Alpha hardening

Prove that the completed loop is dependable enough for household use.

- Reach complete business-logic coverage, including migration, error, recovery,
  and source-preservation behavior.
- Expand importer fixtures and framework regression tests while keeping
  UI automation to application-shell smoke tests.
- Verify localization completeness and representative longer-text layouts for
  every release locale.
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
          → Internationalization foundation
            → Cooking sessions
              → Alpha hardening
```

Pantry holdings, shopping lists, planned cooks, meal planning, synchronization,
OCR, and social features are intentionally outside the alpha. The domain seams
for them remain important, but they should not delay validation of the complete
recipe import, correction, scaling, and cooking loop.
