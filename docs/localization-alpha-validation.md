# Alpha translation validation

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

On 2026-09-07 the maintainer waived device and layout checks for the alpha
translation work in #118–#120. The interface already uses native, resizable
SwiftUI presentation. Do not run a Mac/iPhone/iPad layout matrix solely to accept
these translations, or claim that the waiver is a completed visual review.

Catalog completeness, generated resources, placeholders, authored Recipe
structure and provenance, distinct stable identities, numerical meaning,
fallback, and locale-sensitive formatting remain required checks. Hosted
resource tests may run through Xcode using the `KitchenMemoryCloud` test plan
(which contains no UI tests) on My Mac. Keep the ordinary multilingual smoke
inventory current for future runs. This waiver does not broaden UI automation,
change #132's separate accessibility decisions, or establish beta/release visual
or linguistic acceptance.

## British English

`en-GB` has explicit interface and metadata entries, Credits, and all three
sample Recipe variants. Shared English wording is deliberate authored content,
not a missing localization. Organisation and synchronisation use British
spelling; Recipe wording uses minced beef, frying pan, hob, tins, savoury,
chilli flakes, and tomato purée where appropriate. Product names, source URLs,
authors, and original regional dish identities are retained.

US volume measures remain explicitly identified as US measures. Rice-cooker
cups retain the source meaning; weights, ingredient quantities, cooking times,
and temperatures are not converted or inferred. Each British Recipe and its
Revision and child records have distinct fixed identities within the original
sample family. Existing installed Recipes stay in their authored language.

Food photographs, application artwork, and symbols are shared intentionally.
Their accessible Recipe descriptions are authored per locale. `en-GB` resolves
exactly; an unsupported English region uses the first English sample variant
(currently en-US), and an unsupported language or empty preference list uses
that development variant. Tests pin these fallback choices.
