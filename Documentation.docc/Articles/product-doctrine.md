# Product doctrine

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


- Status: Accepted direction
- Date: 2026-08-09

This document consolidates the product ideas that should guide later design and
implementation. It is deliberately more stable than the exploratory workflow
documents and deliberately less specific than an implementation specification.

## Product thesis

Kitchen Memory is a collaborative kitchen memory that is comfortable admitting
uncertainty.

> Cook, remember, improve.

It preserves what a recipe source said, what a household currently intends to
cook, what happened during a particular attempt, and what the household believes
is in the pantry—without collapsing those different kinds of truth.

```text
Published source       what the source said
Maintained recipe      what this kitchen currently intends
Planned cook           what the kitchen intends to make this time
Cooking session        what actually happened this time
Pantry observation     what the kitchen currently believes it has
```

The system should make correction extraordinarily cheap. Intelligence is useful
when it reduces work; uncertainty is preferable to invented precision.

## The nine core concepts

### Kitchen

The collaboration and ownership boundary. A kitchen contains the shared recipe
library, ingredient vocabulary, pantry knowledge, organization, and participating
people.

### Recipe

The durable identity of a maintained dish or preparation. A recipe has revisions
rather than being identified with one mutable representation.

### Recipe revision

One intended version of a recipe: metadata, yield, ingredients, instructions,
organization, and recipe-level media. A revision may derive from an import,
manual editing, or selected discoveries from cooking sessions.

### Cooking session

One performance of one recipe revision. It records working scale, progress,
deviations, observations, outcome, and session media without silently rewriting
the maintained recipe.

### Ingredient

A normalized kitchen concept that connects recipe requirements, pantry knowledge,
and suggestions. It is neither a commercial product nor a line of recipe text.

### Pantry holding

One separately meaningful amount or presence of an ingredient: a package, jar,
loose quantity, or simple “we have it.” An ingredient may have several holdings
with different precision, locations, package states, and ages.

### Planned cook

One intention to prepare a particular recipe revision at a particular scale,
optionally on a date. It reconciles ingredient requirements with pantry evidence,
shopping decisions, substitutions, omissions, and advance preparation before a
cooking session begins.

### Source capture

Preserved evidence used to create a recipe draft or revision: webpage JSON-LD,
URL, feed entry, scanned card, document, or attributed human source. It supports
lossless reprocessing and provenance.

### Media asset

An original photograph, scan, video, or other media object. Contextual attachments
associate the asset with a source capture, recipe revision, cooking session,
ingredient, or instruction step without unnecessary duplication.

## Structural relationships

```text
SourceCapture
      ↓
  ImportDraft
      ↓
Recipe ──→ RecipeRevision ──→ CookingSession
                 │       ↑           │
                 ├─→ PlannedCook ────┤
                 └──── MediaAsset ───┘

RecipeIngredient ──→ Ingredient ←── PantryHolding[]
```

`ImportDraft` is a workflow boundary rather than necessarily a durable domain
entity. It ensures that acquisition never writes questionable interpretations
directly into the library.

`PlannedCook` is the shared unit beneath both single-recipe readiness and future
weekly meal planning. A meal plan organizes planned cooks rather than creating a
second execution model.

## Accepted simplifications

### Schema.org fidelity, not a Schema.org-shaped app

The application will preserve imported Schema.org `Recipe` source losslessly,
accept its legal alternate shapes, and map meaningful recipe concepts natively.
Unknown or not-yet-modeled properties remain in the source capture for later
interpretation.

“Full support” does not mean providing an editor control for every inherited
`CreativeWork` property. It means source-compatible import, preservation, and
progressive native understanding.

### Folders locate; tags classify

A recipe initially has zero or one primary folder and any number of tags.

- Folders provide a human navigational hierarchy and sense of place.
- Tags provide overlapping many-to-many classification.
- Saved searches and smart collections may later project dynamic organization.

Direct multi-folder membership is deferred. Aliases or smart collections may
eventually provide that experience without complicating recipe identity.

### Small pantry vocabulary

A holding may express:

```text
exact        425 g
container    1 unopened bottle
fuzzy        a little | some | plenty
presence     have it
uncertain    maybe
```

Forms may combine where useful, such as `1 open bottle · a little`. Qualitative
labels remain deliberately few until household use demonstrates a need for more.

### No fake aggregation

Unlike amounts coexist without being forced into one total. The app may infer an
explainable availability state:

```text
available
probably available
possibly insufficient
unknown
unavailable
```

It does not convert “425 g + one unopened package + a little” into fabricated
arithmetic.

### Pantry knowledge is observed and becomes stale

Current pantry state is based on observations. Holdings retain when and, when
relevant, by whom they were observed. The implementation need not be fully event-
sourced, but it must leave room for staleness, cleanup, and correction.

### Readiness maintenance is opportunistic

Reconciling a planned cook is a natural moment to correct stale pantry knowledge.
“Have,” “purchase,” “substitute,” “skip,” and “need to check” are decisions for
one planned cook; accepting or correcting pantry evidence may also create a new
observation. The app should ask when the answer matters rather than demand routine
inventory audits.

### One recipe and one week use the same planning unit

A single planned cook can produce shopping and preparation decisions. A weekly
plan is a dated collection of planned cooks using the same reconciliation rules.
Combined shopping preserves which planned cooks created each requirement.

### Cooking sessions become durable on meaningful activity

Viewing a recipe is not automatically permanent history. A cooking session
becomes durable when a person explicitly starts cooking or records meaningful
activity such as progress, a timer, a note, media, or a deviation.

### One media asset model

Scans, recipe photographs, session photographs, and video share one media asset
concept. Promotion from a session to a recipe creates an intentional contextual
attachment rather than silently moving or duplicating the original.

### Social features begin modestly

The early cooking-history vocabulary is:

- Session outcome: great, okay, or unsuccessful.
- Session notes and deviations.
- Session media.
- Lightweight family reactions later.

Durable recipe ratings, threaded comments, notifications, and richer social
behavior remain optional future features rather than foundational requirements.

### Feeds are acquisition sources

RSS, Atom, and JSON feeds produce candidate URLs or documents for the existing
import pipeline. They do not define a second recipe database or synchronization
model. By default, feed discoveries belong in an inbox rather than being silently
saved.

### Assistance is capability-based and replaceable

The product does not depend on a monolithic “AI service.” It may request narrow
capabilities such as:

```text
recognizeText(image)
parseIngredient(line)
suggestIngredient(text)
structureRecipe(text)
rankSearchResults(query)
```

An implementation may use deterministic logic, local search, Apple frameworks,
an on-device model, a remote model, or a composition. Original input remains
available and assisted changes are visible, reversible, and optional.

## Interaction doctrine

### Reading is the default recipe experience

A recipe is primarily something to read. Database editing is explicit. Cooking
mode adds lightweight session controls without turning the presentation into an
administration form.

### Progressive detail

- An ingredient line may remain unparsed.
- A pantry item may be simple presence or several detailed holdings.
- A cooking session may contain one note or a rich media history.
- A recipe may be unfiled and untagged.

The system rewards detail without requiring it before the object is useful.

### Explain suggestions

Pantry cleanup, shopping advice, duplicate detection, parsing, and recipe-change
prompts should state why they appeared. The user can accept, correct, defer, or
dismiss them.

### Promote; do not silently mutate

Information moves between contexts intentionally:

- A source capture creates a reviewed recipe revision.
- A recipe revision and desired yield create a planned cook.
- Planned decisions carry into a cooking session without editing the recipe.
- Session media may be promoted to recipe media.
- Session deviations may become a revision or variant through an explicit diff.
- Session evidence may suggest a pantry correction.

## Platform doctrine

- macOS is the full library-management, batch-work, and automation environment.
- iPhone emphasizes capture, shopping, quick interaction, and cooking.
- iPad emphasizes cooking, planning, and comfortable editing.
- tvOS is a later display-centric cooking client without feature-parity goals.

The platforms share the domain and relevant application capabilities. They do not
share one compromised interface.

SwiftData is the first local persistence implementation. CloudKit is the
Apple-native synchronization and household-collaboration platform. The domain
remains independent of both, and versioned import and export provide content
portability. The exact shared-Kitchen CloudKit integration follows a focused
collaboration prototype; see ADRs 0003 and 0004.

## Capability horizons

Horizons communicate dependency and focus, not dates or promises.

### Foundation

- Manual recipe entry and editing.
- Recipe sections, ingredients, instructions, yield, and core metadata.
- Lossless Schema.org JSON-LD URL import into reviewable drafts.
- Local recipe library with folders and tags.
- Recipe reading and basic cooking sessions with progress and notes.
- A basic planned cook that retains recipe revision and desired yield.
- Domain, import, storage, and UI boundaries suitable for multiple Apple targets.

### Expansion

- Kitchen sharing and synchronization.
- Pantry items with multiple exact, fuzzy, presence, and uncertain holdings.
- Ingredient readiness decisions, combined shopping, and weekly collections of
  planned cooks.
- Session deviations, outcomes, media, and revision promotion.
- Shopping suggestions and lightweight pantry cleanup.
- Safari sharing, richer Mac workflows, and saved searches.

### Advanced

- Recipe-card scanning and assisted transcription.
- Batch folder ingestion, AppleScript, Shortcuts, and command-line automation.
- Feed subscriptions and acquisition inboxes.
- Explainable planning and replenishment suggestions.
- tvOS cooking presentation.
- Richer family reactions and cooking history if actual use warrants them.

Capabilities may move between horizons as prototypes reveal dependencies. The
foundation should be enjoyable and useful without requiring the advanced vision.

## Not yet decided

- Exact CloudKit integration for multi-participant Kitchen sharing.
- Exact revision and conflict-resolution mechanics.
- Ingredient parser or assistance implementations.
- Media storage and quality policy.
- Pantry observation storage strategy.
- Public distribution and App Store strategy.
- Product-name availability, trademark research, and final bundle/repository
  naming for the working name “Kitchen Memory.”

These are later design decisions, not omissions from the product vision.
