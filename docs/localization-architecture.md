# Localization and recipe resources

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: 0.3 translation seam contract (#117)
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
counts belong in String Catalogs in the `KitchenMemory/` application layer.
The native multiplatform target compiles those catalogs into both iOS and Mac
products. The catalogs carry the plural
variants required by each supported locale. As interface copy stabilizes,
ambiguous terms, placeholders, tone, and screen context receive translator
comments at their extraction sites. Views and presentation adapters request
localized values; KitchenKit's Domain, Import, Persistence, and Logic
responsibilities do not look up interface strings.

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

KitchenKit continues to return semantic values such as quantities,
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
`inLanguage` import mapping, and persistence. The original pre-release introduction landed in V1. That historical schema is
now frozen; adding a locale changes authored resources, not historical schema
definitions or existing Recipe Revisions.

## Sample onboarding and future delivery

The [reversible sample-pack setting](sample-pack.md) now owns explicit installation
and removal, organization identities, and observed-versus-requested state. The
following onboarding and language boundaries remain in force.

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
- keep the top-level UI suite independent of translated copy.

The catalog and presentation tests own deterministic localization proof. Native
review of the three locales, doubled and long text, right-to-left direction,
Dynamic Type, and assistive technologies remains part of release hardening.
The constrained automation boundary from
[ADR 0007](adr/0007-business-logic-coverage-and-ui-smoke-tests.md) still applies:
localization is not a reason to restore interaction-heavy scripts or encode a
provisional visual hierarchy in UI tests.

## Current alpha additions

British English (`en-GB`), German (`de-DE`), and Italian (`it-IT`) are explicit
supported locales alongside en-US, es-MX, and fr-CA. See [alpha translation validation](localization-alpha-validation.md)
for the regional content choices and the maintainer's device/layout-check waiver
for #118–#120. The following checks apply to all currently supported locales.

## 0.3 verification contract

`Configurations/LocalizationContract.json` is the source-language and supported-
locale inventory for repository verification. Its explicit `retainedKeys` map
records why four historical keys remain despite having no current interface
reference. Retention preserves earlier meanings; it is not a baseline for new
unused keys. Reusing a retained key requires removing its retention entry.

Run `ruby Tools/check-localization.rb` during ordinary verification. Xcode Cloud's
post-clone script runs it and its synthetic contract tests before the build. It
checks both catalogs for locale completeness, reviewed nonempty values, matching
variant and named-placeholder structure, intentional manual extraction state,
translator context, and generated-symbol collisions. Named object and integer
operands (`@`, `d`, `lld`) are supported; other printf conversions are rejected
until their parsing and compiled formatter tests are deliberately extended. It also rejects new orphan
interface keys, direct literal UI copy, immediately preceding literal bindings,
and raw localization-key lookups. The two exact nonprose exceptions are an
example HTTPS URL and an accessibility-hidden fraction separator, each with a
source path and reason. Historical documents and authored Recipe assets are not
scanned as interface Swift code.

This source guard recognizes a bounded set of SwiftUI label entry points. It is
not whole-program data-flow analysis: dynamically assembled copy, new custom
label APIs, and complex interpolation need source review. Xcode's compiler still
owns generated-symbol availability and operand type checking; hosted tests own
compiled catalog, bundle metadata, localized Credits, and authored asset checks.
Neither a source scan nor a green build establishes linguistic quality.

`SamplePackLocalizationContractTests` walks all authored variants of each
sample family. It checks locale membership, structural shape, source kind, URL and
author provenance, nonempty wording, stable reloading, and distinct Recipe,
Revision and child identities. A translation retains the original family and
structure while owning distinct immutable identities; a later correction must
not mutate an already-published identity's payload. The tests also exercise
ordinary localized Sample Pack names and preservation of user spelling across
refresh. Unfiled and Untagged remain generated presentation labels: neither is
a reserved name nor a stored system Folder/Tag identity. Locale-aware Folder and
Tag tests compare ordering with Foundation's collation without changing stored
names.

The six French and Spanish assets now carry revision 2 baselines. Hotdish and
fried rice restore omitted ingredients, steps, equipment, media, and provenance;
Red Engine restores its equipment. Numerical quantities, optionality, and source
uncertainty follow the complete authored source rather than inventing simplified
recipes. Recipe identities and manifest families stay stable, while corrected
Revisions and their child records receive fresh identities. Existing installed
Recipes are not upgraded or replaced. Sample removal conservatively preserves
an older baseline whose payload differs from the current bundled baseline, just
as it preserves other changed sample content.

The native shell smoke suite includes en-US, en-GB, es-MX, fr-CA, de-DE, and it-IT with doubled strings
and forced right-to-left direction. Run it through Xcode on an iPhone simulator
(compact) and My Mac (regular). It checks named, reachable shell and Settings
structure without asserting translated copy, scrolling, or feature workflows.
The existing minimal Recipe-only fixture keeps those tests independent of sample
pack organization. Representative formatter tests exercise zero/singular/plural/
large counts, durations, source-capture dates, and preserved authored measurement
units with explicit locales and a fixed captured date. Structural smoke survival
is not a clipping, typography, or assistive-technology sign-off; visual and native-
speaker review remain release acceptance work.

Apple documents the doubled-string and right-to-left launch controls in
[Testing Your Internationalized App](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/TestingYourInternationalApp/TestingYourInternationalApp.html),
and the current workflow in
[Preparing your interface for localization](https://developer.apple.com/documentation/xcode/preparing-your-interface-for-localization).
Follow [String Catalog guidance](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
when adding locale-specific variants; extend the inventory, compiled resource
checks and authored family variants together. Issues #118–#120 own the additional
locales and their authored content.
