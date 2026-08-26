# Cooking sessions and deviations

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


- Status: Deferred 0.2 exploration

The accepted simplifications distilled from this exploration are recorded in
`product-doctrine.md`; unresolved detail remains here for future design work.

Cooking sessions are deliberately outside the 0.1 persistence and production
CloudKit schema. The current application has neither session domain types nor
session persistence records. The 0.2 feature slice must first settle the
unresolved ownership, historical-reference, progress, and deviation boundaries
described below, then introduce a new immutable SwiftData schema version and
additive CloudKit record types and fields.

This is expected schema evolution, not a rewrite of recipe data. CloudKit's
production schema may grow but published types and fields cannot be removed or
repurposed, so the 0.1 synchronization foundation must establish an additive
schema policy without guessing at a premature session representation.

A saved recipe describes an intended preparation. Cooking it creates a temporary
working session: ingredients and steps can be checked off, and the cook can note
what actually happened without editing the source recipe mid-cook.

A session may begin directly from a recipe or from a `PlannedCook`. The latter
provides working yield, readiness decisions, completed preparation, and planned
substitutions or omissions.

## Separation of concerns

```text
Recipe
  the maintained instructions

PlannedCook
  what the kitchen intends to prepare this time

CookingSession
  one performance of that recipe

RecipeRevision or RecipeVariant
  a deliberate recipe change derived from experience
```

This separation lets the normal recipe screen remain primarily a reading and
cooking surface while still capturing valuable deviations.

## Cooking mode

During a session, the cook should be able to:

- Check off ingredient lines.
- Check off instruction steps.
- Move backward and forward without losing progress.
- Mark an ingredient as unavailable.
- Record a substitution.
- Record an amount actually used.
- Add a quick note to an ingredient, step, or the whole session.
- Mark a step as skipped, changed, or problematic.
- Finish or abandon the session.

Checking an ingredient means “accounted for during this cook,” not necessarily
“deducted precisely from the pantry.” Pantry effects should initially be prompts
or suggestions, particularly when the pantry amount is fuzzy.

## Deviations

A deviation records the difference between recipe intent and cooking reality.
Candidate types include:

```text
ingredient unavailable
ingredient substituted
amount changed
ingredient omitted
ingredient added
step skipped
step changed
timing changed
free-form observation
```

Examples:

```text
Didn't have buttermilk.
Substituted yogurt + water for buttermilk.
Used half the sugar.
Cooked 12 minutes longer than written.
Added smoked paprika after tasting.
```

The original recipe remains untouched. Deviations belong to the session until a
person deliberately promotes them.

Planned substitutions and omissions enter the session as expected deviations.
The session records whether the cook followed, changed, or abandoned those plans.

## From a deviation to a recipe

After cooking, the app may summarize the session and offer choices:

- Keep the notes only in cooking history.
- Apply selected corrections to the recipe as a new revision.
- Create a named variant or fork.
- Discard incidental notes.

A repeated deviation is particularly valuable:

> You reduced the sugar the last three times you cooked this. Update your
> recipe?

Promotion must show an explicit diff. It should never quietly rewrite an
imported or family recipe based on checked boxes and hurried kitchen notes.

## Illustrative model

```text
CookingSession
  id
  recipeID
  recipeRevisionID?
  startedAt
  finishedAt?
  status
  servingScale
  ingredientProgress[]
  stepProgress[]
  deviations[]
  notes[]

CookingDeviation
  target              // session, ingredient row, or step
  kind
  originalValue?
  actualValue?
  note?
  recordedAt
```

The session should retain enough of the recipe version it used to remain
meaningful after the maintained recipe changes. Whether this is a full snapshot
or a revision reference is intentionally unresolved.

## Pantry feedback

Sessions provide evidence without pretending to know more than the cook entered:

- “Didn't have” can correct pantry presence and influence shopping suggestions.
- “Used the last of it” can close a holding.
- A precise amount used may reduce a precise holding.
- Checking off “salt to taste” should not perform inventory arithmetic.
- A substitution may reveal that two ingredients can serve similar roles for
  this household without globally declaring them equivalent.

At the end of a session, a compact review might ask only about material pantry
changes. The user should be able to skip it entirely.

## Collaboration

Session progress is personal by default unless a shared live-cooking experience
proves useful. The resulting notes and proposed recipe changes may be shared with
the kitchen.

Concurrent editing and family recipe ownership will require a clear revision
model before deviations can update shared recipes.

## Principles to preserve

1. Cooking mode is primarily for reading; interaction is lightweight.
2. Checkmarks are session progress, not permanent recipe edits.
3. Pantry deductions follow evidence and user intent, not assumptions.
4. Deviations are cheap to record and safe to ignore later.
5. Creating a revision or variant is explicit and reviewable.
6. Cooking history remains intelligible after a recipe changes.
