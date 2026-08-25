<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# Kitchen Memory

> Cook, remember, improve.

Kitchen Memory is a private, local-first recipe book for Mac, iPhone, and iPad.
It preserves the recipe you meant to save, makes corrections inexpensive, and
keeps useful cooking structure without pretending every ingredient can be
reduced to a perfect database row.

Version 0.1.0 is the first public alpha. A signed and notarized universal macOS
build is available from [GitHub Releases](https://github.com/ctwelve/KitchenMemory/releases).
The iPhone and iPad application is present in the source tree, but this alpha
does not yet have a public iOS download or TestFlight group.

## Download and install

The macOS alpha requires macOS 26 or later and runs natively on Apple silicon
and Intel Macs.

1. Download `KitchenMemory-0.1.0-macOS.zip` from the 0.1.0 release.
2. Expand the archive and move **Kitchen Memory** to Applications.
3. Launch it normally. The distributed app is signed with Developer ID,
   notarized by Apple, and carries a stapled notarization ticket.
4. On first launch, choose whether to add the bundled sample recipes.

This is early-alpha software. The core recipe loop works, but the interface is
intentionally provisional and the acceptance exercise is smaller than the one
planned for 1.0. Keep the original copies of recipes that matter to you while
the storage and recovery experience continues to mature.

## What 0.1 can do

- Create and edit structured recipes without requiring every field.
- Import bounded Schema.org `Recipe` JSON-LD from a webpage and review it before
  saving.
- Preserve original ingredient wording, source attribution, and uncertain or
  unscalable quantities instead of inventing precision.
- Save edits as immutable revisions.
- Scale exact and ranged quantities for a working yield without changing the
  maintained recipe.
- Present sectioned ingredients and instructions for reading while cooking.
- Keep one person's recipe library synchronized privately through their iCloud
  account while retaining a useful local store.
- Run in English (United States), Canadian French, and Mexican Spanish, with a
  localized starter-recipe pack.

Cooking sessions, pantry knowledge, planning, shopping, household sharing,
OCR, nutrition calculation, and public recipe discovery are deliberately not
part of 0.1. The next feature release is expected to explore cooking sessions
without confusing what happened during one cook with the canonical recipe.

## Privacy

Kitchen Memory has no advertising, analytics, telemetry, tracking, or crash-
reporting service. The app declares no collected data in its Apple privacy
manifest. Recipe synchronization uses your private iCloud database as a feature
you direct; it is not an observation channel for this project.

See [PRIVACY.md](PRIVACY.md) for the complete commitment, including the promise
not to retain private debugging material or reveal Aunt Matilda's secret
artichoke dip recipe in public.

## Why Kitchen Memory exists

Most recipe apps treat ingredients as display text. Most pantry apps demand
precise stock counts. Real kitchens live between those extremes. A useful
household tool should preserve recipes faithfully, understand structure where
it honestly can, and remain comfortable saying “probably,” “running low,” or
“I don't know.”

The recipe library comes first because planning, shopping, pantry knowledge,
and cooking history are only trustworthy when the underlying recipe has not
been flattened or silently rewritten.

## Documentation

- [Documentation library](Documentation.docc/Documentation.md) — product,
  architecture, workflows, and engineering guidance
- [0.1 release notes](Documentation.docc/Articles/release-notes-0.1.md)
- [0.1 release evidence](Documentation.docc/Articles/release-evidence-0.1.md)
- [0.1 release engineering](Documentation.docc/Articles/release-engineering.md)
- [Product doctrine](Documentation.docc/Articles/product-doctrine.md)
- [Product brief](Documentation.docc/Articles/product-brief.md)
- [Recipe domain model](Documentation.docc/Articles/recipe-domain-model.md)
- [Personal iCloud synchronization](Documentation.docc/Articles/personal-icloud-synchronization.md)
- [Localization architecture](Documentation.docc/Articles/localization-architecture.md)
- [Continuous integration](Documentation.docc/Articles/continuous-integration.md)
- [Architecture decisions](Documentation.docc/Documentation.md#Architecture-decisions)
- [Artificial intelligence use](AI.md)

## Building from source

Open `KitchenMemory.xcodeproj` in Xcode. Run **KitchenMemory iOS Development**
for an iOS Simulator or development device, or **KitchenMemory macOS
Development** for My Mac.

Development builds use the `net.ctwelve.dev` application namespace and the
separate `iCloud.net.ctwelve.dev.KitchenMemory` container. They cannot read or
administer the production app's iCloud data. Production and Development also
use separate local application sandboxes.

The repository contains separate native iOS and macOS app targets. Shared
presentation, localization, and starter content live in `KitchenMemory`;
platform-owned files live in `KitchenMemoryIOS` and `KitchenMemoryMac`. Durable
domain, import, product-logic, and persistence code lives in root-level native
framework targets.

Business-logic, application, and persistence tests run through the committed
platform Testing schemes. For example:

```sh
xcodebuild test \
  -project KitchenMemory.xcodeproj \
  -scheme 'KitchenMemory macOS Testing' \
  -destination 'platform=macOS'
```

The shared SwiftUI interface is a deliberately provisional 0.1 shell. The
business logic and native app boundaries are intended to survive deeper Mac and
mobile interface work in 0.2.

## License

Copyright © 2026 the Kitchen Memory contributors. See [COPYRIGHT](COPYRIGHT)
for the repository-wide notice and [AI.md](AI.md) for the project's statement
on AI-assisted development.

Kitchen Memory is free software licensed under the
[GNU General Public License, version 3 only](LICENSE) (`GPL-3.0-only`).
