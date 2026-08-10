<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# Product workflows

- Status: Exploration

The accepted simplifications and stable product direction distilled from these
ideas are recorded in `product-doctrine.md`.

This document collects desired end-to-end behavior. It describes what a person
should be able to accomplish without committing every feature to the first
release or selecting a particular AI, search, persistence, or sync technology.

## Add a recipe

Every acquisition path produces an `ImportDraft` or editable recipe draft. The
user can review the result, enrich it, organize it, and save it through the same
application use case.

```text
Manual entry ────────────────┐
Web URL ─────────────────────┤
RSS / Atom / JSON feed ──────┼─→ Recipe draft → Review/edit → Organize → Save
Shared text or file ─────────┤
Recipe-card scan ────────────┘
```

This common draft boundary prevents each importer from inventing different rules
for recipes, provenance, warnings, or saving.

### Traditional entry

The editor supports deliberate key-in without requiring automation:

- Title, description, author, source, yield, timing, and other metadata.
- Ingredient sections and ordered ingredient lines.
- Instruction sections and ordered steps.
- Nutrition, equipment, media, cuisine, category, and dietary metadata where
  useful.
- Keyboard-friendly entry on Mac and comfortable touch entry elsewhere.
- Pasting multiple ingredient lines or steps at once.
- Reordering and moving rows between sections.
- Saving an incomplete draft and returning later.

The editor progressively enhances input rather than blocking on structure. A
line such as “a good glug of olive oil” remains valid even if no parser can turn
it into a conventional measurement.

### Smart suggestions

While an ingredient is entered, the app may suggest:

- Existing kitchen ingredients and aliases.
- Common units and container descriptions.
- Recently or frequently used ingredients.
- Likely parsing of quantity, unit, ingredient, and preparation.
- Duplicate or near-duplicate ingredient concepts.
- Section names inferred from surrounding rows.
- Pantry presence, shown as context rather than an editing constraint.

Suggestions should prefer deterministic local information first. Search indexes,
Natural Language/Vision frameworks, local models, or remote assistants may add
value later, but none should become necessary to enter or read a recipe.

Any assisted change must be visible, reversible, and distinguishable from the
user's original text. The product should use “AI” only where it removes work or
recovers information—not as a label for ordinary autocomplete and search.

### Import from URL

The URL importer follows the pipeline in `web-import.md`:

1. Discover Schema.org `Recipe` JSON-LD.
2. Preserve the source representation and attribution.
3. Map supported properties into the domain.
4. Preserve unsupported properties for later interpretation.
5. Provisionally parse ingredients and normalize instructions.
6. Present uncertain or conflicting fields for review.

A URL may be handed to the app through its editor, clipboard detection, drag and
drop, a Safari share extension, AppleScript, Shortcuts, or a future command-line
companion.

### Subscribe via RSS, Atom, or JSON Feed

A feed is a stream of acquisition candidates, not automatically a trusted recipe
database.

```text
Feed subscription
 → poll or refresh
 → discover new entries
 → identify likely recipe URLs or embedded recipe data
 → deduplicate by stable source identity/content digest
 → place candidates in an inbox
 → import selected recipes through the URL pipeline
```

Potential subscription policies:

- Show all new candidates.
- Automatically draft likely recipes.
- Automatically save only when rules and confidence permit it.
- Ignore entries matching user-defined filters.

The initial feed support can simply surface linked recipes. Directly importing
embedded feed content and JSON Feed attachments is a later enhancement. A failed
or changed feed must not damage recipes already saved from it.

### Scan a recipe card

The aspirational scan workflow uses the phone camera, photo library, scanner, or
Mac file import:

```text
Capture images
 → detect/crop card or page
 → correct perspective and improve readability
 → recognize text and layout
 → preserve original images
 → infer recipe fields, sections, ingredients, and steps
 → produce a reviewable draft with confidence and diagnostics
```

Handwriting, stains, unusual layouts, front/back cards, marginal notes, and
abbreviations make this intrinsically uncertain. The original scan is therefore
part of the source capture, and transcription creates a draft rather than a
recipe silently committed to the library.

The pipeline should allow layers:

1. On-device Vision text recognition when adequate.
2. Deterministic recipe parsing and layout rules.
3. Optional local or remote model assistance for ambiguous structure.
4. Human review focused on uncertain regions.

Batch scanning and folder automation are described in `apple-platform.md`.

## Organize recipes

Recipes may belong to several overlapping structures. Folders and tags serve
different purposes and should coexist.

### Folders

Folders provide a navigable hierarchy and a sense of place:

```text
Family recipes
└── Grandma Jean
    ├── Recipe cards
    └── Holiday meals
```

A recipe initially has zero or one primary folder. Aliases or smart collections
may later provide multi-location browsing while preserving one recipe identity.

### Tags

Tags form a many-to-many classification across folder boundaries:

```text
weeknight
vegetarian
Thanksgiving
freezer-friendly
needs-photograph
family-favorite
```

Tags may themselves be grouped or nested for browsing, but their identity should
remain independent of presentation hierarchy. Renaming a tag should not rewrite
recipe content.

### Saved searches and smart collections

Later, saved queries can create dynamic organization from folders, tags, recipe
properties, pantry likelihood, cooking history, ratings, and other signals:

> Dinner recipes tagged “weeknight” that we have not cooked in six months and
> can probably make from the pantry.

This is a projection over recipes rather than another ownership hierarchy.

## Schema.org compatibility

The app aims to round-trip the meaningful `Recipe` model rather than implement
only the fields needed by the first UI.

That means:

- Decode the legal text, object, array, and sectioned shapes used by Schema.org.
- Preserve the complete imported Recipe JSON-LD source.
- Map recipe-specific metadata including ingredients, instructions, yield,
  timings, nutrition, cuisine, category, diet, media, author, ratings, and source.
- Preserve unmapped properties so a future app version can interpret them.
- Distinguish publisher ratings/reviews from this household's cooking sessions
  and opinions.
- Eventually export standards-compliant JSON-LD without pretending that every
  private app feature has a Schema.org equivalent.

“Full support” does not require exposing every inherited `CreativeWork` property
in the initial editor. It means imports are lossless at the source boundary and
the domain can evolve without needing to re-fetch or discard source information.

## Edit a recipe

Database editing is an intentional mode for changing maintained recipe content.
It supports structural edits, metadata, organization, media, and revision
history. Editing is distinct from checking things off while cooking.

When a shared or imported recipe changes, the app should know:

- Which revision was edited.
- Who made the change.
- Whether source attribution remains intact.
- What changed.
- Whether existing cooking sessions refer to an older revision.

The exact collaboration and revision design remains open.

## Plan and prepare a recipe

Selecting a recipe and desired yield may create a `PlannedCook`. The app derives
scaled ingredient requirements, compares them with explainable pantry evidence,
and lets the person decide whether each requirement is covered, should be
purchased, needs checking, will be substituted, or will be skipped.

```text
Recipe revision + desired yield
                ↓
       Ingredient requirements
                ↓
      Pantry evidence and suggestions
                ↓
 Have · Purchase · Check · Substitute · Skip
                ↓
 Shopping contributions + planned deviations + advance prep
```

Correcting the app during this flow is useful pantry maintenance: “I don't
actually have that” can create a new observation while also adding the ingredient
to shopping.

Physical preparation remains distinguishable from readiness. Thawing, chopping,
marinating, measuring, and preparing components may become advance preparation
items on the planned cook.

Several dated planned cooks form the basis of weekly planning and combined
shopping. The detailed concept is recorded in `planned-cooks.md`.

## Cook a recipe

Starting cooking creates or resumes a `CookingSession`. The presentation is
primarily read-only and optimized for glanceability, but offers low-friction
ways to record what happens.

When started from a planned cook, the session inherits its recipe revision,
working yield, preparation progress, substitutions, omissions, and execution
notes. Those remain plans until confirmed or changed during cooking.

### During the session

- Check off ingredients and steps.
- Scale the working yield without modifying the base recipe.
- Start timers associated with a step or free-form note.
- Mark ingredients missing, omitted, substituted, or changed.
- Add an ingredient or impromptu step.
- Record text or dictated notes.
- Capture photographs or short video from the phone.
- Attach media to the session, an ingredient, or a step.
- Record what succeeded, failed, or deserves another attempt.
- Keep the display awake and legible during active cooking.

Voice and camera interactions are especially useful because cooking hands are
often wet, dirty, occupied, or gloved. These capabilities should degrade cleanly
to ordinary touch and typing.

### Session media

Media belongs to the session first. After cooking, a person may promote selected
items to the maintained recipe:

- Finished-dish hero photograph.
- Technique photograph attached to a step.
- Visual reference for desired texture or doneness.
- Evidence of a failure retained only in cooking history.

Each asset should retain who captured it, when, its session context, an optional
caption, and whether it has been promoted to recipe media. Original media should
not be silently edited or discarded.

### Notes, reviews, and family reactions

The app should distinguish several forms of response:

```text
Cooking note
  factual or personal observation from this session

Session review
  the cook's assessment of this attempt

Recipe rating
  a household member's longer-lived opinion of the recipe

Comment / reaction
  a family response to a session, note, photograph, or recipe
```

A spectacular failure can therefore be documented, laughed about, and learned
from without lowering an imported publisher rating or rewriting the recipe.

Family comments and reactions imply identity, notifications, permissions, and
moderation/deletion behavior even in a trusted household. Those concerns belong
in the collaboration design rather than being treated as strings on a recipe.

### Finish cooking

The session summary may offer:

- Overall result and private or shared notes.
- Photographs and media to keep or promote.
- Deviations to retain, discard, or turn into a recipe revision/variant.
- Pantry observations such as “used the last one” or “didn't actually have it.”
- A household review or rating.
- A shareable session story for family members.

None should be mandatory. Closing the cooking view must remain fast even after a
messy meal.

## Cross-workflow principle

The system maintains three kinds of truth without collapsing them:

```text
Published recipe     what the source said
Maintained recipe    what this kitchen currently intends
Planned cook         what we intend to make this time
Cooking session      what actually happened this time
```

Source imports, edits, and cooking history can inform one another, but movement
between them is explicit and reviewable.
