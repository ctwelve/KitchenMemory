# Kitchen Memory development documentation

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Build a faithful, private, local-first recipe book for real household kitchens.

This page is the navigation authority for durable development documentation.
Current product and engineering contracts come first. Accepted decisions explain
why those contracts exist. Research, release evidence, and milestone plans are
retained records; they are useful context, but they do not override current
guidance or later accepted decisions.

## Start here

Version 0.2.2 is the current public alpha. The signed and notarized universal
macOS build is published through GitHub Releases. The iPhone and iPad product is
present in the source tree but does not yet have a public download or TestFlight
group. The repository [README](../README.md) is the current product and download
summary, and the [0.2.2 release notes](release-notes-0.2.2.md) describe the
published patch.

The [0.2.2 release evidence](release-evidence-0.2.2.md) is the retained candidate
worksheet. Its in-document status records the validation stage at which the
evidence was captured; it is not the current publication status.

For implementation work, begin with:

- [Product doctrine](product-doctrine.md) for the durable product principles.
- [Domain architecture](domain-architecture.md) and the relevant domain or
  workflow document for product semantics.
- [Implementation architecture](implementation-architecture.md) for the live
  code and target boundaries.
- [Architecture decisions](#accepted-architecture-decisions) for accepted
  constraints and their rationale.
- [Continuous integration](continuous-integration.md) for the current validation
  contract.

## Current product guidance

- [Product doctrine](product-doctrine.md) — accepted durable principles.
- [Product brief](product-brief.md) — product purpose, audience, and boundaries.
- [Privacy engineering](privacy.md) — accepted no-data posture.
- [Public privacy commitment](../PRIVACY.md) — contributor and user-facing
  privacy contract.
- [Naming and voice](naming.md) — working terminology and writing direction.
- [Open questions](open-questions.md) — unresolved product decisions, not
  implementation commitments.

### Domain and workflows

- [Recipe domain model](recipe-domain-model.md)
- [Domain context and vocabulary](../CONTEXT.md)
- [Domain architecture](domain-architecture.md)
- [Web recipe import](web-import.md)
- [Cooking Sessions](cooking-sessions.md) — accepted 0.2 product contract.
- [Cooking Session V3 persistence contract](cooking-session-v3-schema.md) —
  decision-frozen physical schema contract.
- [Personal iCloud synchronization](personal-icloud-synchronization.md)
- [Fuzzy pantry](fuzzy-pantry.md) — exploration, not a shipped contract.
- [Planned cooks and readiness](planned-cooks.md) — accepted future direction.
- [Product workflows](workflows.md) — exploration, not a shipped contract.

## Current engineering guidance

- [Apple platform and automation architecture](apple-platform.md)
- [Implementation architecture](implementation-architecture.md)
- [Localization and recipe resources](localization-architecture.md)
- [Accessibility engineering](accessibility-engineering.md)
- [Continuous integration](continuous-integration.md)
- [Third-party dependency inventory](../DEPENDENCIES.md)
- [Artificial intelligence use](../AI.md)

### Agent operations

These files define repository workflow for coding agents. They are operational
guidance, not product or architecture decisions.

- [Repository agent instructions](../AGENTS.md)
- [Domain-document routing](agents/domain.md)
- [GitHub issue tracker workflow](agents/issue-tracker.md)
- [Canonical triage labels](agents/triage-labels.md)

## Accepted architecture decisions

Accepted ADRs are current unless their own status says that a later decision
amends them.

- [0001: Build a native SwiftUI application](adr/0001-apple-platform.md)
- [0003: Domain-persistence boundary](adr/0003-domain-persistence-boundary.md)
- [0004: Apple persistence and portability](adr/0004-apple-persistence-and-portability.md)
- [0005: Testing and comprehension](adr/0005-testing-and-comprehension.md)
- [0006: Use a shared UI for the foundation slices](adr/0006-shared-ui-for-foundation-slices.md)
- [0007: Business-logic coverage and UI smoke tests](adr/0007-business-logic-coverage-and-ui-smoke-tests.md)
- [0008: Freeze the 0.1 localization contract](adr/0008-freeze-the-0-1-localization-contract.md)
- [0010: Distinct Cooking Session module seam](adr/0010-distinct-cooking-session-module.md)
- [0011: Cooking Session document envelopes](adr/0011-use-document-envelopes-for-cooking-sessions.md)
- [0012: Consolidate business code in KitchenKit](adr/0012-consolidate-business-code-in-kitchenkit.md)
- [0013: Unify the native application target](adr/0013-unified-native-multiplatform-app-target.md)
- [0014: Native capabilities and evidence-based dependencies](adr/0014-prefer-native-capabilities-and-evidence-based-dependencies.md)
- [0015: Adopt the MIT License](adr/0015-adopt-mit-license.md)
- [0016: Alpha data contract and beta stabilization](adr/0016-alpha-data-contract-and-beta-stabilization.md)

### Superseded architecture decisions

These ADRs are retained as decision history. Do not treat them as current
implementation instructions; follow the linked replacement.

- [0002: License the project under GPLv3 only](adr/0002-gpl-3-only.md) —
  superseded by ADR 0015.
- [0009: Separate native app targets](adr/0009-separate-native-app-targets.md) —
  superseded by ADR 0013.

## Research records

Research records preserve the question, evidence, and conclusion available at
the time. They are not current implementation instructions unless an accepted
ADR or current guidance document adopts their conclusion.

- [Alamofire for recipe retrieval](research/alamofire-for-recipe-retrieval.md) —
  research complete; do not adopt for the current fetcher.
- [CloudKit production schema evolution](research/cloudkit-production-schema-evolution.md)
- [GPLv3 and paid App Store distribution](research/gplv3-paid-app-store-distribution.md) —
  historical licensing research superseded by ADR 0015.
- [Internal framework linkage](research/internal-framework-linkage.md) —
  pre-consolidation research superseded by ADR 0012's chosen topology.
- [Managed CloudKit Cooking Session reconciliation](research/managed-cloudkit-session-reconciliation.md)
- [Swift tooling ecosystem survey](research/swift-tooling-ecosystem-survey.md) —
  selection policy adopted by ADR 0014.
- [Unified native multiplatform app target](research/unified-multiplatform-app-target.md) —
  adopted and validated by ADR 0013.

## Release records and milestone history

These documents are retained evidence for particular releases or planning
boundaries. Their dates, target names, and pending gates describe those
milestones and must not be mistaken for the live engineering contract above.

### Current public release: 0.2.2

- [0.2.2 release notes](release-notes-0.2.2.md)
- [0.2.2 candidate evidence](release-evidence-0.2.2.md) — retained prepublication
  validation worksheet; see [Start here](#start-here) for current status.

### Earlier 0.2 records

- [0.2 acceptance contract](acceptance-0.2.md)
- [0.2 Cooking Sessions roadmap](roadmap-0.2.md)
- [0.2 release evidence](release-evidence-0.2.md)
- [Rejected 0.2.1 candidate notes](release-notes-0.2.1.md)
- [Rejected 0.2.1 candidate evidence](release-evidence-0.2.1.md)

### 0.1 records

- [0.1 roadmap and release boundary](alpha-roadmap.md)
- [0.1 release engineering](release-engineering.md)
- [0.1 release evidence](release-evidence-0.1.md)
- [0.1 release notes](release-notes-0.1.md)
