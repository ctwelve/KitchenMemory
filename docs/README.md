# Kitchen Memory development documentation

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Use this map to load the guidance for the work at hand. Current contracts and
accepted decisions govern implementation; research and milestone records explain
how we got here. GitHub Issues owns the live plan and dependencies. The root
[README](../README.md) describes the published alpha and downloads.

## Start here

| Work | Read |
| --- | --- |
| Understand the product | [Product brief](product-brief.md), then [doctrine](product-doctrine.md) |
| Name or change concepts | [Domain vocabulary](../CONTEXT.md), [domain architecture](domain-architecture.md), relevant [decisions](adr/README.md) |
| Find code ownership | [Implementation architecture](implementation-architecture.md), then the [KitchenKit](../KitchenKit/KitchenKit.docc/KitchenKit.md) or [app](../KitchenMemory/Documentation.docc/Documentation.md) DocC guide |
| Build or validate | [CI and test contract](continuous-integration.md); [Xcode agent workflow](agents/xcode.md) for signed native tests |
| Prepare or publish a release | [Release engineering](release-engineering.md), [preparation loop](release-preparation.md) |
| Maintain these docs | [Routing and validation contract](documentation-maintenance.md) |

## Product contracts

- Recipe content: [domain model](recipe-domain-model.md), [web import](web-import.md), [private media](recipe-media.md).
- Recipe authority: [V5 storage contract](recipe-authority-v5-schema.md), [reconciliation](recipe-reconciliation.md), [deletion and restoration](recipe-disposition.md), [retention and Recovery](recipe-retention.md).
- Organization: [native library](recipe-library-organization.md), [Folders](folders.md), [Tags](tags.md), [reversible sample pack](sample-pack.md).
- Cooking: [Sessions](cooking-sessions.md), [V3 storage contract](cooking-session-v3-schema.md).
- Storage operation: [personal iCloud](personal-icloud-synchronization.md), [records maintenance](records-maintenance.md).
- Person-facing policy: [public privacy commitment](../PRIVACY.md), [privacy engineering](privacy.md), [naming and voice](naming.md).

## Engineering contracts

- [Apple platform direction](apple-platform.md)
- [Localization and authored resources](localization-architecture.md)
- [Accessibility and alpha/beta acceptance](accessibility-engineering.md)
- [Dependency inventory](../DEPENDENCIES.md) and [AI use](../AI.md)
- [Repository agent instructions](../AGENTS.md), [domain routing](agents/domain.md), [issue workflow](agents/issue-tracker.md), [triage labels](agents/triage-labels.md)

## Future direction

These are design inputs, not claims about shipped features or implementation
queues: [open questions](open-questions.md), [workflow exploration](workflows.md),
[fuzzy pantry](fuzzy-pantry.md), and [planned cooks](planned-cooks.md).

## Accepted architecture decisions

The [decision index](adr/README.md) includes current decisions, amendments, and
superseded records. Consult the decisions for the boundary being changed.

## Research records

The [research index](research/README.md) routes capability investigations and
synthetic experiments. Recheck evidence before adopting an old recommendation.

## Release records and milestone history

The [history index](history.md) retains release notes, candidate evidence,
completed roadmaps, startup measurements, localization review, and alpha
accessibility evidence. It includes the [0.3 release-preparation audit](release-preparation-0.3.md).
