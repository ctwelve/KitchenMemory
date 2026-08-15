<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# Kitchen Memory

> Cook, remember, improve.

A collaborative, local-first recipe book for real household kitchens.

The project begins with recipes: capture them accurately, make them pleasant to
cook from, and structure their ingredients well enough to support planning and
shopping. Later, those ingredients connect to a deliberately **fuzzy pantry**—a
model that can say “we usually have this,” “running low,” or “not sure” instead
of requiring warehouse-grade inventory.

## Project thesis

Most recipe apps treat ingredients as display text. Most pantry apps demand
precise stock counts. A useful household tool needs a middle path:

- preserve recipes faithfully, including their original wording;
- understand quantities, units, ingredients, and preparation notes when it can;
- make uncertainty visible rather than inventing precision;
- work locally and remain useful without a service connection;
- make sharing with a family feel like sharing a kitchen, not administering a
  database.

## Current scope

The first product slice is:

1. Create and edit a recipe.
2. Import a recipe from a webpage using Schema.org JSON-LD.
3. Review the imported ingredient structure without losing the source text.
4. Scale a recipe and cook from clear, sectioned instructions.

Pantry inventory, meal planning, and shopping follow after this slice is useful.

## Documentation

- [Documentation library](Documentation.docc/Documentation.md) — complete guide
- [Product doctrine](Documentation.docc/Articles/product-doctrine.md) — consolidated product direction
- [Alpha roadmap](Documentation.docc/Articles/alpha-roadmap.md) — remaining slices to a working alpha
- [Naming and voice](Documentation.docc/Articles/naming.md)
- [Product brief](Documentation.docc/Articles/product-brief.md)
- [Recipe domain model](Documentation.docc/Articles/recipe-domain-model.md)
- [Domain architecture](Documentation.docc/Articles/domain-architecture.md)
- [Web import design](Documentation.docc/Articles/web-import.md)
- [Fuzzy pantry concept](Documentation.docc/Articles/fuzzy-pantry.md)
- [Planned cooks and readiness](Documentation.docc/Articles/planned-cooks.md)
- [Cooking sessions and deviations](Documentation.docc/Articles/cooking-sessions.md)
- [Product workflows](Documentation.docc/Articles/workflows.md)
- [Apple platform and automation architecture](Documentation.docc/Articles/apple-platform.md)
- [Continuous integration](Documentation.docc/Articles/continuous-integration.md)
- [Accessibility engineering](Documentation.docc/Articles/accessibility-engineering.md)
- [Open questions](Documentation.docc/Articles/open-questions.md)
- [Architecture decisions](Documentation.docc/Documentation.md#Architecture-decisions)
- [Artificial intelligence use](AI.md)

## Development

Open `KitchenMemory.xcodeproj` in Xcode and run the **KitchenMemory** scheme on
My Mac or an iOS Simulator. The application is based on Xcode's standard
multiplatform SwiftUI structure and uses SwiftData as its first local persistence
implementation. On first launch, it installs the bundled Tuna Noodle Hotdish as
starter content into a newly created local Kitchen and opens the read-only
recipe library. The Kitchen gets an installation-specific identity; bundled
recipes retain their hand-assigned identities so linked Kitchens can recognize
the same samples instead of accumulating duplicates.

The persistence-independent domain lives in the `KitchenMemoryDomain` Swift
package. Run its tests with:

```sh
swift test --package-path KitchenMemoryDomain
```

CloudKit is the selected synchronization and collaboration platform; the
precise shared-Kitchen integration will be selected after a focused
collaboration prototype.

## License

Copyright © 2026 the Kitchen Memory contributors. See [COPYRIGHT](COPYRIGHT)
for the repository-wide notice and [AI.md](AI.md) for the project's statement
on AI-assisted development.

This project is free software licensed under the
[GNU General Public License, version 3 only](LICENSE) (`GPL-3.0-only`). See
`LICENSE` for the complete terms.
