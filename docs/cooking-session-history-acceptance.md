# Cooking Session history: implementation and acceptance

<!-- Kitchen Memory; Copyright © 2026 the Kitchen Memory contributors; SPDX-License-Identifier: MIT -->

[Documentation map](README.md) · [Accepted interface](cooking-session-interface.md)

**Status:** Implementation merged; native walkthrough acceptance pending. Evidence reconciled 2026-10-07.

## Current state

Issue [#251](https://github.com/ctwelve/KitchenMemory/issues/251) remains open. Its body still says implementation and native acceptance are pending. The implementation was merged in [PR #257](https://github.com/ctwelve/KitchenMemory/pull/257) on 2026-10-06. PR #257 records the complete lifecycle history, retained routes and per-history list anchors, observational Finished Session presentation, and readable continuation lineage. The issue’s remaining acceptance is the native walkthrough for repeated-session distinction, group reachability, compact/wide layouts, accessibility text sizes, keyboard, and VoiceOver.

The implementation commits [`ef13bee`](https://github.com/ctwelve/KitchenMemory/commit/ef13bee) and [`0024a5e`](https://github.com/ctwelve/KitchenMemory/commit/0024a5e) were merged at [`07d8213`](https://github.com/ctwelve/KitchenMemory/commit/07d8213). They are ancestors of the current stack; this reconciliation does not duplicate their runtime changes.

The implementation and tests are already present in the current history surface:

- `CookingSessionHistoryView` renders lifecycle groups and history rows with the Recipe title, start date/time, and optional Outcome; `CookingSessionLineageView` presents retained predecessor/continuation rows.
- `CookingSessionHistoryPresentationTests` cover untruncated history, lifecycle ordering, provenance filtering, missing/deleted Recipes, Finished observation, and continuation immutability.
- `CookingSessionHistoryNavigationTests` cover all-history and Recipe-history routes, direct Recipe return, Finish/Continue/Back, list anchors, and delayed Finish/Continue acceptance after navigating away.
- PR #257 records signed hosted/native test evidence. **Current coordinator rerun:** the integrated signed Mac test run is executing at scaling head `807dde0`. Record its completed count before crediting this rerun; native walkthrough rows below remain unexercised.

Automated coverage does not establish native reachability, focus order, legibility, or VoiceOver behavior. Those results must be recorded from the walkthrough below; do not infer them from the merged PR or test count.

## Manual acceptance matrix

Record device/model, OS version, build, interface locale, text size, input method, and outcome for each applicable row. Mark unexercised rows `Not run`; include a short observation for failures. Use isolated sample/test data, not a person’s retained Kitchen data.

| Issue #251 acceptance | Native walkthrough | Expected observation | Result / evidence |
| --- | --- | --- | --- |
| Repeated cooks are distinguishable | In one Recipe, create or open multiple Sessions with the same Recipe title and different start times; include recorded Outcomes where available. Inspect Active, Stopped, and Finished rows. | Each row exposes its lifecycle context and start date/time; the optional Outcome distinguishes cooks when present. No custom Session name is required. | Not run — |
| Every retained group and older cook stays reachable | Open overall history with more than five unfinished Sessions, then open Recipe-specific history. Navigate to older rows in Active, Stopped, and Finished. | All groups and all retained Sessions remain reachable; the recent/current shortcut does not replace the full history route. Recipe history filters by retained provenance. | Not run — |
| Missing/deleted source Recipe does not block retained history | In isolated data, open a Session whose source Recipe is absent or deleted; inspect its details and continue it. | The self-contained snapshot remains readable. Continuation keeps predecessor lineage and does not require the source Recipe to exist. | Not run — |
| Finished Session remains observational | Open a Finished row and inspect snapshot, scale, progress, notes, and Outcome. Try available controls, then use Back and Continue. | Retained evidence is readable; active-only prompts and mutation controls are absent; Back returns to the originating history or direct Recipe route; Continue starts a new Active Session. | Not run — |
| History scope and list position survive Finish/Continue/Back | From overall and Recipe-specific histories, choose a row away from the top, Finish it, Continue it, then leave/back. Repeat direct entry from a Recipe. | Return route preserves the originating scope and saved list anchor. Direct Recipe entry retains its ordinary return route. | Not run — |
| Compact and wide layouts keep history understandable | Inspect narrow/compact and wide windows or devices, including accessibility text sizes. Visit each lifecycle group and a repeated-title pair. | Group headings and identifying row details remain legible and reachable without clipping or losing the only route to a row. | Not run — |
| Keyboard access | On Mac, move focus through history headings and rows, open a Session, use Back, and Continue. | Focus reaches each group and row in a sensible order; activation and return remain possible without a pointer. | Not run — |
| VoiceOver access | On Mac and iPhone, navigate history headings and rows, open a Session, and reach Back/Continue. Repeat with accessibility text sizes. | Group structure is announced; a history row exposes enough information to distinguish same-title Sessions, including start date/time and Outcome when present; destination controls are named and reachable. | Not run — |
| Delayed Finish/Continue | The merged hosted regression already exercises a controlled failure followed by retry after navigation away. If a native harness can inject the same transient failure, repeat on-device; otherwise record this row as covered by hosted regression only. | Retry completes the submitted action and restores the submitting history scope and anchor. No new lifecycle transition or duplicate continuation is introduced by navigation. | Hosted regression in PR #257; native injection not yet recorded — |

