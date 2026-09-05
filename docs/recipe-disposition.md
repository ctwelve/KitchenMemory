# Recipe deletion and restoration

Delete Recipe changes the disposition of the stable Recipe aggregate. It keeps
immutable Revisions, ancestry, selections, provenance, media, and device-local
editing drafts. Existing Cooking Sessions retain their own Execution Snapshots
and remain usable. Saving a retained draft adds evidence without restoring the
Recipe; restoration is a separate explicit intention.

`RecipeDeleteCommand` and `RecipeRestoreCommand` are caller-owned Codable values.
Keep the complete command, including its identity and timestamp, when retrying.
The Recipe repository accepts each command in one isolated local transaction.
Delete writes one deletion row; Restore writes one resolution per observed
deletion, with stable row identities derived from the Restore identity and the
observed deletion identity. Exact retries coalesce; a row identity reused with
different content is rejected. Neither operation removes payload or invokes
Kitchen reset or sample-pack replacement.

Restore resolves only the deletions captured when the person began the action.
A concurrent unobserved deletion keeps the aggregate hidden. Timestamps describe
the action and never select the winner. Save and Selection evidence remain
independent of disposition, so a concurrent Save cannot resurrect a Recipe.

Deleted Items includes Recipes alongside Cooking Sessions. Complete deleted
Recipes offer Restore; missing or unsupported evidence displays a waiting state,
and conflicting or invalid evidence displays a recovery state. These states do
not pretend restoration is currently possible. A refresh can make late content
available without recreating a live Recipe. Failed presentation commands retain
their original identity for an explicit retry during the current app process.
After relaunch, persisted authority remains the source of truth; initiating a new
action creates a new command.

The existing [V5 authority contract](recipe-authority-v5-schema.md) owns the
scalar disposition rows. This feature adds no schema version and no pruning,
automatic sample removal, or permanent-erasure operation. Dependency-aware
pruning and recovery of evidence arriving after pruning remain separate work.
