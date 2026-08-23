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

## Current alpha scope

The implemented recipe foundation and remaining alpha loop are:

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
- [Implementation architecture](Documentation.docc/Articles/implementation-architecture.md)
- [Localization and recipe resources](Documentation.docc/Articles/localization-architecture.md)
- [Continuous integration](Documentation.docc/Articles/continuous-integration.md)
- [Accessibility engineering](Documentation.docc/Articles/accessibility-engineering.md)
- [Testing strategy](Documentation.docc/Articles/Decisions/0007-business-logic-coverage-and-ui-smoke-tests.md)
- [Open questions](Documentation.docc/Articles/open-questions.md)
- [Architecture decisions](Documentation.docc/Documentation.md#Architecture-decisions)
- [Artificial intelligence use](AI.md)

## Development

Open `KitchenMemory.xcodeproj` in Xcode and run the **KitchenMemory** scheme on
My Mac or an iOS Simulator. The application is based on Xcode's standard
multiplatform SwiftUI structure and uses SwiftData as its first local persistence
implementation. On first launch, it creates an empty local Kitchen and asks
whether the person wants to install the bundled sample recipe pack. The answer
is stored independently of recipe data only to avoid repeating onboarding; it
is not standing permission to restore deleted content. Settings derives
none/partial/complete installation state from stable sample UUIDs and adds only
missing identities when explicitly asked. The Kitchen gets an installation-
specific identity; bundled recipes retain their hand-assigned identities so
installation, future merging, and reset behavior are deterministic. Localized
authored variants are related by the sample manifest rather than pretending
that two different recipe payloads are one durable recipe revision.

The app's internal domain, import, persistence, and product-logic modules live
under `KitchenMemory/Modules` as native Xcode framework targets. Bundled starter
content and presentation adapters compile directly into `KitchenMemory`. All
tests run in the shared `KitchenMemory` scheme and committed test plan:

```sh
xcodebuild test \
  -project KitchenMemory.xcodeproj \
  -scheme KitchenMemory \
  -destination 'platform=macOS'
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
