# Localization and recipe resources

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Implemented 0.1 interface contract
- Date: 2026-08-23

Kitchen Memory's first localization set is American English (`en-US`), Canadian
French (`fr-CA`), and Mexican Spanish (`es-MX`). American English is the
development language and universal fallback. The regional identifiers are
intentional because recipe vocabulary, measurements, and ordinary kitchen
language vary by market. German, Italian, and additional locales may follow
without changing the architectural boundary.

Internationalization has two distinct resource problems:

1. interface language and formatted messages; and
2. authored recipe content bundled with the application.

They use different resource models and must not be collapsed into one large
table of sentence fragments.

## Interface language

Application-shell labels, actions, settings, validation messages, and formatted
counts belong in String Catalogs in the shared `KitchenMemory/` application
layer. Explicit target membership compiles those catalogs into both
`KitchenMemoryIOS` and `KitchenMemoryMacOS`. The catalogs carry the plural
variants required by each supported locale. As interface copy stabilizes,
ambiguous terms, placeholders, tone, and screen context receive translator
comments at their extraction sites. Views and presentation adapters request
localized values; `KitchenMemoryDomain`, `KitchenMemoryImport`,
`KitchenMemoryPersistence`, and `KitchenMemoryLogic` do not look up interface
strings.

### Localization-key lifecycle

The frozen 0.1 interface has graduated to semantic localization identifiers such
as `recipe.editor.save-revision`. Every catalog entry provides explicit `en-US`,
`fr-CA`, and `es-MX` values, and English sentences are no longer embedded in
application code or used as durable keys. Application code uses Xcode's generated
`LocalizedStringResource` symbols, including generated functions with named
operands for formatted messages. Each entry carries translator context that
explains its screen, purpose, tone, placeholders, plural operands, or
accessibility role where those details are not already obvious.

This makes product meaning the stable layer while allowing layout to change. A
0.2 redesign should reuse an existing key when the control still expresses the
same meaning, add a new semantic key when meaning or translator context changes,
and remove an obsolete key only after no supported release or retained surface
uses it. Moving a Save action from a toolbar to a menu does not rename its key;
turning Save into a different operation does. Sentence fragments are not
introduced merely to reuse a key, and source-authored recipe wording remains
outside this interface-copy abstraction.

`LocalizationCatalogTests` enforces the 0.1 catalog contract. Keys must be
semantic and manually managed; translator comments and all three locales are
required; every value must be reviewed and nonempty; plural structures must
match; and formatted values must use named placeholders with identical
signatures in every locale. Both platform application-test targets embed an
exact JSON copy of the raw catalog at build time so this source-level contract
remains available when CI builds and runs tests on separate hosts.

This boundary is now enforced. The former English-oriented `renderedText`,
`structuredDisplayText`, and `effectiveDisplayText` domain helpers are gone.
Semantic predicates identify meaningful and structured ingredient content;
`RecipePresentationFormatter` owns locale-sensitive composition such as
“about,” “optional,” durations, quantities, and the fallback “Ingredient.”
Authored source wording remains in the domain; generated interface wording does
not.

The reusable frameworks continue to return semantic values such as quantities,
counts, workflow states, and typed failures. For example,
`RecipeImportConcern.unparsedIngredients(count:)` remains a count-bearing value;
the application decides how that concern is phrased and pluralized. This keeps
business-logic tests independent of a development language while allowing
focused presentation tests to exercise locale-specific output.

Numbers, dates, durations, temperatures, and measurements are formatted for
an explicit locale at the presentation boundary. A formatted value is never
parsed back into a domain value, and changing locale never changes stored
rational quantities or source-faithful ingredient text.

The standard macOS About panel is the intentional resource-level exception.
AppKit reads `Credits.rtf` as formatted bundle content, so the complete document
has `en-US`, `fr-CA`, and `es-MX` resource variants rather than flattening its
formatting and links into String Catalog entries.

## Bundled recipe packs

A starter recipe is authored content, not interface copy. Its title, summary,
yield wording, section names, ingredients, instructions, source description,
taxonomy, equipment, notes, and image descriptions need translation as a
coherent document. Those fields remain versioned `SampleRecipeDocument` data
assets in `SampleRecipes.xcassets` rather than thousands of disconnected String
Catalog entries.

The locale-aware sample manifest maps one logical sample recipe to explicit
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
asset-localization wells do not cover data sets. Every recipe data-asset and
payload name includes its complete locale identifier, including `-en-US`; the
catalog has no implicit base-language recipe. Image, color, and symbol assets
may use the asset catalog's language and region variations when their visual
content genuinely needs adaptation. Shared food photography should normally
remain shared; localized accessibility descriptions travel with the recipe
document.

Authored content language is durable recipe metadata, not an inference from the
current application locale. `RecipeRevision.contentLanguage` stores an optional
canonical BCP 47 tag and carries it through drafts, sample documents, Schema.org
`inLanguage` import mapping, and persistence. Because the app is still a
single-user development toy, this pre-release change updates V1 directly and
requires deleting development stores; no fictional migration path is retained.

## Sample onboarding and future delivery

The current release ships the localized sample pack inside the application, but
first startup does not install it implicitly. A separate durable preference
records `undecided`, `accepted`, or `declined` so onboarding is not repeated.
Acceptance invokes the installer once; it is not standing permission to restore
content later. Settings compares the current localized pack's stable recipe
UUIDs with stored recipes and reports none, partial, or complete presence. An
explicit installation then skips existing samples and adds only missing UUIDs,
without deleting user content.

The in-app loading and decision states are deliberately independent of the
static operating-system launch screen. When the deployment floor reaches xOS
27, the bundled provider may be replaced by localized Managed Background Asset
packs. The stored response remains useful onboarding history, while current
pack presence and a new explicit installation request govern future transfers.
Deleting samples must not cause an accepted response to download or reinsert
them automatically.

## Persistence behavior

Bootstrap creates an empty Kitchen. After acceptance, installation chooses a
localized sample variant and atomically adds only stable recipe identities that
are not already present. Once stored, that recipe is ordinary local content. A
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

Localization proof remains layered and deterministic:

- select `en`, `fr-CA`, and `es-MX` explicitly rather than inheriting the host;
- exercise every pluralized formatter with representative values for each
  locale;
- verify locale fallback and sample-manifest selection as pure operations;
- decode every localized recipe asset and validate stable identity relationships;
- preserve source strings and numerical domain values across presentation
  locales; and
- keep UI smoke tests identifier-driven rather than asserting translated copy;
- launch the durable shell and Privacy display under every supported interface
  locale; and
- launch smoke coverage with doubled localized strings and forced right-to-left
  writing direction to expose basic layout assumptions.

These UI checks prove reachability and structural survival, not linguistic
quality or pixel-perfect layout. Native review of the three locales, long text,
right-to-left direction, Dynamic Type, and assistive technologies remains part
of release hardening. The identifier-driven smoke boundary from
<doc:0007-business-logic-coverage-and-ui-smoke-tests> still applies: a localized
screen is not a reason to encode its provisional visual hierarchy in tests.
