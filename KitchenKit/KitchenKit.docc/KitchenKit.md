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

Start in `Interface/Domain`, `Interface/Logic`, `Interface/Import`, or
`Interface/Persistence` to read the actual public declarations and their DocC.
Corresponding `Modules/` folders hold internal implementation, internal records,
and helpers. Some concrete Swift types retain bodies beside their declarations
to preserve private access and natural value semantics; the folder split does
not add indirection or change Swift visibility.

For two concrete examples, ``SchemaOrgRecipeImporter`` keeps its public capture
entry points in `Interface/Import` while `Modules/Import` owns bounded discovery,
normalization, and output accounting. ``SwiftDataRecipeRepository`` keeps public
operations and transaction ownership in `Interface/Persistence`; its
`Modules/Persistence` helpers own payload mapping, authority reads/writes, and
Kitchen ownership. These are internal source boundaries, not additional products.

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

### Editing a Recipe

``RecipeDrafts`` owns recoverable device-local drafts and publication. A live
``RecipeEditingDraft`` exposes a read-only ``RecipeEditSession`` snapshot.
Use identity-based ingredient operations or a ``RecipeIngredientTextEditing``
interface for ingredient changes. Native controls retain one interface for their
lifetime; completing a mode or replacing contents retires its transient history.

For other form fields, edit a session copy and submit
``RecipeEditingDraft/updateRecipeDetails(from:)``. Kit applies editable details
while retaining ingredients and captured metadata. Restoration and reconciliation
keep ingredient text and structured contents consistent before persistence.
``RecipeIngredientTextDraft`` contains recoverable wording, line identities, and
interpretation proposals; it is not part of a published ``RecipeRevision``.

### Choose the smallest entry point

| Task | Start with | Caller responsibility |
| --- | --- | --- |
| Read or change a maintained Recipe | ``RecipeLibrary`` | Supply repositories scoped to the same Kitchen; present failures and choices |
| Keep editing recoverable across relaunch | ``RecipeDrafts`` | Retain the collection and provide a device-local editing store |
| Parse captured recipe markup | ``SchemaOrgRecipeImporter`` | Acquire input, choose a candidate, and review it before Save |
| Retrieve a recipe webpage | ``RecipeImportService`` | Initiate acquisition explicitly and present import concerns |
| Scale a reading copy | ``RecipeScalingState`` | Choose an honest numeric yield basis and show unchanged-row reasons |
| Record cooking activity | ``CookingSessions`` | Retain prepared intentions for retry and handle classified results |
| Implement storage | ``RecipeRepository`` / ``CookingSessionRepository`` | Preserve immutable command identities and evidence boundaries |

Domain and Import values can move across isolation boundaries when their types
are `Sendable`. Repository adapters, the live draft collection, and product
services that access those repositories use the main actor. `async` import
does not make an actor-bound repository safe to access from a background task.

### Parse without saving

This example consumes an already captured JSON-LD document. It performs no
network request and creates no Recipe:

```swift
import Foundation
import KitchenKit

func inspectCapturedRecipe() -> RecipeImportResult {
    let markup = """
    {"@context":"https://schema.org","@type":"Recipe",
     "name":"Toast","recipeIngredient":["1 slice bread"],
     "recipeInstructions":["Toast the bread."]}
    """
    return SchemaOrgRecipeImporter().importJSONLD(Data(markup.utf8))
}
```

Inspect ``RecipeImportResult/candidates`` and
``RecipeImportResult/diagnostics`` together. Resource-limit failures can reject
the operation's candidates rather than return a partially accepted result.
Source snapshots preserve captured evidence; they do not establish that the
website's claims are true. ``RecipeImportService`` turns candidates into
reviewable ``RecipeImportOption`` values, and ``RecipeDrafts`` can retain them
before the person accepts an import for editing.

### Edit through the retained draft

A `RecipeEditSession` is a value. Mutating a local copy alone does not notify
the retained draft or persist it. Submit non-ingredient changes through the
live draft's interface:

```swift
import KitchenKit

@MainActor
func beginRecipe(in drafts: RecipeDrafts) -> RecipeEditingDraft? {
    guard let draft = drafts.begin() else { return nil }
    var details = draft.session
    details.title = "Toast"
    draft.updateRecipeDetails(from: details)
    return draft
}
```

`begin()` can return a draft even when its initial persistence attempt fails;
present the collection's storage status and check persistence before leaving.
Save freezes one command before submission. Retrying that pending Save uses
the same identity and contents. ``RecipeDrafts/Publication`` distinguishes
accepted publication from successful local draft cleanup, so a cleanup failure
must not be presented as proof that the Recipe was never saved.

For native ingredient text, retain one ``RecipeIngredientTextEditing`` for the
control's lifetime, forward UTF-16 replacements, and end it on teardown. The
control owns marked text, selection, and native Undo/Redo delivery. KitchenKit
owns the matching semantic snapshots. Recreate the control when
``RecipeEditingDraft/ingredientTextEditorID`` changes so delayed callbacks cannot
mutate replacement contents.

### Scale a transient reading value

```swift
import KitchenKit

func doubledIngredient(_ ingredient: RecipeIngredient) -> ScaledRecipeIngredient? {
    let yield = RecipeYield(
        quantity: QuantityExpression(
            kind: .exact, lowerBound: RationalQuantity(numerator: 2)
        ),
        originalText: "2 servings"
    )
    var reading = RecipeScalingState(recipeYield: yield)
    reading.adjustWorkingYield(by: 2)
    guard let scale = reading.scale else { return nil }
    return ingredient.scaled(using: scale)
}
```

The maintained ingredient remains untouched. Examine
``ScaledRecipeIngredient/status``: fixed quantities, uncertain text, display
overrides, manual-review choices, and arithmetic failures have explicit reasons
for retaining their authored amounts. Scaling does not infer units or convert
a textual yield into a numeric one.

### Preparation, acceptance, and transport

Recipe Save, Selection, Folder, Tag, and Cooking Session commands carry stable
identities and observed evidence. Preparation captures an intention against
what the caller observed; repository acceptance validates the relevant current
evidence. A stale screen is not authorization to overwrite newer evidence.

``CookingSessions`` reads retained evidence through
``SessionEvidenceProjector``. A result can be a usable Session, temporarily
unavailable material, or evidence requiring Recovery. Those distinctions remain
meaningful after local writes and partial CloudKit delivery. A view disappearing
does not Stop or Finish a Session; only an explicit accepted intention does.
The application owns its pending-command outbox and retry presentation.

``KitchenMemorySchema`` is a composition entry point for SwiftData adapters.
Its default container is local-only; personal CloudKit requires the default
durable store and explicit synchronization selection. A successful local save
does not prove upload, download, convergence, or migration of arbitrary alpha
data. Domain callers receive values and classified evidence, never live
SwiftData records.

## Topics

### Domain Foundations

- ``Kitchen``
- ``Recipe``
- ``RecipeRevision``
- ``StableIdentifier``

### Folder Organization

- ``Folder``
- ``FolderLibrary``
- ``FolderIntent``
- ``FolderCommand``
- ``FolderCollision``
- ``FolderCheckpoint``
- ``FolderRepository``

### Tag Organization

- ``Tag``
- ``TagLibrary``
- ``TagIntent``
- ``TagCommand``
- ``TagCollision``
- ``TagCheckpoint``
- ``TagRepository``

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
- ``RecipeDrafts``
- ``RecipeEditingDraft``
- ``RecipeEditSession``
- ``RecipeIngredientTextDraft``
- ``RecipeIngredientTextEditing``
- ``RecipeScalingState``
- ``ScaledRecipeIngredient``
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
- ``RecipeEditingStoring``
- ``FileRecipeEditingStore``
- ``KitchenMemoryStoreSynchronization``

### Cooking Session Evidence

- ``SessionEvidence``
- ``SessionEvidenceProjector``
- ``SessionProjectionResult``
- ``CookingSessionProjection``
