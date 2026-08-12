<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# Web recipe import

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

Network fetching should eventually live behind a small interface so the same
pipeline can consume a Safari share extension, a saved HTML file, or test
fixtures without knowing where the document came from.

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
| `url`, `mainEntityOfPage` | `RecipeSource.canonicalURL` | Resolve relative URLs |
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
- Restrict URL schemes and defend against requests to local/private services if
  fetching occurs on a server.
- Avoid downloading all media during the initial parse.
- Make external image loading visible and controllable for privacy.

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
