# Localization and recipe resources

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Accepted direction
- Date: 2026-08-22

Kitchen Memory's first localization set is English, Canadian French
(`fr-CA`), and Mexican Spanish (`es-MX`). English is the development language;
the regional identifiers are intentional because recipe vocabulary, measurements,
and ordinary kitchen language vary by market. German, Italian, and additional
locales may follow without changing the architectural boundary.

Internationalization has two distinct resource problems:

1. interface language and formatted messages; and
2. authored recipe content bundled with the application.

They use different resource models and must not be collapsed into one large
table of sentence fragments.

## Interface language

Application-shell labels, actions, settings, validation messages, and formatted
counts belong in String Catalogs owned by the `KitchenMemory` application target.
The catalogs carry translator comments and the plural variants required by each
supported locale. Views and presentation adapters request localized values;
`KitchenMemoryDomain`, `KitchenMemoryImport`, `KitchenMemoryPersistence`, and
`KitchenMemoryLogic` do not look up interface strings.

This is the destination boundary, with one known foundation-era exception. The
domain currently exposes English-oriented `renderedText`,
`structuredDisplayText`, and `effectiveDisplayText` helpers, including the words
“about,” “optional,” and the fallback “Ingredient.” `RecipeEditor` also uses that
fallback wording as an empty-row signal. The internationalization slice replaces
the sentinel with semantic validation and moves locale-sensitive composition
behind an application-owned formatter. Authored source wording remains in the
domain; generated interface wording does not.

The reusable frameworks continue to return semantic values such as quantities,
counts, workflow states, and typed failures. For example,
`RecipeImportConcern.unparsedIngredients(count:)` remains a count-bearing value;
the application decides how that concern is phrased and pluralized. This keeps
business-logic tests independent of a development language while allowing
focused presentation tests to exercise locale-specific output.

Numbers, dates, durations, temperatures, and measurements will be formatted for
an explicit locale at the presentation boundary. A formatted value is never
parsed back into a domain value, and changing locale never changes stored
rational quantities or source-faithful ingredient text.

## Bundled recipe packs

A starter recipe is authored content, not interface copy. Its title, summary,
yield wording, section names, ingredients, instructions, source description,
taxonomy, equipment, notes, and image descriptions need translation as a
coherent document. Those fields remain versioned `SampleRecipeDocument` data
assets in `SampleRecipes.xcassets` rather than thousands of disconnected String
Catalog entries.

The locale-aware sample manifest will map one logical sample recipe to explicit
localized data-asset names. Each authored translation has stable recipe,
revision, and child identifiers. The manifest also carries a logical sample-
family identifier used to select among translations. Distinct translated
payloads must not reuse one `Recipe.ID` unless the domain first gains a
first-class localized-content model; otherwise two Kitchens could synchronize
different content under one durable identity. The loader selects the best
supported variant in this order:

1. exact language and region;
2. supported language fallback;
3. the English development asset.

Recipe property lists remain explicit named data sets because Xcode's built-in
asset-localization wells do not cover data sets. Image, color, and symbol assets
may use the asset catalog's language and region variations when their visual
content genuinely needs adaptation. Shared food photography should normally
remain shared; localized accessibility descriptions travel with the recipe
document.

Authored content language is durable recipe metadata, not an inference from the
current application locale. The current `RecipeRevision` has no such field, so
the internationalization slice must add an optional canonical BCP 47 language
tag and carry it through `RecipeDraft`, sample documents, import mapping, and a
new immutable persistence-schema version. Existing revisions migrate as unknown
rather than being mislabeled from the device's current settings.

## Persistence behavior

Bootstrap chooses a localized sample variant before the Kitchen and its recipes
are created atomically. Once stored, that recipe is ordinary local content. A
later system-language change must not silently replace it, discard edits, or
rewrite immutable revision history.

A destructive reset may reseed the current preferred localization because the
person has explicitly chosen to replace the Kitchen. A future explicit
"install sample language" operation may add another authored variant, but it
must use normal recipe operations and the manifest's sample-family relationship
rather than mutating an existing revision in place.

Imported and person-authored recipes preserve the language in which they were
captured. Automatic recipe translation, if added later, creates a reviewable
authored variant with source provenance; it is not an incidental effect of
changing the application locale.

## Testing boundary

Localization tests should remain fast and deterministic:

- select `en`, `fr-CA`, and `es-MX` explicitly rather than inheriting the host;
- exercise every pluralized formatter with representative values for each
  locale;
- verify locale fallback and sample-manifest selection as pure operations;
- decode every localized recipe asset and validate stable identity relationships;
- preserve source strings and numerical domain values across presentation
  locales; and
- keep UI smoke tests identifier-driven rather than asserting translated copy.

Pseudo-localization, longer-text layout review, right-to-left layout proofing,
and focused accessibility automation belong to interface stabilization. Their
deferral does not justify leaving durable strings or formatters outside the
localization boundary now.
