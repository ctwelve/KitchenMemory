# Repository tools

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

[Development documentation](../docs/README.md) owns the contracts these tools
verify. Product behavior lives in KitchenKit and the application; these tools
are not shipping product modules.

| Task | Entry point |
| --- | --- |
| Structural/source contracts | `check-project-structure.rb`, `check-localization.rb`, `check-software-inventory.rb`, `check-release-version.rb` |
| Documentation links and currentness | [Documentation maintenance](../docs/documentation-maintenance.md), `check-documentation.rb` |
| Synthetic checker regression tests | `Tests/*_test.rb`; the Cloud post-clone script runs them before package code |
| Exact durable coverage | `run-core-framework-coverage.sh`; [coverage contract](../docs/continuous-integration.md#kitchenkit-coverage-gate) |
| Native application/UI tests | [Xcode agent workflow](../docs/agents/xcode.md); Xcode manages runner signing |
| Synthetic startup measurements | [StartupMeasurements](StartupMeasurements/README.md) |
| Signed Session CloudKit acceptance | [SessionCloudKitAcceptance](SessionCloudKitAcceptance/README.md); device/service evidence, separate from deterministic tests |
| Historical V4 schema initialization | [CloudKitProductionSchemaAdmin](CloudKitProductionSchemaAdmin/README.md); frozen 0.2.2 tool, production container's Development environment only |

The CloudKit tools require their own named-candidate and signing instructions;
they do not authorize Production deployment. Keep credentials, private records,
raw cloud exports, screenshots, and generated result bundles out of the repo.
