# Architecture decisions

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

[Documentation map](../README.md)


Accepted ADRs are current unless their own status says that a later decision
amends them.

- [0001: Build a native SwiftUI application](0001-apple-platform.md)
- [0003: Domain-persistence boundary](0003-domain-persistence-boundary.md)
- [0004: Apple persistence and portability](0004-apple-persistence-and-portability.md)
- [0005: Testing and comprehension](0005-testing-and-comprehension.md)
- [0006: Use a shared UI for the foundation slices](0006-shared-ui-for-foundation-slices.md)
- [0007: Business-logic coverage and constrained UI automation](0007-business-logic-coverage-and-ui-smoke-tests.md)
- [0008: Freeze the 0.1 localization contract](0008-freeze-the-0-1-localization-contract.md) — historical baseline; current locale inventory and proof are in [localization](../localization-architecture.md), with alpha/beta acceptance in ADR 0019
- [0010: Distinct Cooking Session module seam](0010-distinct-cooking-session-module.md)
- [0011: Cooking Session document envelopes](0011-use-document-envelopes-for-cooking-sessions.md)
- [0012: Consolidate business code in KitchenKit](0012-consolidate-business-code-in-kitchenkit.md)
- [0013: Unify the native application target](0013-unified-native-multiplatform-app-target.md)
- [0014: Native capabilities and evidence-based dependencies](0014-prefer-native-capabilities-and-evidence-based-dependencies.md)
- [0015: Adopt the MIT License](0015-adopt-mit-license.md)
- [0016: Alpha data contract and beta stabilization](0016-alpha-data-contract-and-beta-stabilization.md)
- [0017: Additive Recipe authority evidence](0017-use-additive-recipe-authority-evidence.md)

- [0018: Converge release preparation on evidence](0018-converge-release-preparation-on-evidence.md)
- [0019: Stage accessibility acceptance at beta](0019-stage-accessibility-acceptance-at-beta.md)

## Superseded architecture decisions

These ADRs are retained as decision history. Do not treat them as current
implementation instructions; follow the linked replacement.

- [0002: License the project under GPLv3 only](0002-gpl-3-only.md) —
  superseded by ADR 0015.
- [0009: Separate native app targets](0009-separate-native-app-targets.md) —
  superseded by ADR 0013.

