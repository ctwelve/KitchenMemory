# ADR 0010: Keep Cooking Sessions behind a distinct module seam

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Accepted
- Date: 2026-08-26

`CookingSession` is a top-level aggregate with lifecycle, snapshot, progress,
terminal-action, and convergence rules that differ from maintained recipes.
Kitchen Memory will therefore place those rules behind a distinct
`KitchenMemoryLogic` interface and persistence seam. The SwiftData adapter may
share the application's model container, but `RecipeRepository` will remain the
interface for Kitchens, Recipes, and RecipeRevisions rather than growing
session operations. Starting a session from a recipe revision is the deliberate
cross-aggregate operation and belongs in Logic.

Expanding `RecipeRepository` was rejected because it would couple recipe
reconciliation to session authority and make both the interface and its
implementation grow together. A single repository for the entire Kitchen was
also rejected because top-level Kitchen aggregates are independently loaded,
saved, tested, and synchronized. The first alternate adapter at the new seam is
the deterministic in-memory implementation used by exhaustive session tests;
additional seams wait for demonstrated variation.
