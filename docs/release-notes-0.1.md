# Kitchen Memory 0.1.0

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

Kitchen Memory 0.1.0 is the first public alpha: a private, local-first recipe
book built to preserve what a recipe actually says while making it easier to
correct, scale, read, and remember.

## Download

The release includes a signed and notarized universal macOS application for
macOS 26 or later. It runs natively on Apple silicon and Intel Macs.

Download `KitchenMemory-0.1.0-macOS.zip`, expand it, move **Kitchen Memory** to
Applications, and launch it normally. The archive contains version 0.1.0,
build 1.

SHA-256:

```text
b44b1abc65b5eb5548f40aea1d89dafe9d1cf5f2284739a4ce7cc9dcb8fdc268
```

The same digest is attached as `KitchenMemory-0.1.0-macOS.zip.sha256` for
machine-readable verification.

The iPhone and iPad application is implemented in the source tree, but 0.1 does
not yet offer a public iOS artifact or TestFlight group.

## Highlights

- Create and revise structured recipes while leaving incomplete fields honest.
- Import bounded Schema.org `Recipe` JSON-LD from a webpage and review the
  result before saving it.
- Preserve original ingredient wording, source attribution, and uncertain or
  unscalable quantities.
- Keep immutable revision history instead of silently replacing earlier recipe
  content.
- Scale exact and ranged quantities for a working yield without mutating the
  saved recipe.
- Read sectioned ingredients and instructions in a cooking-friendly view.
- Synchronize one person's recipe library privately through their iCloud
  account while continuing to use a local store.
- Use the interface and localized starter catalog in English (United States),
  Canadian French, or Mexican Spanish.

## Privacy

Kitchen Memory contains no advertising, analytics, telemetry, tracking, or
crash-reporting service and declares no collected data in its Apple privacy
manifest. Private iCloud synchronization is a feature the person directs, not
an observation channel for this project. See
[PRIVACY.md](https://github.com/ctwelve/KitchenMemory/blob/main/PRIVACY.md) for
the complete commitment.

## Alpha boundaries

The core recipe loop works, but the interface is intentionally provisional.
Cooking sessions, pantry knowledge, planning, shopping, household sharing,
OCR, nutrition calculation, and public recipe discovery are not part of 0.1.

This release completed a deliberately smaller acceptance exercise than the one
planned for 1.0. Native-language review, the twenty-recipe breadth corpus,
public iOS/TestFlight distribution, and much of the broad multi-device recovery
matrix remain future gates. Keep original copies of recipes that matter while
the alpha storage and recovery experience continues to mature.

## Release verification

The macOS artifact was archived locally from the immutable
`release/0.1.0` source tag after the accepted candidate passed its final iOS and
macOS tests, analysis, and Production builds. Its Developer ID signature,
Gatekeeper acceptance, stapled notarization ticket, production identifiers,
privacy manifest, version, localized resources, and universal executable were
verified after extracting the distributable ZIP. The installed artifact then
launched and completed an ordinary-use walkthrough outside Xcode.

Full engineering evidence is recorded in
[the 0.1 release ledger](release-evidence-0.1.md).

Kitchen Memory is free software licensed under the GNU General Public License,
version 3 only (`GPL-3.0-only`), without warranty.
