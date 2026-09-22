# Native Recipe Library organization

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Issue [#116](https://github.com/ctwelve/KitchenMemory/issues/116) connects the
[Folder](folders.md) and [Tag](tags.md) policies to the native library. Organization
belongs to stable Recipes and never changes their Revision content.

## Commit and retry boundaries

`RecipeOrganization` prepares immutable commands against observed Folder and Tag
evidence. Bulk commands sort Recipe identities and derive stable per-Recipe action
identities from the batch identity. `SwiftDataRecipeOrganizationRepository` owns
one fresh `ModelContext` transaction for every batch. It validates each complete
policy projection once, then inserts its accepted actions. A failed member rolls
back the entire local batch. Managed personal-iCloud delivery remains incremental;
this is not a distributed transaction promise.

A new `RecipeEditingDraft` retains pending Folder and Tag choices in its existing
device-local document. Before publication, `RecipeDrafts` freezes both its first
Save and its organization command, persists them together, and asks the repository
to accept Recipe identity, first Revision, Selection and organization actions in
one transaction. Cleanup failure preserves the same frozen commands for retry.
Existing Recipe organization commits separately while content editing remains a
device-local draft.

Pending bulk commands and Folder expansion are scoped by owner and store as well
as Kitchen identity. Explicit Kitchen reset clears retained local commands before
resetting shared evidence, preventing later retries from restoring old organization.

The existing V7 scalar record family also stores digest receipts in the
`organization-batches` namespace. A receipt binds a batch identity to its complete
command and optional first Save, rejecting identity reuse with a changed selection
or operation. Receipts contain digests rather than Recipe content. They currently
remain retained; maintenance must not remove them without a later policy that
preserves retry guarantees. Kitchen convergence and explicit reset already own
all organization namespaces. No SwiftData schema shape changes are required.

## Presentation and synchronization

Folder and Tag visibility, Folder expansion and the collapsed Tags section are
device-local preferences. Expansion is scoped to the owner, store and Kitchen.
Hiding a feature does not stop its projection, acceptance or synchronization.
Alphabetical/manual ordering and the visibility of the computed Unfiled and
Untagged views are independent causal registers in their respective synchronized
policies. Alphabetical presentation uses the local locale; switching modes does
not remove the manual sequence. The new visibility actions extend the encoded
organization payload vocabulary; older alpha builds cannot decode them.

Folder scope includes its subtree. Selected Tags intersect with each other, the
Folder scope and Recipe text search. Unfiled has no stored identity and remains
available even without Folders; Untagged additionally requires a live Tag.
Hidden local features contribute no filter constraint. Native disclosure shows
Folder children only when expanded; Tags remain flat. The policy still exposes
an iterative outline for ordering and non-UI consumers.

Bulk operations and native drops use the same prepared command boundary as menus.
Name collisions remain readable in Recovery even with both presentation features
hidden. Merge and deletion require confirmation. Rename, reparent, manual ordering and
merge are available from row context menus and the visible hierarchy options
button. Creation uses the adjacent plus buttons.
Organization deletion affects ordinary presentation immediately and never deletes
Recipe content or creates Deleted Items.

## Adaptive library shell

Phase one of [#182](https://github.com/ctwelve/KitchenMemory/issues/182), implemented
by [#184](https://github.com/ctwelve/KitchenMemory/issues/184), uses a balanced native
three-column split: Organization, the current destination's list, and selected
detail. All Recipes, Drafts when present, Session History, Deleted Items and
conditional Recovery are named sidebar destinations. Selecting a draft or a
Session retains its middle-column context. Recipe detail retains its associated
Sessions action. Session lifecycle and internal cooking interactions are unchanged.

The system controls adaptive collapse. The Organization menu offers persistent
show/hide and a separate temporary reveal; Mac also offers a delayed edge reveal.
The temporary surface overlays rather than resizes detail, with a named dismiss
action and Escape support. Essential actions never depend on pointer hover.
Selection, list anchors and recoverable editing documents belong to the prepared
app graph rather than a particular column presentation. A folder/tag change uses
the same draft-save veto as every other destination change.

Settings groups local Show Folders/Tags separately from the Folder and Tag policy
preferences. The latter continue to author the existing synchronized commands;
moving their controls does not change ownership or persistence.

## Contextual browsing

[#185](https://github.com/ctwelve/KitchenMemory/issues/185) pins the search,
scope, active Tags and bulk controls above the scrolling Recipe rows. The scope
shows the full Folder path, including a selected Folder's descendants. Reset
Filters clears the query, Tags and Untagged constraint while retaining that
location. All Recipes removes only the location constraint; search and Tags
remain visible and active. Hidden organization features contribute no constraint
and their inactive scope is not presented as active.

The existing Foundation `String.range` matching searches the maintained title
and short summary, case- and diacritic-insensitively using the presentation locale.
It is a literal substring search, not stemming, fuzzy search, ingredient search
or translation. Filtering runs synchronously over the loaded Recipe snapshot
as the query changes; it performs no storage fetch or network request. There is
no additional index, package, or debounce delay. Large-library latency has not
been benchmarked.

Apple's [native searchable interface](https://developer.apple.com/documentation/swiftui/adding-a-search-interface-to-your-app)
was evaluated: its placement follows the navigation container and platform.
The fixed top-of-middle-column requirement uses a native SwiftUI TextField
outside the ScrollView instead, reusing the existing Foundation matching policy.
The model retains the query across Folder/Tag changes and destination switches.
Filtering never changes the selected Recipe or closes its editor. A named return
action reveals the existing detail when its row is filtered out; Drafts also
retains the existing recoverable-document route. Selection and list anchors
remain in the navigation model across column reveal and resize.

## Recipe reading composition

[#187](https://github.com/ctwelve/KitchenMemory/issues/187) measures the detail
pane itself. Two columns require room for two text-scaled 320-point minimum
columns, a 24-point gap and 48 points of outer padding; content is capped at
1120 points. Accessibility text sizes always stack. A shared ordered section
description keeps Ingredients before Instructions, above or toward the leading
edge respectively. SwiftUI's AnyLayout preserves the section view identity when
the arrangement changes. Introductory media, metadata, source, equipment and
scaling remain ahead of the ingredient/instruction body. Recipe actions and
Cooking Session views are unchanged.

## Validation boundary

Framework tests own atomicity, stable retries, draft recovery, causal preferences,
filtering and deep outline traversal. Hosted tests own local preference persistence,
drop decoding, command retry state, hidden-feature Recovery, preference ownership
and list/detail routing. Native UI tests prove named top-level destinations, consistent with
[ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md). Detailed feature
workflows remain below the UI automation boundary; human platform and assistive
technology review is still required for release acceptance.

## Simple editing in the recipe pane

[#188](https://github.com/ctwelve/KitchenMemory/issues/188) starts explicit Edit and
New Recipe in the simple editor: title, multiline ingredients and instruction
steps. Advanced Editor exposes the existing full recipe form; Ingredient Precision
exposes those ingredient controls without leaving simple editing. Both surfaces
write the same `RecipeEditingDraft`. Instruction section/step identities, media,
equipment and other maintained metadata are retained across mode changes. Import
review continues to use the full editor.

`RecipeIngredientTextDraft` is optional, Codable device-local editing state inside
`RecipeEditSession`, not a new persisted Recipe schema. Native text edit ranges
carry surviving line identities. Text is retained immediately; completing a line,
pasting, leaving the field, switching modes or Save completes interpretation.
Quantity weight, underlined units, italic supporting details and accent color
provide redundant visual distinctions without replacing authored text or moving
the selection. A single `# ` prefix creates a real IngredientSection; removing it
converts the line back. Add Ingredient Section inserts the same prefix through the
native text control. Native text undo/redo restores text and its draft identities
while that text control remains open; application-wide undo remains deferred.

Changed precise ingredients retain their existing adjustments and an explicit
parser proposal. The reader must keep the details or accept the proposal before
Save can publish. Those unresolved choices and active text survive local draft
recovery. Merely opening simple editing does not reinterpret maintained content.
Close retains the draft, Save publishes a Revision, and Discard still uses the
existing confirmation. Organization retains the commit boundaries documented above.
