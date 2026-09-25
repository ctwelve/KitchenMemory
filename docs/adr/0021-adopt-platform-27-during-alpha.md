# ADR 0021: Adopt platform 27 during alpha

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Status: Accepted, 2026-09-25.

Kitchen Memory requires macOS 27 and iOS/iPadOS 27 across all application,
framework, test, and acceptance-tool configurations. Xcode 27 is the development
and validation toolchain. This is a deliberate alpha compatibility break:
SwiftUI and accessibility changes warrant a consistent platform baseline rather
than accumulating fallback behavior before the interface stabilizes.

We prioritize reproducing release failures locally before spending more CI time.
The local release test plan must run on the same Xcode, OS, and small-screen
simulator configuration as Xcode Cloud. A build or a passing larger-device test
does not establish compact-layout accessibility. Dependency updates retain exact
reviewed pins, licensing/privacy review, and an aligned software inventory.

The alternative was retaining 26.5 with availability branches. During alpha,
the maintainer accepts losing older-OS compatibility in return for one current
SwiftUI/accessibility baseline. This decision changes no persisted format,
CloudKit schema, or public domain interface. Platform 27 does not by itself fix
the outstanding editor toolbar failure or debug-map warnings; those still need
local evidence.

macOS 27 supports only Apple silicon Macs. Release collection therefore requires
an `arm64` Mac executable instead of requiring an additional Intel slice. Signing,
notarization, entitlement, and identity checks remain mandatory. See Apple's
[macOS 27 compatibility guidance](https://support.apple.com/en-us/127455).
