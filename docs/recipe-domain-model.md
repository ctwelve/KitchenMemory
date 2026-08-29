# Recipe domain model

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->


This is the conceptual domain model, not a persistence schema. The implemented
recipe foundation follows these names and ownership boundaries; future pantry,
planning, and cooking-session types remain design direction until their slices
land.

## Design goals

- Represent common web recipes without flattening sections or steps.
- Preserve all imported text even when parsing is incomplete.
- Support exact, fractional, ranged, approximate, and absent quantities.
- Separate an ingredient concept from the way it appears in one recipe.
- Make serving scaling predictable.
- Leave a clean seam for future pantry matching.

## Aggregate

```text
Kitchen
└── Recipe
    └── RecipeRevision[]
        ├── RecipeSource?
        ├── RecipeSourceCapture?
        ├── RecipeYield?
        ├── RecipeMedia[]
        ├── EquipmentItem[]
        ├── IngredientSection[]
        │   └── RecipeIngredient[]
        │       └── QuantityExpression?
        └── InstructionSection[]
            └── InstructionStep[]
```

## Entities and values

### Kitchen

The collaboration boundary. Recipes belong to a kitchen rather than directly to
one user. Membership and synchronization are intentionally outside this first
model.

### Recipe

| Field | Meaning |
| --- | --- |
| `id` | Stable application identity |
| `kitchenID` | Owning Kitchen identity |
| `currentRevisionID` | Revision currently presented as maintained content |

### RecipeRevision

An immutable authored version of one recipe. Editing appends a new revision and
makes it current; it does not overwrite the previous value.

| Field | Meaning |
| --- | --- |
| `id` | Stable revision identity |
| `recipeID` | Owning Recipe identity |
| `revisionNumber` | Person-visible sequence within the Recipe |
| `title` | Display title |
| `summary` | Optional summary |
| `authorName` | Human-readable attribution |
| `source` | Provenance for imported or transcribed material |
| `sourceCapture` | Bounded immutable evidence retained from import |
| `contentLanguage` | Planned optional BCP 47 authored-language tag; existing content may be unknown |
| `recipeYield` | What the base recipe produces |
| `prepDuration` | Active preparation time, when known |
| `cookDuration` | Cooking time, when known |
| `totalDuration` | Published total, which need not equal prep + cook |
| `cuisines` | Publisher/user classifications |
| `categories` | Course or recipe type |
| `keywords` | Other descriptive tags |
| `media` | Locally managed or remote media references |
| `equipment` | Ordered tools named by the authored recipe |
| `ingredientSections` | Ordered ingredient groups |
| `instructionSections` | Ordered instruction groups |

Durations should be stored as semantic durations rather than formatted strings.
The imported spelling may additionally remain in the source snapshot.

### RecipeSource

```text
kind: original | webpage | book | person | imported
title?
authorName?
publisherName?
canonicalURL?
```

Imported revisions may additionally retain a `RecipeSourceCapture`. The current
capture records one bounded JSON-LD block, its final source URL, capture time,
media type, and the selected candidate coordinates. Its opaque payload is not
the live recipe; it is evidence that lets a future importer reinterpret the
source without refetching the webpage.

### Yield

A recipe may produce servings, pieces, loaves, volume, or free-form output.

```text
quantity: QuantityExpression?
unitText: String?          // servings, cookies, loaves
originalText: String       // e.g. "4 to 6 servings"
```

Scaling uses a chosen numeric basis when one exists. A ranged yield must retain
its range and expose which value is being used for scaling.

### IngredientSection

An ordered group such as “For the crust” or “Sauce.” A recipe with no explicit
groups still contains one untitled section. Sections prevent importers from
smuggling headings into ingredient rows.

### RecipeIngredient

This is the ingredient **as used by this recipe**, not the canonical food.

| Field | Meaning |
| --- | --- |
| `originalText` | Untouched imported or entered line |
| `presentationMode` | Whether to show structured, original, or custom text |
| `customDisplayText` | Optional explicit presentation override |
| `quantity` | Parsed quantity expression, if any |
| `unitText` | Parsed or selected recipe-unit wording, if any |
| `package` | Optional structured package quantity and unit wording |
| `ingredientText` | Parsed name before/without resolution |
| `preparation` | “finely chopped,” “divided,” “at room temperature” |
| `note` | Other authored guidance retained with the row |
| `isOptional` | Whether the line describes an optional ingredient |
| `scalingBehavior` | linear, fixed, or manual-review |
| `parseState` | unparsed, parsed, reviewed, or edited |

Both `originalText` and structured fields are necessary. For example:

```text
originalText:    "1 (28-ounce) can whole tomatoes, crushed by hand"
quantity:        exact(1)
unit:            can
ingredientText:  whole tomatoes
preparation:     crushed by hand
```

The normal ingredient presentation is computed from the structured fields.
When those fields are incomplete it falls back to `originalText`. A person may
explicitly choose the original wording or a custom override, but computed text
is not persisted separately where it could drift out of sync.

The package size is meaningful but does not fit cleanly into a single quantity
and unit. `PackageDescription` represents it without blocking
the first implementation.

### Future Ingredient seam

A later pantry slice may add a kitchen-scoped normalized concept such as “whole
tomatoes” or “unsalted butter.” It is deliberately not a commercial product and
not a pantry record. The implemented recipe row currently retains
`ingredientText`; it does not yet carry this reference.

```text
id
preferredName
aliases[]
```

Normalization should be reversible and user-controlled. “Cilantro” and
“coriander leaves” may be aliases; “coriander seed” is a different ingredient.

### QuantityExpression

Quantities are values, not floating-point numbers.

```text
none                         // salt to taste
exact(3/4)
range(2, 3)
approximate(2)
text("one generous handful")
```

Exact numeric values should use rational or decimal arithmetic. Fractions must
round-trip cleanly; `1/3` must not become `0.333333` in the editor.

### Future Unit seam

A later normalization slice may give a recipe unit stable identity, a preferred
label, aliases, and a dimension where known. The implemented recipe row stores
authored `unitText`, which remains lossless without claiming that normalization
has occurred.

```text
id
name             // tablespoon
symbol           // tbsp
dimension?       // mass, volume, count, length, temperature
```

Conversions are only valid within compatible dimensions. Volume-to-mass
conversion belongs to ingredient-specific knowledge and is out of scope here.
Container units such as “can,” “package,” and “bunch” are valid even when their
physical size is unknown.

### InstructionSection and InstructionStep

Instructions retain hierarchy found in `HowToSection`/`HowToStep`.

```text
InstructionSection
  title?
  steps[]

InstructionStep
  name?
  text
  duration?
  temperature?
```

Steps do not initially require explicit links to ingredients. That feature can
be added after real imports establish whether automatic association is useful.

## Scaling rules

- Exact and ranged numeric quantities scale linearly by default.
- Text quantities remain unchanged.
- A fixed quantity remains unchanged when servings change.
- An ingredient marked `manual-review` displays its base amount plus a warning.
- Display rounding is a presentation policy and must not modify stored values.
- Preparation text never participates in arithmetic.

## Future pantry seam

The recipe model connects to the pantry through `Ingredient`, not by matching
display strings or recipe rows directly.

```text
RecipeIngredient → Ingredient ← PantryItem → PantryHolding[]
```

The pantry side is explored in `fuzzy-pantry.md`. One `PantryItem` may contain
multiple holdings, each with exact, approximate, qualitative, presence-only, or
unknown knowledge. Recipe work should preserve this seam without prematurely
forcing those concepts into its persistence schema.

Cooking progress and Session Entries are similarly Session-specific rather than
properties of `Recipe`; see `cooking-sessions.md`.

Readiness and meal planning connect a particular recipe revision and yield to
pantry evidence through `PlannedCook`; see `planned-cooks.md`. This preserves the
distinction between recipe requirements, intended decisions for one cook, and
what actually occurs in its cooking session.

## Invariants

1. Every ingredient row retains meaningful display text.
2. Parsing failure never prevents saving or cooking a recipe.
3. Imported provenance is distinguishable from user-authored content.
4. Section and row order are stable and user-controlled.
5. Normalization never silently rewrites the original text.
6. Scaling never fabricates a numeric interpretation for a textual quantity.
