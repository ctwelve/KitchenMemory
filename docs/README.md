# Kitchen Memory development documentation

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

Build a faithful, private, local-first recipe book for real household kitchens.

## Overview

Kitchen Memory preserves recipes, makes uncertainty visible, and records what
happened while cooking without silently changing the canonical recipe. This
directory collects the product doctrine, architecture, workflows, engineering
practice, and accepted decisions that guide implementation while Kitchen
Memory is under active development.

Version 0.1.0 is the first public alpha. Its direct-download macOS application
is signed with Developer ID, notarized by Apple, and published in the GitHub
release attached to the immutable `release/0.1.0` source tag. The iPhone and
iPad product is implemented in the source tree but is not yet publicly
distributed through TestFlight or the App Store. See
[0.1 release evidence](release-evidence-0.1.md) for the exact claims and
deferred gates.

The native iOS and macOS application targets currently compile a basic shared
SwiftUI layer to exercise the product's foundation slices. That interface is
implementation scaffolding, not a commitment that the mature Mac and mobile
products must share one presentation architecture.

## Topics

### Product direction

- [Product doctrine](product-doctrine.md)
- [Product brief](product-brief.md)
- [Naming](naming.md)
- [Alpha roadmap](alpha-roadmap.md)
- [Roadmap to 0.2](roadmap-0.2.md)
- [0.1 release notes](release-notes-0.1.md)
- [Release engineering](release-engineering.md)
- [0.1 release evidence](release-evidence-0.1.md)
- [Privacy engineering](privacy.md)
- [Open questions](open-questions.md)

### Domain and workflows

- [Recipe domain model](recipe-domain-model.md)
- [Domain architecture](domain-architecture.md)
- [Web import](web-import.md)
- [Fuzzy pantry](fuzzy-pantry.md)
- [Planned cooks](planned-cooks.md)
- [Cooking sessions](cooking-sessions.md)
- [Workflows](workflows.md)

### Apple platforms and engineering

- [Apple platforms](apple-platform.md)
- [Implementation architecture](implementation-architecture.md)
- [Personal iCloud synchronization](personal-icloud-synchronization.md)
- [Localization architecture](localization-architecture.md)
- [Accessibility engineering](accessibility-engineering.md)
- [Continuous integration](continuous-integration.md)

### Architecture decisions

- [0001: Apple platform](adr/0001-apple-platform.md)
- [0002: GPL-3.0-only](adr/0002-gpl-3-only.md)
- [0003: Domain-persistence boundary](adr/0003-domain-persistence-boundary.md)
- [0004: Apple persistence and portability](adr/0004-apple-persistence-and-portability.md)
- [0005: Testing and comprehension](adr/0005-testing-and-comprehension.md)
- [0006: Shared UI for foundation slices](adr/0006-shared-ui-for-foundation-slices.md)
- [0007: Business-logic coverage and UI smoke tests](adr/0007-business-logic-coverage-and-ui-smoke-tests.md)
- [0008: Freeze the 0.1 localization contract](adr/0008-freeze-the-0-1-localization-contract.md)
- [0009: Separate native app targets](adr/0009-separate-native-app-targets.md)
