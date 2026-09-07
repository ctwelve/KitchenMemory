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

The [product doctrine](product-doctrine.md) owns the durable principles:
local-first operation, source fidelity, honest uncertainty, progressive
structure, and explicit separation of maintained intent from cooking evidence.
Kitchen is the ownership boundary; multi-person sharing remains future work.

## Primary users

- A household member saving a recipe from Safari.
- A family member entering a handwritten or inherited recipe.
- A cook scaling a recipe and following it in the kitchen.
- Later: a shopper asking what the household probably needs.
- Later: a cook reviewing a pantry suggestion based on several exact and fuzzy
  holdings of the same ingredient.

## Product maturity

The [public README](../README.md) owns published capability and distribution
status. Current source also includes Recipe authority, recoverable drafts,
private media, Folder/Tag organization, and records maintenance; use the
[documentation map](README.md) for their contracts. Historical 0.1 scope and
acceptance remain in the [milestone records](history.md).

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
