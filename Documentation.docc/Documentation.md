# ``KitchenMemory``

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

Build a faithful, private, local-first recipe book for real household kitchens.

## Overview

Kitchen Memory preserves recipes, makes uncertainty visible, and records what
happened while cooking without silently changing the canonical recipe. This
catalog collects the product doctrine, architecture, workflows, engineering
practice, and accepted decisions that guide its implementation.

Version 0.1.0 is the first public-alpha candidate. Its direct-download macOS
application is signed with Developer ID, notarized by Apple, and prepared in a
GitHub draft attached to the immutable `release/0.1.0` source tag. The iPhone
and iPad product is implemented in the source tree but is not yet publicly
distributed through TestFlight or the App Store. See
<doc:release-evidence-0.1> for the exact claims and deferred gates.

The native iOS and macOS application targets currently compile a basic shared
SwiftUI layer to exercise the product's foundation slices. That interface is
implementation scaffolding, not a commitment that the mature Mac and mobile
products must share one presentation architecture.

## Topics

### Product direction

- <doc:product-doctrine>
- <doc:product-brief>
- <doc:naming>
- <doc:alpha-roadmap>
- <doc:release-notes-0.1>
- <doc:release-engineering>
- <doc:release-evidence-0.1>
- <doc:privacy>
- <doc:open-questions>

### Domain and workflows

- <doc:recipe-domain-model>
- <doc:domain-architecture>
- <doc:web-import>
- <doc:fuzzy-pantry>
- <doc:planned-cooks>
- <doc:cooking-sessions>
- <doc:workflows>

### Apple platforms and engineering

- <doc:apple-platform>
- <doc:implementation-architecture>
- <doc:personal-icloud-synchronization>
- <doc:localization-architecture>
- <doc:accessibility-engineering>
- <doc:continuous-integration>

### Architecture decisions

- <doc:0001-apple-platform>
- <doc:0002-gpl-3-only>
- <doc:0003-domain-persistence-boundary>
- <doc:0004-apple-persistence-and-portability>
- <doc:0005-testing-and-comprehension>
- <doc:0006-shared-ui-for-foundation-slices>
- <doc:0007-business-logic-coverage-and-ui-smoke-tests>
- <doc:0008-freeze-the-0-1-localization-contract>
- <doc:0009-separate-native-app-targets>
