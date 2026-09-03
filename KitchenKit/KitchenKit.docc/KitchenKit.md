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

Newcomers can start with the three domain identities—``Kitchen``, ``Recipe``,
and ``RecipeRevision``—then move outward to a product-facing service such as
``RecipeLibrary`` or ``CookingSessions``. Repository protocols mark the boundary
where durable storage begins. Importers produce reviewable values; they never
write directly to a library.

```text
Application presentation
        ↓
RecipeLibrary / CookingSessions       Logic
        ↓
Repository protocols                  Persistence boundary
        ↓
Domain values and evidence projector  Domain
```

## Topics

### Domain Foundations

- ``Kitchen``
- ``Recipe``
- ``RecipeRevision``
- ``StableIdentifier``

### Recipe Content

- ``RecipeSource``
- ``RecipeYield``
- ``IngredientSection``
- ``RecipeIngredient``
- ``InstructionSection``
- ``InstructionStep``

### Product Logic

- ``RecipeLibrary``
- ``RecipeDraft``
- ``RecipeEditSession``
- ``CookingSessions``

### Import

- ``RecipeImportService``
- ``RecipeURLImporter``
- ``SchemaOrgRecipeImporter``
- ``RecipeImportResult``

### Persistence

- ``RecipeRepository``
- ``CookingSessionRepository``
- ``KitchenMemorySchema``

### Cooking Session Evidence

- ``SessionEvidence``
- ``SessionEvidenceProjector``
- ``SessionProjectionResult``
- ``CookingSessionProjection``
