<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# Product brief

## Working idea

A private, collaborative recipe book for a family, designed around how people
actually remember what is in their kitchen.

The application should eventually connect recipes, meal plans, shopping, and a
fuzzy pantry. The recipe library comes first because every later feature depends
on a trustworthy ingredient model.

## Problem

Existing tools tend to optimize for one of two worlds:

- a recipe scrapbook, where ingredients are unstructured strings; or
- an inventory system, where every item must have a precise count and lifecycle.

Households live between them. A person may know there is “plenty of flour,” be
unsure whether there is enough butter, and care exactly that only one egg
remains. The system should preserve that varying level of confidence.

## Product principles

### Local first

Reading, editing, and cooking from saved recipes must work from local data.
Synchronization is a collaboration feature, not a prerequisite for opening the
app.

### Source faithful

An import must never discard the publisher's ingredient or instruction text.
Structured interpretations are stored alongside the source representation and
may be corrected or regenerated.

### Honest about uncertainty

Failed parsing is data, not an exceptional state. “A handful of parsley” is a
valid recipe ingredient even when it cannot be converted into grams.

### Calm collaboration

The top-level shared object is a **Kitchen**. People join a kitchen and share its
recipes; collaboration should not require thinking about servers, databases, or
permissions during ordinary use.

### Progressive structure

A pasted recipe should be immediately usable. Structure can be added by an
importer, by the cook, or over time. The application should reward cleanup but
never hold a recipe hostage until cleanup is complete.

### Record reality without rewriting intent

A recipe describes what someone intends to cook. A cooking session records what
actually happened: checked ingredients and steps, substitutions, omissions, and
observations. Those deviations may later become an explicit revision or variant;
they do not silently mutate the maintained recipe.

### Reconcile when knowledge matters

A planned cook compares scaled recipe requirements with pantry evidence before
cooking. The person may confirm availability, purchase, check, substitute, or
skip. This moment supplies useful pantry corrections without requiring routine
inventory maintenance.

## Primary users

- A household member saving a recipe from Safari.
- A family member entering a handwritten or inherited recipe.
- A cook scaling a recipe and following it in the kitchen.
- Later: a shopper asking what the household probably needs.
- Later: a cook reviewing a pantry suggestion based on several exact and fuzzy
  holdings of the same ingredient.

## First useful release

### In scope

- Local recipe library.
- Manual recipe editor.
- Local, reversible suggestions during manual ingredient entry.
- Recipe and ingredient sections.
- Structured ingredient rows with retained original text.
- URL import from Schema.org `Recipe` JSON-LD.
- Import review that highlights uncertain interpretations.
- Serving/yield scaling where quantities permit it.
- Step-by-step and full-recipe cooking views.
- Source attribution and a link back to the webpage.

### Explicitly deferred

- Pantry state.
- Shopping lists and meal planning.
- Nutrition calculation.
- Barcode and commercial-product databases.
- OCR and image-based import.
- AI-generated recipes.
- Public recipe discovery or social feeds.
- True peer-to-peer synchronization.

## Success signals

The first release succeeds when a household can:

1. Import twenty recipes from varied websites without losing meaningful text.
2. Correct imperfect imports faster than re-entering the recipe.
3. Enter a family recipe that has imprecise ingredients.
4. Reliably scale the ingredients that are mathematically scalable.
5. Cook from the app without returning to the source webpage.

## Product risks

- Ingredient cleanup may become tedious enough that users stop importing.
- A too-normalized model may erase distinctions cooks care about.
- A too-flexible model may make aggregation and pantry matching ineffective.
- Sync may dominate the project before the cooking experience is proven.
- Copyright and attribution need careful treatment when importing third-party
  recipes; the product should default to private personal use and retain sources.
