# 0.1 roadmap and release boundary

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


- Status: 0.1 public alpha published
- Baseline completed: 2026-08-23
- Alpha artifact accepted: 2026-08-25

This roadmap records the feature slices that produced the 0.1 baseline and the
boundary between feature development and release engineering. Slices 1 through
10 and the deliberately reduced public-alpha acceptance exercise are complete.
Version 0.1.0 is published as a signed and notarized direct-download macOS
application in a GitHub prerelease; public iOS and TestFlight distribution
remain later work.

## Alpha definition

Kitchen Memory's 0.1 feature baseline lets one person save or import recipes
faithfully, correct them without re-entry, scale usable quantities, read them
without returning to the source webpage, and find the same library on their
supported Apple devices.

The alpha validates the recipe loop:

```text
Manual entry or webpage URL
            ↓
     Review and correction
            ↓
       Saved recipe revision
            ↓
        Scale and read
            ↓
 Private iCloud synchronization
```

The app remains local first throughout this work: the local store remains usable
without a network connection, and iCloud moves durable changes between devices
rather than becoming the only copy. Each slice preserves original source text.
Cooking-session state remains distinct from canonical recipe editing, but that
workflow is deferred to the 0.2 feature release.

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

### Slice 9 — Internationalization foundation (implemented 2026-08-22)

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
  it through drafts, imports, sample assets, and the pre-release V1 store.
- Preserve imported and person-authored recipe language instead of translating
  stored content as a side effect of changing the app locale.
- Document translator context, recipe-resource ownership, and the boundary
  between authored content and interface copy.

This slice internationalizes the existing experience without declaring its
editor layout final. Detailed localized UI automation, screenshot proofing, and
release-level accessibility audits still wait for stable platform interfaces.

The foundation now includes the three-locale String Catalog, application-owned
formatters, plural rules, authored-language persistence and import, localized
sample families, deterministic fallback, explicit-locale tests, and an opt-in
sample installation flow. The onboarding answer is stored outside recipe data,
but sample presence is derived from stable UUIDs and missing content is never
reinserted without an explicit request. This supports a future downloadable-
pack migration without turning an onboarding response into permanent authority.
Because V1 has no external users, the schema was updated in place and development
stores were reset instead of manufacturing a migration.

### Slice 10 — iCloud synchronization foundation (implemented 2026-08-23)

Make the existing recipe library available across one person's devices without
leaking CloudKit concepts into the domain or Logic layers.

- Choose and document the initial private-database integration after a focused
  prototype of SwiftData-managed synchronization and its recovery behavior.
- Make the current persistence records compatible with the chosen CloudKit
  integration before promoting any production schema.
- Preserve application-owned Kitchen, recipe, revision, child-row, and media
  identifiers across devices.
- Synchronize the complete recipe graph, including immutable revision history,
  source evidence, authored-language metadata, and sample-recipe identities.
- Keep local reads and writes useful while offline, and surface account, setup,
  import, and export failures without presenting speculative success.
- Define deterministic convergence for concurrent edits, deletion, sample-pack
  installation, and recovery after interrupted synchronization.
- Exercise the development schema on multiple devices and document the explicit
  production-promotion checklist.
- Establish the post-release rule that SwiftData schemas are versioned and the
  production CloudKit schema evolves additively. Published record types and
  fields are never repurposed to mean something else.

Household invitations, shared-database permissions, and live collaboration do
not belong to this foundation. The repository and synchronization boundaries
must leave room for them without pretending private cross-device sync proves
their behavior.

The slice established the V1 personal CloudKit configuration, stable identity
and convergence rules, observable account and transfer status, remote-store
refresh, development schema administration, and recovery documentation. Local
and cloud persistence now live together behind `KitchenMemoryPersistence`,
while Domain and Logic remain independent of Apple storage mechanics.

## 0.1 release engineering — Completed alpha exercise

The feature loop moved through its first release-engineering pass. This work was
deliberately not numbered as Slice 11: its unit of progress was release evidence,
not another feature increment.

The pass established final green candidate builds, protected release tagging,
V1 production-schema promotion, privacy and localization contracts, physical-
device Development acceptance, and a signed, notarized, post-extraction-
validated Mac artifact that launched outside Xcode. When Xcode Cloud failed to
import the release tag, the alpha used an explicit local Developer ID archive
fallback without moving the immutable tag. Public iOS/TestFlight distribution
and the broader 1.0-quality acceptance matrix remain deferred. Full results live
in <doc:release-evidence-0.1>.

## 0.2 feature release — Cooking sessions

Cooking sessions become the first post-alpha product capability. A bounded
0.1.2 polish pass precedes four versioned feature slices: session foundation,
cooking progress, cheap notes and deviations, and history plus release closure.
The detailed scope, decision gates, exit criteria, and explicit deferrals live
in <doc:roadmap-0.2>.

The current domain and persistence model do not implement the session aggregate.
Version 0.2 introduces it through an immutable SwiftData schema version and
additive CloudKit records without rewriting existing recipe content.

## Sequence and boundaries

```text
Structured editing
  → Import engine
    → URL import and review
      → Scaling and reading
        → Cleanup and refactor
          → Internationalization foundation
            → iCloud synchronization foundation
              → 0.1 release engineering
                → 0.1.2 alpha polish
                  → 0.2 cooking-session slices
```

Pantry holdings, shopping lists, planned cooks, cooking sessions, meal planning,
household sharing, OCR, and social features are intentionally outside the alpha.
Household sharing is also explicitly deferred until after 1.0. The domain seams
for these capabilities remain important, but they should not delay validation
of the complete recipe import, correction, scaling, reading, and private
cross-device synchronization loop.
