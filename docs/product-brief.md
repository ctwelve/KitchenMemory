# Product brief

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->


## Product

A private, local-first recipe book that begins with one person's Apple devices
and is designed to grow into calm household collaboration around how people
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
actually happened: progress, working-scale changes, and exact authored Session
Entries. Selected Entries may later inform an explicit revision, variant, or new
Recipe; they do not silently mutate the maintained Recipe.

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

## First useful release — 0.1.0 public alpha

The first useful release artifact was accepted and published on 2026-08-25 as a
signed and notarized direct-download macOS application in a GitHub prerelease.
The same source contains native iPhone and iPad targets, but public iOS
distribution and TestFlight remain deferred. The alpha proves the core recipe
loop with a deliberately smaller acceptance set than the one required for 1.0.

### In scope

- Local recipe library.
- Manual recipe editor.
- Local, reversible suggestions during manual ingredient entry.
- Recipe and ingredient sections.
- Structured ingredient rows with retained original text.
- URL import from Schema.org `Recipe` JSON-LD.
- Import review that highlights uncertain interpretations.
- Serving/yield scaling where quantities permit it.
- Clear full-recipe reading views.
- Private iCloud synchronization across one person's devices.
- Source attribution and a link back to the webpage.

### Explicitly deferred

- Pantry state.
- Shopping lists and meal planning.
- Nutrition calculation.
- Barcode and commercial-product databases.
- OCR and image-based import.
- AI-generated recipes.
- Public recipe discovery or social feeds.
- Cooking-session progress, Session Entries, and history.
- Multi-person Kitchen sharing and live collaboration.
- True peer-to-peer synchronization.

## Alpha evidence and 1.0 success signals

The 0.1 exercise established manual revision, bounded import, structured
reading and scaling, local persistence, private Development iCloud propagation,
production-schema deployment, and a notarized Mac artifact. It did not claim
the breadth of the eventual 1.0 acceptance corpus.

Before 1.0, the product should demonstrate that a household can:

1. Import twenty recipes from varied websites without losing meaningful text.
2. Correct imperfect imports faster than re-entering the recipe.
3. Enter a family recipe that has imprecise ingredients.
4. Reliably scale the ingredients that are mathematically scalable.
5. Cook from the app without returning to the source webpage.
6. Find the intact recipe library on another device using the same iCloud
   account.

## Product risks

- Ingredient cleanup may become tedious enough that users stop importing.
- A too-normalized model may erase distinctions cooks care about.
- A too-flexible model may make aggregation and pantry matching ineffective.
- Sync may dominate the project before the cooking experience is proven.
- Copyright and attribution need careful treatment when importing third-party
  recipes; the product should default to private personal use and retain sources.
