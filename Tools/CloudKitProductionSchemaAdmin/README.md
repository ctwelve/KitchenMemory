# CloudKit Production-container schema administration

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

This one-shot Mac tool initializes Kitchen Memory's frozen V3 model in the
**Development environment of the Production container**. It exists only so a
release operator can review an additive deployment preview before deliberately
promoting that schema to Production.

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
  479b3608f42448821a61727e45c15ce234207e2a
```

Success means only that the Development server schema accepted the additive
model operation. The operator must still inspect record types, fields, indexes,
roles, encryption state, and the deployment preview. Never treat this tool's
output as Production-deployment evidence.
