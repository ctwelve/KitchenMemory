# 0.2 roadmap — Cooking sessions

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Accepted planning baseline
- Planned: 2026-08-25
- Target release: 0.2.0

Version 0.2 makes one performance of a recipe a first-class, durable product
concept without confusing cooking reality with the maintained recipe. The
release is complete when a person can start from a particular recipe revision
and working yield, make lightweight progress, record what differed, recover
after interruption, finish or abandon explicitly, and later understand what
happened.

The complete loop is:

```text
Recipe revision and working yield
              ↓
        Start cooking
              ↓
 Ingredient and step progress
              ↓
     Notes and deviations
              ↓
 Resume after interruption or sync
              ↓
       Finish or abandon
              ↓
     Intelligible history
```

The slices below are potential releases under the versioned-slice discipline
in <doc:release-engineering>. Advancing a working version does not publish it;
the root `RELEASE` marker changes only for a deliberately submitted release.

## Prelude — 0.1.2 alpha polish

Version 0.1.2 is the bounded polish pass immediately before 0.2 feature work.
It collects coherent corrections against the public-alpha baseline without
introducing a cooking-session aggregate or adding speculative 0.2
infrastructure. Its bounded additive V2 persistence schema records recipe
deletion intent and observed restoration so a long-disconnected device can
rejoin private synchronization without silently reviving deleted recipes.

The pass includes repository-wide product and engineering polish, accurate
documentation, focused sample-content corrections, and a device-local iCloud
sync opt-out with explicit long-disconnected reconnection consent. It is
complete when its accepted fixes pass the existing 0.1 behavior, privacy,
localization, build, and test contracts.

## Slice 11 — 0.1.3 session foundation

Deliver the smallest durable cooking session from end to end:

- Settle historical recipe-reference, session authority, progress, and
  synchronization policies before freezing persistence records.
- Add plain domain values and lifecycle rules for active, finished, and
  abandoned sessions.
- Start from a specific recipe revision and reading-only working scale.
- Make a session durable only after an explicit start or other meaningful
  activity; viewing a recipe does not create history.
- Persist, relaunch, resume, finish, and abandon through Logic and repository
  boundaries rather than directly through SwiftUI or SwiftData.
- Introduce an immutable SwiftData V3 schema and additive private CloudKit
  record types without rewriting existing recipe content.
- Add one deliberately simple start-or-resume presentation on each supported
  native product.
- Exhaustively test domain rules, Logic operations, repository mapping, and
  V2-to-V3 migration.

The initial historical-reference recommendation is a hybrid: keep stable
`Kitchen.ID`, `Recipe.ID`, and `RecipeRevision.ID` references while capturing a
self-contained, session-relevant snapshot at start. The snapshot keeps history
meaningful if the maintained recipe changes, is deleted, is temporarily absent
during synchronization, or later uses a different persistence representation.
The slice must validate this recommendation before making it a schema contract.

The synchronization prototype must compare append-only session activity with
mutable per-target progress records. The chosen representation must preserve
offline intent and converge deterministically across one person's devices
without claiming multi-person live collaboration.

### Exit criteria

- Starting a session does not mutate its recipe revision.
- An active session survives process termination and ordinary relaunch.
- Finish and abandon are explicit terminal actions.
- V1 stores open through the supported V2 migration path with recipes intact.
- Development CloudKit receives only reviewed additive schema changes.

## Slice 12 — 0.1.4 cooking progress

Make the active session useful while hands and attention are occupied:

- Account for ingredient lines without interpreting a checkmark as precise
  pantry consumption.
- Complete or skip instruction steps and move backward or forward freely.
- Preserve working yield, scaled ingredient presentation, and base-recipe
  context without creating a recipe revision.
- Save progress automatically and recover it after interruption.
- Resume the same personal session after private synchronization.
- Target progress through stable snapshot row identities, not displayed text or
  array position.
- Provide accessible state, focus, keyboard, and assistive-technology semantics
  without coupling smoke tests to localized copy.

This slice is the first representative native 0.2 interaction. iPhone should
favor glanceable, one-handed cooking; iPad should favor comfortable full-recipe
reading; Mac should remain useful and keyboard operable. The rest of the 0.1
library, import, and editor shell may remain shared while this representative
surface teaches the project where presentation genuinely benefits from
platform ownership.

### Exit criteria

- Ingredient and step progress persists without changing canonical content.
- Relaunch and supported personal-device handoff retain intelligible state.
- Progress remains attached to the intended snapshot row after later recipe
  editing.
- Durable behavior remains exhaustively covered while UI automation stays a
  small identifier-driven smoke suite.

## Slice 13 — 0.1.5 cooking reality

Make deviations extraordinarily cheap to capture and safe to ignore:

- Add a note to the whole session, an ingredient row, or an instruction step.
- Record basic unavailable, substituted, amount-changed, omitted, added,
  step-skipped, step-changed, timing-changed, and free-form observations.
- Optionally record a simple outcome: great, okay, or unsuccessful.
- Keep every note and deviation session-owned until a person deliberately
  promotes it through a later reviewed workflow.
- Prefer rapid, progressive entry over forms that require false precision.
- Preserve authored wording and unknown details rather than manufacturing
  structured values.

Structured inventory deductions, media, repeated-deviation intelligence, and
recipe promotion are not prerequisites for this slice.

### Exit criteria

- A useful observation can be recorded with minimal interruption.
- Targets remain intelligible against the captured session snapshot.
- No progress, deviation, or outcome silently edits a recipe.
- Synchronization does not drop independently recorded notes or deviations.

## Slice 14 — 0.2.0 history and closure

Complete the release promise and harden the whole session loop:

- List active and completed sessions in the context of their recipe.
- Reopen a historical session using its captured representation.
- Distinguish active, finished, and abandoned sessions clearly.
- Resolve convergence for progress, notes, and competing terminal actions.
- Exercise offline start, offline activity, relaunch, later synchronization,
  deletion, and recovery behavior.
- Complete `en-US`, `fr-CA`, and `es-MX` interface coverage for stable session
  surfaces without translating stored authored content.
- Perform the stable cooking-flow accessibility walkthrough on supported native
  products.
- Update architecture, privacy, migration, synchronization, and recovery
  documentation to describe implemented behavior rather than aspirations.

### Release acceptance walkthrough

1. Start a scaled cook from a known immutable recipe revision.
2. Record ingredient and instruction progress.
3. Add a substitution or observation.
4. Terminate and relaunch the application.
5. Resume without losing or reassigning activity.
6. Exercise supported continuation on another personal device.
7. Finish the session.
8. Confirm that the maintained recipe is unchanged.
9. Reopen the completed history and understand what was cooked.

The slice is feature-complete only when this loop passes with bounded private
diagnostics and no false synchronization-success claims.

## 0.2 release engineering

Release engineering follows the accepted 0.2.0 feature state and is not another
numbered product slice. It records immutable-schema review and production
promotion, the device and recovery matrix, privacy and localization evidence,
production builds, archive and signing results, distribution decisions, and an
immutable `release/0.2.0` tag if the version is deliberately submitted.

Physical-device iPhone and iPad acceptance belongs to the feature evidence.
Public TestFlight or App Store distribution remains a separate product and
release decision; 0.2 does not silently acquire that scope merely because its
cooking interaction is mobile-first.

## Explicitly outside 0.2

- Planned cooks, meal planning, shopping lists, and pantry deductions.
- Timers and live activities.
- Session photographs, video, and other media capture.
- Promotion of deviations into recipe revisions or named variants.
- Repeated-deviation suggestions or inferred recipe corrections.
- Household sharing and multi-person live cooking.
- A wholesale redesign of every 0.1 library, import, and editor screen.
- TestFlight or App Store publication without a separate distribution decision.

These boundaries preserve the distinction in <doc:product-doctrine> between the
published source, maintained recipe, planned cook, cooking session, and pantry
observation. They also keep the 0.2 release small enough to prove that cooking
history is valuable before later planning, pantry, media, and collaboration
work depends on it.
