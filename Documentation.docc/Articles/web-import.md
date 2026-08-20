# Web recipe import

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


## Interoperability target

The first importer targets Schema.org [`Recipe`](https://schema.org/Recipe)
embedded as JSON-LD. It is widely used by recipe publishers and exposes the
fields needed for a strong baseline: title, author, images, yield, times,
ingredients, nutrition metadata, and sectioned instructions.

Schema.org permits `recipeIngredient` as text or more structured values and
permits `recipeInstructions` as text, an ordered list, `HowToStep`, or nested
`HowToSection`. Import code must accept that variability instead of assuming the
single shape shown in search-engine examples.

Microdata, HTML heuristics, and site-specific adapters are later fallbacks. They
must feed the same normalized import pipeline.

## Pipeline

```text
URL
 → fetch document
 → discover JSON-LD blocks
 → expand @graph and locate Recipe candidates
 → select recipe
 → capture immutable source snapshot
 → map recipe metadata
 → normalize instruction hierarchy
 → parse ingredient lines provisionally
 → validate without rejecting partial data
 → present import review
 → save recipe
```

Network fetching lives behind a small interface so the same pipeline can later
consume a Safari share extension or saved HTML file and already consumes test
fixtures without knowing where the document came from.

`URLSessionRecipeDocumentLoader` now provides that interface for person-entered
URLs. It uses a fresh ephemeral session, accepts only HTTPS, carries no
cookies or URL cache, limits redirects and total resource time, and streams at
most 2 MiB into memory. It accepts HTML content only and rejects credentials,
literal IP addresses, local-looking names, and nonstandard ports. URLSession
owns DNS, connection setup, redirects, response streaming, and cancellation
under one resource deadline; no separate blocking resolver can outlive the
import. The same structural URL policy is applied to every redirect. Loading
cancels when the import surface closes. Each accepted redirect becomes a fresh,
bodyless `GET` carrying only Kitchen Memory's `Accept` and `User-Agent` headers;
Foundation-proposed methods, bodies, cookies, authorization, and arbitrary
headers do not cross that boundary. Parsing then applies independent budgets for
JSON-LD blocks, nesting,
structural tokens, discovered objects, candidates, interpreted field lengths,
ingredients, and instruction items. Structural and item ceilings are enforced
while traversing. An aggregate UTF-8 ceiling bounds the candidate models retained
for review, while the direct-input ceiling and item counts separately bound
transient construction memory.

## Deterministic import boundary

`KitchenMemoryImport` implements the pipeline from captured HTML or JSON-LD
through reviewable candidates. `SchemaOrgRecipeImporter` has no networking or
persistence dependency. Its result retains a source-faithful UTF-8 transcription
of the containing JSON-LD block plus the selected candidate coordinates, so
later parsing improvements can be applied without fetching the page again or
relying on today's interpretation.

Missing titles and malformed sibling blocks are diagnostics rather than reasons
to discard other meaningful recipe content. Candidate selection, URL fetching,
person-facing review, and saving remain responsibilities of the application
layer rather than the deterministic parser.

When a reviewed candidate is saved, the revision retains one bounded JSON-LD
block and the selected candidate coordinates. It does not persist the full HTML
document, download referenced images, or duplicate the normalized candidate
payload. Existing stores use the same optional encoded source field, so this
addition remains compatible with the released V1 SwiftData schema.

The transcription preserves the decoded JSON text's spelling, whitespace, key
order, unknown properties, and Unicode scalar content. It does not preserve the
HTTP response's original byte encoding, byte-order mark, byte offsets, or the
surrounding HTML. Exact network-byte provenance would require retaining the
bounded response plus encoding metadata; this release deliberately keeps only
the smaller recipe metadata block. The payload remains untrusted opaque data:
Kitchen Memory must not execute it or insert it into an HTML surface.

`blockIndex` and `objectIndex` describe the traversal performed by the importer
that created the capture. They are not permanent JSON Pointers, and a later
importer may discover candidates differently as Schema.org support improves.

## Candidate discovery

A page may contain:

- one `Recipe` object;
- multiple JSON-LD script blocks;
- a `Recipe` nested inside `@graph`;
- multiple recipes or recipe variants;
- malformed JSON-LD alongside a valid block;
- an `ItemList` that references recipes rather than containing the full recipe.

Discovery should collect all usable candidates. If there is exactly one clear
candidate, select it automatically. Otherwise, the import result should ask the
user which recipe to save.

## Field mapping

| Schema.org | Internal concept | Notes |
| --- | --- | --- |
| `name` | `Recipe.name` | Required for a clean import; user may supply if absent |
| `description` | `Recipe.description` | Strip unsafe markup, preserve text |
| `author` | `Recipe.authorName` | Accept person, organization, text, or arrays |
| `url`, `mainEntityOfPage` | `RecipeSource.canonicalURL` | Resolve relative URLs; retain only structurally public HTTP(S) metadata; revalidate before activation |
| `datePublished` | Source metadata | Not a local creation date |
| `image` | `Recipe.images` | Accept URL, object, or array |
| `prepTime` | `Recipe.prepDuration` | ISO 8601 duration |
| `cookTime` | `Recipe.cookDuration` | ISO 8601 duration |
| `totalTime` | `Recipe.totalDuration` | Preserve independently |
| `recipeYield` | `Recipe.yield` | Text, number, or quantitative value |
| `recipeCuisine` | `Recipe.cuisines` | Text or array |
| `recipeCategory` | `Recipe.categories` | Text or array |
| `keywords` | `Recipe.keywords` | Comma-separated text or array |
| `recipeIngredient` | ingredient rows | Always retain each original value |
| `recipeInstructions` | sections and steps | Normalize all legal shapes |
| `nutrition` | deferred source metadata | Preserve raw; do not calculate yet |
| `suitableForDiet` | deferred source metadata | Preserve raw; map later |

Unknown properties remain available in the source snapshot. Import does not need
to model every Schema.org property before it can be lossless.

## Ingredient interpretation

Web publishers overwhelmingly provide ingredient display strings even though
Schema.org permits some structured forms. Ingredient parsing is therefore
provisional.

For each line:

1. Save the untouched value as `originalText`.
2. Detect and remove a section heading only when evidence is strong.
3. Parse a leading quantity expression.
4. Parse a unit or container phrase.
5. Separate the likely ingredient name from preparation/modifier text.
6. Attempt to resolve the name to an existing kitchen ingredient.
7. Record parse state and confidence for review.

Examples that must remain valid:

```text
2 cups all-purpose flour
1½–2 tablespoons olive oil
salt and freshly ground black pepper, to taste
one 28-ounce can whole peeled tomatoes
3 eggs, divided
a generous handful of basil
juice of 1 lemon
```

The first importer need not parse all of these perfectly. It must preserve all of
them and clearly distinguish interpreted fields from source text.

## Import review

The review experience is a core product surface, not an error dialog.

- Show the recipe as it will be saved.
- Emphasize only low-confidence or incomplete fields.
- Distinguish machine-parsed ingredients from person-reviewed ingredients.
- Surface malformed sibling blocks, referenced-but-undownloaded images, and
  taxonomy that is preserved even when the current editor cannot change it.
- Allow bulk acceptance of high-confidence rows.
- Let the user edit its structure, choose the original line, or supply an
  explicit custom presentation.
- Never require every ingredient to resolve to a canonical ingredient.
- Retain the source link and attribution visibly.

An import with a good title, intact ingredient lines, and usable instructions is
successful even if every ingredient remains unparsed.

## Security and privacy

- Treat imported HTML and JSON-LD as untrusted input.
- Never execute page scripts.
- Sanitize markup before display.
- Apply response-size and redirect limits.
- Bound post-download expansion as well as transport bytes. JSON nesting,
  collections, candidates, and interpreted strings need limits before model
  allocation.
- Restrict URL schemes, ports, literal address syntax, resolved addresses, and
  every redirect so a recipe import cannot intentionally reach local or private
  services.
- Avoid downloading all media during the initial parse.
- Make external image loading visible and controllable for privacy.

### Destination-validation boundary

String inspection cannot prove that a hostname resolves only to public
addresses. Kitchen Memory rejects literal and ambiguous numeric addresses, but
deliberately leaves hostname resolution to URLSession. A separate `getaddrinfo`
preflight cannot be cancelled reliably, and URLSession cannot pin its later TLS
connection to the answer that preflight inspected. Such a check would therefore
add a hang and time-of-check/time-of-use boundary without creating a dependable
security boundary.

Consequently, a dotted hostname can still resolve to a private address, and the
system's configured proxy, VPN, trusted roots, and managed routing remain part of
the device trust boundary. HTTPS certificate validation, no cookies, a
person-initiated `GET`, a small response limit, one finite URLSession-owned
deadline, and no script execution independently limit the consequence. That is
a deliberate availability-oriented policy for a recipe importer, not a claim
to provide a general SSRF sandbox.

## Test strategy

Maintain checked-in fixtures rather than depending on live websites in tests.
Each fixture should include the source HTML, expected discovered candidates, and
an expected normalized import result.

Initial fixture families:

- Minimal flat JSON-LD recipe.
- Recipe inside `@graph`.
- Multiple JSON-LD blocks.
- Multiple recipe candidates.
- String instructions.
- `HowToStep` instructions.
- Nested `HowToSection` instructions.
- Text and `PropertyValue` ingredients.
- Relative image and canonical URLs.
- Malformed optional fields.
- Fractions, ranges, Unicode fractions, containers, and “to taste.”
- A page with malicious markup in text fields.

Live-site smoke tests may be run manually, but the product must not depend on the
continued markup behavior of particular publishers.

## Non-goals for the first importer

- Executing JavaScript to reveal hidden structured data.
- Circumventing paywalls, authentication, or bot protection.
- Extracting the surrounding article prose.
- Site-specific CSS selectors.
- AI interpretation.
- Claiming perfect semantic ingredient parsing.
