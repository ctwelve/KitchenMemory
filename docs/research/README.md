# Research records

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

[Documentation map](../README.md)

Dates and conclusions describe the investigation, not a current adoption mandate.
[Accepted decisions](../adr/README.md) and current guidance take precedence.
Keep research local while its unresolved questions support current contracts or
open design work. Completed investigations whose conclusions have been adopted
live at fixed Git commits below; recheck their evidence before renewed adoption.

## Current design inputs

- Localization ([planning #192](https://github.com/ctwelve/KitchenMemory/issues/192)): [global language support evidence and staged plan](global-language-expansion.md), with its [independent model review](global-language-independent-review.md). Locale selection and delivery remain separate; the shipping inventory is unchanged.

- Undo ([delivery gate #204](https://github.com/ctwelve/KitchenMemory/issues/204)): [agreed operation policy](application-undo-policy.md), [native facilities](native-undo-facilities.md), [durable storage](durable-undo-storage.md).
- Managed storage: [CloudKit schema evolution](cloudkit-production-schema-evolution.md), [Cooking Session reconciliation facts](managed-cloudkit-session-reconciliation.md). These retain platform constraints and uncompleted service experiments.
- Acquisition ([planning #196](https://github.com/ctwelve/KitchenMemory/issues/196)): [photographs and scans](recipe-photo-and-scan-acquisition.md), [privacy-preserving AI assistance](privacy-preserving-ai-assistance.md).
- Portability ([planning #194](https://github.com/ctwelve/KitchenMemory/issues/194)): [Recipe documents and Kitchen archives](recipe-and-kitchen-interchange.md).
- Future assistance: [allergen awareness and substitution](allergen-awareness-and-substitution.md). This remains a research recommendation; no safety or medical capability is authorized.

## Adopted or superseded investigations

| Evidence in Git history | Current owner or outcome |
| --- | --- |
| [Unified native app target](https://github.com/ctwelve/KitchenMemory/blob/ed91dc532235e0bd6c1571853c0ccb78eee62b66/docs/research/unified-multiplatform-app-target.md) | [ADR 0013](../adr/0013-unified-native-multiplatform-app-target.md) and [implementation architecture](../implementation-architecture.md) own the adopted target structure. |
| [Swift tooling ecosystem survey](https://github.com/ctwelve/KitchenMemory/blob/ed91dc532235e0bd6c1571853c0ccb78eee62b66/docs/research/swift-tooling-ecosystem-survey.md) | [ADR 0014](../adr/0014-prefer-native-capabilities-and-evidence-based-dependencies.md) owns selection policy; [the inventory](../../DEPENDENCIES.md) owns adopted packages. Refresh the dated watchlist only for a concrete new requirement. |
| [Alamofire retrieval comparison](https://github.com/ctwelve/KitchenMemory/blob/ed91dc532235e0bd6c1571853c0ccb78eee62b66/docs/research/alamofire-for-recipe-retrieval.md) | [Web import](../web-import.md) retains the bounded native transport contract. The comparison found no reason to add a networking dependency for the existing surface. |
| [Cloud UI activation investigation](https://github.com/ctwelve/KitchenMemory/blob/ed91dc532235e0bd6c1571853c0ccb78eee62b66/docs/research/macos-cloud-ui-test-activation.md) | [Current CI policy and evidence](../continuous-integration.md#cloud-ui-testing) supersede the suspension. The original activation cause remains unconfirmed. |
| [GPLv3 and paid App Store distribution](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/research/gplv3-paid-app-store-distribution.md) | [ADR 0015](../adr/0015-adopt-mit-license.md) adopted MIT. |
| [Internal framework linkage](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/research/internal-framework-linkage.md) | [ADR 0012](../adr/0012-consolidate-business-code-in-kitchenkit.md) adopted KitchenKit. |

## Completed synthetic experiments

The active investigations retain conclusions, observations and limits. Their
disposable harnesses and generated outputs are preserved together in Git:

- [On-device AI probe and captured output](https://github.com/ctwelve/KitchenMemory/tree/ed91dc532235e0bd6c1571853c0ccb78eee62b66/docs/research/privacy-preserving-ai-assistance-fixtures): three exploratory responses, with no comparative quality or performance claim.
- [Interchange admission/preservation experiment and fixtures](https://github.com/ctwelve/KitchenMemory/tree/ed91dc532235e0bd6c1571853c0ccb78eee62b66/docs/research/recipe-and-kitchen-interchange-fixtures): 24 checks under reduced synthetic limits, with no production codec or complete Kitchen reconstruction proof.

Use a fresh, separately scoped harness for the remaining experiments; these
completed programs are evidence rather than maintained test infrastructure.
