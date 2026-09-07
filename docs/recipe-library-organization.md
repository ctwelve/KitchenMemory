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

Folder and Tag visibility and Folder expansion are device-local preferences.
Hiding a feature does not stop its projection, acceptance or synchronization.
Alphabetical/manual ordering and the visibility of the computed Unfiled and
Untagged views are independent causal registers in their respective synchronized
policies. Alphabetical presentation uses the local locale; switching modes does
not remove the manual sequence. The new visibility actions extend the encoded
organization payload vocabulary; older alpha builds cannot decode them.

Folder scope includes its subtree. Selected Tags intersect with each other, the
Folder scope and Recipe text search. Unfiled has no stored identity and remains
available even without Folders; Untagged additionally requires a live Tag.
Hidden local features contribute no filter constraint. Iterative Folder outline
construction handles deep hierarchies without recursive view construction.

Bulk operations and native drops use the same prepared command boundary as menus.
Name collisions remain readable in Recovery even with both presentation features
hidden. Merge requires confirmation; Rename remains available through management.
Organization deletion affects ordinary presentation immediately and never deletes
Recipe content or creates Deleted Items.

## Validation boundary

Framework tests own atomicity, stable retries, draft recovery, causal preferences,
filtering and deep outline traversal. Hosted tests own local preference persistence,
drop decoding, command retry state and hidden-feature Recovery. Native UI tests
prove only the accessible top-level management destination, consistent with
[ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md). Detailed feature
workflows remain below the UI automation boundary; human platform and assistive
technology review is still required for release acceptance.
