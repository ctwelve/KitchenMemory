# ``KitchenKit``

The complete, presentation-independent business implementation of Kitchen
Memory.

## Overview

KitchenKit gives every Kitchen Memory client one importable module while keeping
four responsibilities locally explicit:

- Domain owns persistence-independent kitchen concepts and invariants.
- Import discovers and normalizes recipes without saving or presenting them.
- Logic owns product operations and workflow state.
- Persistence supplies storage and synchronization adapters behind domain-facing
  repository seams.

These names describe source organization and architectural responsibility; they
are not nested Swift namespaces. Clients use `import KitchenKit` and refer to
types by their natural names, such as ``Recipe`` and ``RecipeLibrary``.

## Topics

### Recipes

- ``Recipe``
- ``RecipeRevision``
- ``RecipeLibrary``
