# Planned cooks and readiness

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


- Status: Accepted direction

A planned cook bridges a maintained recipe and an actual cooking session. It
answers a practical question:

> We intend to cook this recipe at this scale. What do we have, what must we buy,
> and what have we already decided to change?

It is the foundation for single-recipe readiness, advance preparation, shopping,
and eventual weekly meal planning.

## Place in the product

```text
Recipe revision
      ↓
Planned cook
      ├── pantry reconciliation
      ├── shopping decisions
      ├── planned substitutions and omissions
      └── advance preparation
      ↓
Cooking session
```

A planned cook records intent. A cooking session records reality. Neither
silently edits the maintained recipe.

## Working model

```text
PlannedCook
  id
  recipeID
  recipeRevisionID
  desiredYield
  plannedDate?
  ingredientDecisions[]
  preparationItems[]
  note?
```

This is a conceptual model rather than a persistence commitment. It must retain
the recipe revision and scale used to derive its requirements.

## Ingredient reconciliation

Each scaled recipe requirement receives a decision. The initial conceptual states
are:

```text
unreviewed
have
purchase
substitute
skip
need to check
```

The final user-facing labels and controls remain open. These states mean:

- `have`: the cook believes the requirement is covered.
- `purchase`: some or all of the requirement should go to shopping.
- `substitute`: another ingredient is planned for this cook.
- `skip`: the ingredient is intentionally omitted for this cook.
- `need to check`: pantry evidence is ambiguous or physically needs confirmation.

A decision may retain the pantry evidence and explanation that informed it:

```text
Requirement: 2 tsp cinnamon
Suggestion:  have
Evidence:
  - 1 open bottle · a little
  - 1 unopened bottle
```

The suggestion and the person's decision are separate. Accepting or correcting a
suggestion may create a new pantry observation, but it must not fabricate an exact
quantity.

## Honest availability

Pantry reconciliation uses the availability vocabulary from the fuzzy pantry:

```text
available
probably available
possibly insufficient
unknown
unavailable
```

Compatible exact requirements and holdings may be compared mathematically.
Unlike evidence remains visible rather than being collapsed into false totals.

## Shopping effects

A `purchase` decision contributes a requirement to a shopping list. Combined
shopping must preserve provenance:

```text
Yellow onions
  2 · chicken soup
  1 · tacos
```

Removing or rescaling a planned cook recalculates its contribution. Compatible
quantities may combine; incompatible, fuzzy, and container quantities remain
separate or are presented as an explainable summary.

Shopping completion may suggest pantry observations, but purchasing and pantry
receipt are distinct events. Checking an item off at the store does not prove it
arrived in the kitchen.

## Planned deviations

Substitutions and omissions belong to the planned cook first:

```text
buttermilk → yogurt + water
omit cilantro
use half the sugar
```

When cooking begins, they are carried into the cooking session as planned
deviations. The cook may confirm, change, or abandon them. Only an explicit
post-cook promotion can turn them into a recipe revision or variant.

## Plan, prep, and cook

The conceptual progression is:

```text
Plan
  reconcile requirements, pantry evidence, purchases, and substitutions

Prep
  perform advance physical work such as thawing, chopping, marinating,
  measuring, or preparing a component

Cook
  execute the recipe and record what actually happens
```

“Prep” may be used as an umbrella label in the interface, but the domain should
not confuse ingredient readiness with physical mise en place. Final terminology
will be tested later.

Preparation items may be derived from recipe steps, entered manually, or
suggested. Completing them records progress on the planned cook and may affect
the cooking presentation without modifying the recipe revision.

## Weekly planning

A meal plan is initially a collection or calendar projection of planned cooks,
not a separate recipe execution model:

```text
Week
├── Monday: chicken soup × 6 servings
├── Tuesday: tacos × 4 servings
└── Saturday: banana bread × 2 loaves
```

The same reconciliation engine works for one planned cook or several. A weekly
view adds dates, combined shopping, scheduling, and batch preparation without
creating a second set of ingredient-decision rules.

## Lifecycle

A planned cook may be:

```text
draft
ready
in preparation
cooking
completed
cancelled
```

These states are illustrative. A plan may exist without a date, and opening a
recipe does not create one automatically.

Starting a cooking session from a planned cook carries forward:

- Recipe revision and desired yield.
- Ingredient decisions.
- Planned substitutions and omissions.
- Completed preparation work.
- Notes relevant to execution.

Finishing or stopping the cooking session updates the plan's lifecycle while
keeping its prior intent intelligible.

## Same product, focused surfaces

Planning, pantry, shopping, and cooking share too much domain meaning to begin as
separate applications. They should be feature modules and platform-appropriate
surfaces within one kitchen system.

Later, focused targets, widgets, App Intents, or companions may expose subsets of
the same application capabilities without creating a second source of truth.

## Principles to preserve

1. A planned cook is intent; a cooking session is reality.
2. Pantry suggestions show their evidence and remain correctable.
3. One recipe and an entire week use the same reconciliation rules.
4. Shopping aggregation preserves recipe provenance.
5. Planned substitutions do not edit the recipe.
6. Pantry maintenance happens opportunistically when knowledge matters.
7. Plan, physical prep, and cooking remain conceptually distinguishable.
