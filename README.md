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

## Current 0.1 scope

The 0.1 feature baseline is implemented:

1. Create and edit a recipe.
2. Import a recipe from a webpage using Schema.org JSON-LD.
3. Review the imported ingredient structure without losing the source text.
4. Scale and read a recipe from clear, sectioned instructions.
5. Keep the local-first recipe library synchronized across one person's devices.

The next pass is release engineering: harden, package, distribute, and prove
this existing loop without adding another product feature. Cooking sessions,
pantry inventory, meal planning, shopping, and household sharing follow later.

## Documentation

- [Documentation library](Documentation.docc/Documentation.md) — complete guide
- [Product doctrine](Documentation.docc/Articles/product-doctrine.md) — consolidated product direction
- [0.1 roadmap](Documentation.docc/Articles/alpha-roadmap.md) — completed feature slices and release boundary
- [0.1 release engineering](Documentation.docc/Articles/release-engineering.md) — hardening and release gates
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
- [Personal iCloud synchronization](Documentation.docc/Articles/personal-icloud-synchronization.md)
- [Localization and recipe resources](Documentation.docc/Articles/localization-architecture.md)
- [Continuous integration](Documentation.docc/Articles/continuous-integration.md)
- [Accessibility engineering](Documentation.docc/Articles/accessibility-engineering.md)
- [Testing strategy](Documentation.docc/Articles/Decisions/0007-business-logic-coverage-and-ui-smoke-tests.md)
- [Open questions](Documentation.docc/Articles/open-questions.md)
- [Architecture decisions](Documentation.docc/Documentation.md#Architecture-decisions)
- [Artificial intelligence use](AI.md)

## Development

Open `KitchenMemory.xcodeproj` in Xcode and run the **KitchenMemory Debugging**
scheme on My Mac or an iOS Simulator. The application is based on Xcode's standard
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
content and presentation adapters compile directly into `KitchenMemory`.
Business-logic, application, and persistence tests run in the shared
`KitchenMemory Testing` scheme and committed non-UI test plan:

```sh
xcodebuild test \
  -project KitchenMemory.xcodeproj \
  -scheme 'KitchenMemory Testing' \
  -destination 'platform=macOS'
```

The small UI smoke suite runs only through the `KitchenMemory Production`
scheme. See the architecture and continuous-integration documentation for the
Debug, Develop, Testing, Production, and non-distributable ProductionTesting
configuration policy.

CloudKit is the selected synchronization and collaboration platform. The first
private cross-device integration lives behind the persistence adapter; the
precise shared-Kitchen integration remains subject to a later post-1.0
collaboration prototype.

## License

Copyright © 2026 the Kitchen Memory contributors. See [COPYRIGHT](COPYRIGHT)
for the repository-wide notice and [AI.md](AI.md) for the project's statement
on AI-assisted development.

This project is free software licensed under the
[GNU General Public License, version 3 only](LICENSE) (`GPL-3.0-only`). See
`LICENSE` for the complete terms.
