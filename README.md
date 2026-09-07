<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

# Kitchen Memory

> Cook, remember, improve.

Kitchen Memory is a private, local-first recipe book for Mac, iPhone, and iPad.
It preserves the recipe you meant to save, makes corrections inexpensive, and
keeps useful cooking structure without pretending every ingredient can be
reduced to a perfect database row.

Version 0.2.2 is the current public alpha. A signed and notarized universal macOS
build is available from [GitHub Releases](https://github.com/ctwelve/KitchenMemory/releases).
The iPhone and iPad application is present in the source tree, but this alpha
does not yet have a public iOS download or TestFlight group.

## Download and install

The macOS alpha requires macOS 26 or later and runs natively on Apple silicon
and Intel Macs.

1. Download `KitchenMemory-0.2.2-macOS.zip` from the 0.2.2 release.
2. Expand the archive and move **Kitchen Memory** to Applications.
3. Launch it normally. The distributed app is signed with Developer ID,
   notarized by Apple, and carries a stapled notarization ticket.
4. On first launch, choose whether to add the bundled sample recipes.

> **Alpha data is disposable.** Kitchen Memory alpha is destructive,
> crash-test-dummy building and testing. Nothing saved by an alpha build should
> be considered permanent. Keep the original copies of anything that matters.
> The project will deliberately hard-reset alpha cloud storage and stabilize its
> data contract when beta begins.

The core recipe and Cooking Session loops work, but the interface and storage
contract are intentionally provisional. This freedom lets the project repair
foundational mistakes aggressively before promising beta-grade durability.

## What the alpha can do

- Create and edit structured recipes without requiring every field.
- Import bounded Schema.org `Recipe` JSON-LD from a webpage and review it before
  saving.
- Preserve original ingredient wording, source attribution, and uncertain or
  unscalable quantities instead of inventing precision.
- Save edits as immutable revisions.
- Scale exact and ranged quantities for a working yield without changing the
  maintained recipe.
- Present sectioned ingredients and instructions for reading while cooking.
- Run Cooking Sessions with immutable snapshots, progress, notes, recovery, and
  history without rewriting the maintained recipe.
- Keep one person's recipe library synchronized privately through their iCloud
  account while retaining a useful local store.
- Run in English (United States), Canadian French, and Mexican Spanish, with a
  localized starter-recipe pack.

Pantry knowledge, planning, shopping, household sharing, OCR, nutrition
calculation, and public recipe discovery are deliberately not part of this
alpha.

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

## Documentation and contributing

Start with the [development documentation map](docs/README.md) for current
product contracts, engineering guidance, decisions, and historical evidence.
[AI.md](AI.md) describes AI-assisted development; [AGENTS.md](AGENTS.md) routes
repository instructions for coding agents.

Open `KitchenMemory.xcodeproj` in Xcode. Run the **KitchenMemory** scheme on
an iPhone, iPad, iOS Simulator, or My Mac destination. Development builds use
separate app sandboxes and `iCloud.net.ctwelve.dev.KitchenMemory`; the Production
container is `iCloud.net.ctwelve.KitchenMemory`.

The [implementation guide](docs/implementation-architecture.md) explains code
ownership. The [CI contract](docs/continuous-integration.md) owns schemes, test
plans, structural checks, and coverage. Run native application and UI tests
through [Xcode's Test action](docs/agents/xcode.md) so Xcode signs the runner.

## License

Copyright © 2026 the Kitchen Memory contributors. See [COPYRIGHT](COPYRIGHT)
for the repository-wide notice and [AI.md](AI.md) for the project's statement
on AI-assisted development.

Kitchen Memory is open-source software licensed under the
[MIT License](LICENSE) (`MIT`).
The reviewed third-party package and build-tool inventory is available in
[DEPENDENCIES.md](DEPENDENCIES.md), with its machine-readable SPDX record in
[SBOM.spdx.json](SBOM.spdx.json).
