# CloudKit Production-container schema administration

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

This one-shot Mac tool initializes Kitchen Memory's additive V7 model in the
**Development environment of the Production container**. It exists only so a
release operator can review an additive deployment preview before deliberately
promoting that schema to Production.

For 0.3.0, compare the live deployed schema with the frozen V4 baseline and
accepted V7 model. V5–V7 add six model families: `RecipeSaveRecord`,
`RecipeSelectionRecord`, `RecipePruneRecord`, `RecipeImagePayloadRecord`,
`OrganizationActionRecord`, and `OrganizationCheckpointRecord`. The deployed
V4 baseline additionally needs `CD_deletedAt` on
`CD_RecipeDeletionRecord`, and `CD_kitchenID` plus `CD_restoredAt` on
`CD_RecipeDeletionResolutionRecord`. Existing field definitions, indexes, roles,
and encryption choices must remain unchanged; no existing type is removed.
Review generated CloudKit fields, assets,
indexes, and standard roles against the local model and deployment preview;
any unexplained change stops the release. The V4 procedure remains historical
evidence in `docs/release-evidence-0.2.2.md`.

The tool is absent from the Kitchen Memory project, shared schemes, test plans,
archives, and product binaries. It uses a disposable temporary store, refuses
every container except `iCloud.net.ctwelve.KitchenMemory`, and performs no
Production deployment. CloudKit Console remains the only deployment surface.

Build it from an accepted source tree by naming the already reviewed macOS
acceptance archive whose provisioning profile permits the Production container:

```sh
KM_PRODUCTION_ARCHIVE=/absolute/path/to/KitchenMemory.xcarchive \
  Tools/CloudKitProductionSchemaAdmin/build.sh
```

Run the one supported operation with the accepted product commit:

```sh
Tools/CloudKitProductionSchemaAdmin/run.sh \
  <accepted-0.3.0-source-commit>
```

Success means only that the Development server schema accepted the additive
model operation. The operator must still inspect record types, fields, indexes,
roles, encryption state, and the deployment preview. Never treat this tool's
output as Production-deployment evidence.
