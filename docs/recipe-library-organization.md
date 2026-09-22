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
moving their controls does not change ownership or persistence. Bulk organization
and text filtering remain in the basic Recipe list for phase one.

## Validation boundary

Framework tests own atomicity, stable retries, draft recovery, causal preferences,
filtering and deep outline traversal. Hosted tests own local preference persistence,
drop decoding, command retry state, hidden-feature Recovery, preference ownership
and list/detail routing. Native UI tests prove named top-level destinations, consistent with
[ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md). Detailed feature
workflows remain below the UI automation boundary; human platform and assistive
technology review is still required for release acceptance.
