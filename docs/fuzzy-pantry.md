# Fuzzy pantry concept

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


- Status: Exploration

The accepted simplifications distilled from this exploration are recorded in
`product-doctrine.md`; unresolved detail remains here for future design work.

This document captures the product idea without fixing a persistence schema or
interaction design. The pantry should model what a household actually knows,
including precise, approximate, and merely existential knowledge.

## Core idea

Pantry knowledge has two independent dimensions:

1. **What kind of amount is known?** Exact, approximate, qualitative, or simple
   presence.
2. **What physical holding does that knowledge describe?** One ingredient may
   have several packages, containers, or loose amounts at once.

The pantry therefore cannot be one quantity field on an ingredient.

```text
Cinnamon
├── 1 unopened bottle
└── 1 open bottle · a little left
```

These entries may be useful independently: the open bottle should be used first,
while the unopened bottle means the household does not yet need to buy cinnamon.

## Working vocabulary

### Pantry item

The kitchen's relationship to a normalized ingredient. It groups all current
holdings and carries household-level behavior such as “we normally keep this.”

### Holding

One separately meaningful amount of a pantry item. A holding might correspond to
a package, jar, produce item, freezer bag, or loose bulk quantity. “Lot” is more
precise inventory language, but “holding” better accommodates fuzzy knowledge.

### Amount observation

What the household currently believes about a holding. Candidate forms:

```text
exact        425 g
count        1 bottle
approximate  about half a jar
qualitative  a little | some | plenty
presence     present
unknown      we may have it, but are not sure
```

The labels are illustrative. User-facing language should be tested before these
become fixed enum cases.

An observation may combine forms rather than forcing only one:

```text
container: 1 bottle
contents:  a little
```

### Package state

Optional knowledge such as unopened, open, or unknown. This is distinct from
quantity because “one unopened bottle” and “one nearly empty bottle” should not
collapse into “two bottles.”

## Illustrative model

```text
PantryItem
  ingredient
  replenishmentPolicy?
  holdings[]

PantryHolding
  id
  containerDescription?
  packageState?
  amountObservation
  location?
  bestBefore?
  observedAt
  note?
```

This is a conceptual sketch. It deliberately does not decide whether holdings
are mutable records, append-only observations, or derived from events.

## Why multiple holdings matter

- Open and unopened packages have different urgency.
- The same ingredient may exist in pantry, refrigerator, and freezer.
- Packages may have different expiration dates.
- Exact and fuzzy knowledge may coexist.
- Recipe suitability may depend on the usable amount, not purchase count.
- Replenishment should consider reserve stock without pretending all containers
  are equally full.

The default interface should not require splitting every ingredient into
holdings. A single simple presence entry must remain effortless. Multiple
holdings are progressive detail when the household finds them useful.

## Replenishment policy

“Do we have it?” and “Should we buy it?” are different questions. A pantry item
may carry an optional household policy:

```text
do not track
keep present
keep some
keep at least <amount>
review manually
```

This could eventually support staples without imposing exact stock maintenance.
For example, cinnamon might use `keep present`; eggs might use an exact minimum;
fresh basil might have no standing replenishment policy.

## Pantry cleanup

Pantry cleanup is a guided review of stale or low-confidence knowledge, not a
punitive inventory audit.

Possible prompts:

- “You marked this jar as ‘a little’ three weeks ago. Still have it?”
- “This open package is older than an unopened one. Is it finished?”
- “We usually keep this, but the last observation was ‘low.’ Add it to shopping?”
- “These two entries may describe the same package. Combine them?”
- “This item has not been used or confirmed recently. Forget it?”

Cleanup should be short, dismissible, and opportunistic. The system must tolerate
stale knowledge; otherwise maintaining the pantry becomes a second household
chore.

## Shopping suggestions

Suggestions should explain their reasoning and allow one-tap correction:

```text
Suggest cinnamon
Reason: usually kept on hand; only open bottle is marked "a little"
Known reserve: 1 unopened bottle
Recommendation: don't buy yet
```

That example intentionally demonstrates that a low open container does not
necessarily imply a purchase. The reasoning engine must aggregate multiple
holdings before suggesting replenishment.

Candidate signals include:

- Replenishment policy.
- Exact total where compatible quantities exist.
- Qualitative amount and package state.
- Age and confidence of observations.
- Planned recipe requirements.
- Recent user-authored Session Entries such as “didn't have.”
- An unopened reserve.

The most valuable time to request correction is while reconciling a planned cook.
At that moment the pantry answer affects a real purchase or substitution decision,
so confirming “have,” “out,” or “need to check” does useful maintenance without a
separate inventory ritual.

Suggestions remain proposals. They must never silently turn fuzzy observations
into exact facts or automatically place questionable items on a shared list.

## Relationship to recipes

Recipes ask whether a usable ingredient is likely available; pantry holdings
describe the evidence. Matching occurs through the normalized `Ingredient`:

```text
RecipeIngredient → Ingredient ← PantryItem → PantryHolding[]
```

An availability answer may be richer than yes/no:

```text
available
probably available
possibly insufficient
not known
unavailable
```

A planned cook records the person's decision separately from this inferred
answer. “Probably available” may be accepted as `have`, changed to `purchase`, or
left as `need to check`; the correction can become new pantry evidence.

The app should show why it reached an answer and make correction easier than
accepting a wrong guess.

## Principles to preserve

1. Precision is optional and may vary by ingredient and holding.
2. Multiple holdings are first-class but never mandatory busywork.
3. Qualitative language is valid data, not a parsing failure.
4. Observations age; uncertainty should increase rather than silently becoming
   false certainty.
5. Suggestions explain themselves and remain reversible.
6. The fastest pantry action should be “yes, we have that.”
