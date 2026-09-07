# Alpha shell and Cooking Session accessibility evidence

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

This is the bounded alpha validation for
[Issue 123](https://github.com/ctwelve/KitchenMemory/issues/123), under
[the accepted accessibility policy](accessibility-engineering.md). It records
source inspection and an agent-operated ordinary-use Mac walkthrough, not human
assistive-technology acceptance or a stable beta interface.

## Candidate and reused native evidence

Checkout: `3c469c5527bfbe723add70f48d0edb20d11df03e`, version 0.2.16.
Application and test inputs are unchanged from
`16072e8b0fb006ea71c7c21c2f860da60cff74a1`: the intervening diff contains only
`docs/README.md` and the
[Recipe Library evidence record](accessibility-alpha-library-evidence.md).
This slice also changes documentation only.

Reuse the Xcode-managed native result recorded there: **185 passed**, comprising
179 hosted application tests and six existing UI tests, with zero failures,
skips, expected failures, or tests not run. Environment remains Xcode 26.6
(17F113), macOS 26.6.2 (25G83), My Mac, KitchenMemory scheme/default plan,
Testing configuration. The summary generated at 2026-09-07T20:01:00Z has artifact
identifier `5422D6F5-5B42-4DE1-8C4E-9B1E9D9BBD64`.

That run includes startup-failure recovery, Settings, Recovery navigation,
ordinary destinations, organization, and the existing localized shell smoke.
Hosted tests separately cover startup retries and Cooking Session lifecycle,
progress, entries, history, and recovery behavior. No repeated native run or new
standalone framework coverage result is claimed by this evidence-only slice.

## Source inspection

| Surface | Inspected implementation | Bounded observation |
| --- | --- | --- |
| Startup | `KitchenStartupView` | Named loading progress, hidden decorative image, explanatory unavailable state, and native Try Again button. |
| Navigation | `RecipeLibrarySidebar`, `RecipeLibraryCommands` | Native named destinations, Recipe/Session discovery, and menu commands; unavailable recovery is not fabricated for a clean Kitchen. |
| Cooking | `CookingSessionView`, `CookingSessionProgressView` | Named lifecycle controls, labeled progress actions and state values, section structure, and an explicit return path. |
| History and recovery | `CookingSessionHistoryView`, `CookingSessionRecoveryView` | Named headings and explicit open/retry/restore actions; destructive and recovery intentions retain their existing confirmation boundaries. |
| Settings | `KitchenSettingsView` | Named iCloud switch, explanatory state, sample-pack controls, and privacy entry point. |

These observations do not certify spoken coherence, focus order, or runtime
heading navigation. Business rules remain below the view layer, and no new
workflow-heavy UI script was added.

## Ordinary-use Mac walkthrough

On 2026-09-07, used the same Testing product in English (en-US), with
`--ui-testing --ui-testing-cloud-sync-disabled` and
`-ApplePersistenceIgnoreState YES`. The fixture uses in-memory persistence and
volatile drafts/preferences/Session presentation, without personal CloudKit.
As recorded for Issue 122, direct execution of this test product supplies its
`Contents/ReexportedBinaries` directory through `DYLD_FRAMEWORK_PATH`. This is
not an installation or signing check of a distributed product.

1. A fresh launch reached the named Recipe Library with bundled synthetic
   content and a readable Recipe detail.
2. Activated the named Start Cooking toolbar action. The Cooking destination
   exposed the Recipe title and Active state, named ingredient/step actions,
   Session notes, and Back to Recipes, Stop, Finish, and Delete actions.
3. Activated Stop. The visible Session state changed to Stopped, progress actions
   became disabled, and the named Resume action appeared.
4. Activated Resume. The Session returned to Active and Stop reappeared.
5. Command-comma opened Settings. The iCloud switch was named and off, with
   explanatory text; sample-pack and privacy surfaces were reachable. No settings
   or personal data were changed. Quit the disposable application.
6. Relaunched with the additional `--simulate-startup-failure` argument. The
   unavailable screen explained that the Library could not be prepared and
   exposed the named Try Again action. Activating it returned to the same
   actionable failure surface, as expected while failure injection remained
   enabled. This does not claim successful recovery from a real storage fault.
   Quit the fixture afterward.

The ordinary UI interactions were performed through native accessibility controls
and keyboard input. They are supporting alpha evidence, not a human VoiceOver
walkthrough or a substitute for the deterministic lifecycle tests.

## Result and remaining obligations

No core-path accessibility barrier was identified in this bounded scope. No
application, test, version, dependency, or SBOM change was warranted. The source
and native semantic suite remain intact. Cloud UI testing stays parked under
[Issue 155](https://github.com/ctwelve/KitchenMemory/issues/155).

This Mac-only slice did not exercise ordinary iOS use; an ordinary-use walkthrough
on iOS remains required if an alpha distributes that platform. Separately, the
comprehensive device/input matrix, VoiceOver focus/grouping/spoken behavior,
platform audits, accessibility text sizes, appearance/contrast/motion variations,
and extensive shipping-language layout checks remain
[beta work](https://github.com/ctwelve/KitchenMemory/issues/168) after the
comprehensive UI design pass. Deferred evidence is unverified, not a pass.

The release maintainer still accepts the actual candidate and distributed
platform scope. Relevant interface, platform, or toolchain changes reopen affected
checks. Raw logs, screenshots, private content, and local diagnostic paths are
not part of this retained record.
