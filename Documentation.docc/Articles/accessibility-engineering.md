# Accessibility engineering

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->


Accessibility is part of Kitchen Memory's UI contract, not a final decorative
pass. It also anchors the UI test harness: stable semantics are a more durable
way to find and verify views than assumptions about SwiftUI's private view
hierarchy.

This document records the design rules, test scope, platform differences, and
Xcode 26 behavior discovered while establishing that contract. The exceptions
below are intentionally specific to the observed toolchain. Reevaluate them
when Xcode, XCTest, SwiftUI, or the deployment targets change.

## Tested environment

The initial investigation used:

- Xcode 26.6, build 17F113;
- macOS 26.5.2 for local macOS UI tests;
- an iPhone 17 Pro simulator running iOS 26.5; and
- GitHub's `macos-26` hosted runner.

Toolchain behavior described as an Xcode false positive is evidence from this
environment, not a permanent claim about every Apple SDK.

## Governing principles

1. Prefer native SwiftUI semantics. Use `Text`, `Button`, `NavigationLink`,
   headings, semantic foreground styles, and normal Dynamic Type before adding
   custom accessibility modifiers.
2. Hide decorative imagery. An SF Symbol used only as a visual bullet or badge
   should not add noise to the spoken interface.
3. Add one semantic representation for one conceptual value. A metadata card
   should be announced as “Yield, Serves 8 generously,” not as an icon, a label,
   an unlabeled container, and a separate value.
4. Keep automation identity separate from visible text. Stable identifiers find
   the concept; separate assertions prove that its human-readable content is
   present.
5. Never assume macOS and iOS expose the same accessibility tree. Shared SwiftUI
   code can produce different element types and place static text in different
   XCTest properties.
6. Make exceptions narrower than the problem. Match the audit type, element
   type, identifier family, label state, geometry, and known system control
   whenever those facts are available.
7. Prefer comprehension over cleverness. A future maintainer should be able to
   explain why each modifier and each exception exists without reverse
   engineering the original failure.

## Semantic structure in the recipe UI

The recipe library and detail view expose these stable concepts:

| Identifier | Meaning |
| --- | --- |
| `recipe-library` | The recipe collection |
| `recipe-row-<UUID>` | A selectable recipe in the library |
| `recipe-detail` | The scrollable recipe reading surface |
| `recipe-title` | The recipe's level-one heading |
| `recipe-summary` | The recipe summary |
| `recipe-author` | The recipe author attribution |
| `recipe-metadata-<kind>` | One spoken metadata value, such as yield |
| `equipment-section` | The Equipment level-two heading |
| `ingredients-section` | The Ingredients level-two heading |
| `instructions-section` | The Instructions level-two heading |
| `ingredient-subsection-<UUID>` | An ingredient level-three heading |
| `instruction-subsection-<UUID>` | An instruction level-three heading |

Identifiers are not substitutes for accessible names. The read-flow UI test
finds an identifier and then independently verifies its expected text.

### Metadata cards

Metadata is visually composed from a decorative symbol, a short label, and a
value. SwiftUI's `accessibilityRepresentation` replaces that visual composition
with one native `Text` element:

```swift
.accessibilityRepresentation {
  Text("\(value.label), \(value.value)")
    .accessibilityIdentifier("recipe-metadata-\(value.label.lowercased())")
}
```

This is preferable to combining several synthesized accessibility nodes. It
gives VoiceOver one meaningful phrase and lets the replacement use a native
static-text role.

The visual text still uses SwiftUI's standard fonts. The metadata grid switches
to one flexible column at accessibility Dynamic Type sizes, preventing the
compact cards from forcing clipped text.

### Decorative icons and bullets

The symbol beside a metadata label is hidden because the spoken phrase already
contains the meaning. Bullet dots are also hidden. The adjacent recipe text is
left as native `Text`; do not combine an icon-and-text `HStack` merely to create
one element. On macOS, that combination becomes a role-less `Other` element and
causes an “Unknown role” audit failure.

### Semantic colors

Ordinary readable text uses SwiftUI semantic foreground styles. The summary
uses `.primary`; `.secondary` was slightly below the required contrast against
the warm app background in light mode. Branded accents continue to come from
the asset catalog.

This distinction is intentional:

- use semantic system colors for ordinary text that must adapt automatically;
- use named assets for branded hues and surfaces whose light and dark variants
  are part of the Kitchen Memory palette.

## XCTest platform differences

Native static text is not represented identically across platforms. iOS often
places spoken text in `XCUIElement.label`. macOS frequently leaves `label` empty
and exposes the same native text through `value`.

Tests therefore accept the native representation:

```swift
let spokenText = element.label.isEmpty
  ? element.value as? String
  : element.label
```

Do not “fix” a valid macOS static-text value by forcing every string into a
custom label. That can synthesize extra elements, erase the native role, or put
the identifier and description on different nodes.

Activation also differs: UI tests use `click()` on macOS and `tap()` on iOS.
The iOS recipe navigation helper retries once because hosted simulators can
acknowledge a first tap immediately after an appearance change without
completing the navigation transition.

## Automated audit scope

The UI tests run light- and dark-appearance semantic audits on each platform.
They request every XCTest accessibility audit type except contrast:

```swift
let auditTypes = XCUIAccessibilityAuditType.all.subtracting(.contrast)
```

The automated suite therefore continues to check element detection, hit
regions, sufficient descriptions, Dynamic Type, clipped text, traits, actions,
and parent-child relationships.

### Why app-wide contrast is excluded

Xcode 26 eagerly audits text below a macOS `ScrollView`'s visible frame. It then
samples unrelated onscreen pixels at stale coordinates. One observed equipment
line began at y=808 while the app window ended at y=807; Xcode reported its
contrast against a strip of the hero photograph. The same impossible failure
occurred in light and dark appearances.

The audit did identify one real problem before it became noisy: secondary
summary text against the warm light background. That text now uses `.primary`.

For the current development phase, an app-wide crawler's contrast signal does
not justify its false positives or runtime. Contrast remains a finish-polish
agenda item and should return as a deterministic palette specimen rather than
as a geometry-dependent whole-app audit.

The future contrast specimen should display every supported foreground/surface
pair in:

- light and dark appearance;
- normal and increased-contrast settings;
- representative normal and accessibility Dynamic Type sizes; and
- enabled, disabled, selected, and emphasized states where applicable.

It should test the named asset values directly or render known pairings on a
dedicated screen. It must not depend on scrolling content being mapped to stale
window coordinates.

## Known Xcode 26 audit artifacts

All exceptions live beside the audit handler in
`KitchenMemoryUITests/KitchenMemoryUITests.swift`. The comments there are the
executable version of this section.

### iOS metadata Dynamic Type

**Finding:** “Dynamic Type font sizes are partially unsupported.”

**Element:** the single `recipe-metadata-<kind>` accessibility replacement.

**Cause:** Xcode cannot trace the visual native `Text` fonts through
`accessibilityRepresentation`.

**Why the exception is bounded:** only `.dynamicType` findings whose identifier
begins with `recipe-metadata-` are accepted. The visual text uses unmodified
SwiftUI Dynamic Type, the grid changes layout at accessibility sizes, and the
read-flow test verifies the replacement's exact spoken phrase.

### macOS structural groups

**Finding:** “Element has no description.”

**Element:** an empty-labeled, non-hittable `Group` emitted by SwiftUI around
native text and layout.

**Cause:** XCTest audits structural layout groups as if each group needed its
own spoken name, even though VoiceOver reaches the native child elements.

**Guard:** the handler accepts only the sufficient-description audit type for
an empty-labeled, non-hittable `Group`. Hittable groups and other audit types
remain failures.

### macOS metadata grid-cell wrapper

**Finding:** “Element has no description” locally, and potentially
“Parent/Child mismatch” on a hosted runner.

**Element:** an unlabeled `Other` emitted by `LazyVGrid` around one fully
described `recipe-metadata-<kind>` child.

**Evidence:** the wrapper and child have identical frames. The child exposes the
expected spoken text in either `label` or `value`.

**Guard:** the handler requires exactly one matching metadata descendant, a
nonempty child description, and equal parent/child frames before accepting only
the two observed audit descriptions.

### macOS sidebar NavigationLink role

**Finding:** “Unknown role.”

**Element:** a labeled, hittable `Button` whose identifier begins with
`recipe-row-`.

**Cause:** SwiftUI's sidebar `NavigationLink` is exposed as an activatable
button, but Xcode 26 reports its role as unknown.

**Guard:** the exception requires the exact finding, button type, hittable
state, nonempty label, and recipe-row identifier family.

### macOS full-screen traffic-light child

**Finding:** “Parent/Child mismatch.”

**Element:** a 14×14 private `Group` nested inside AppKit's green window
traffic-light button.

**Evidence:** the parent button is identified by XCTest as
`_XCUI:FullScreenWindow`; the group is system-owned and outside the SwiftUI
content hierarchy.

**Guard:** before an audit, the test resolves that exact button's frame. It
accepts only an unlabeled, unidentified `Group` contained by that frame.

### macOS injected Touch Bar

**Finding:** “Element has no description.”

**Element:** an empty, unidentified `TouchBar` element. The audit attachment
screenshots the macOS menu bar rather than application-controlled Touch Bar
content.

**Guard:** only the sufficient-description audit type for an empty-label,
empty-identifier `TouchBar` is accepted. Kitchen Memory defines no Touch Bar
content.

## Local UI-test signing

Local macOS UI tests do not require a paid Apple Developer account. They do
require Xcode to assemble and sign the generated runner normally.

Use the full Xcode developer directory:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -project KitchenMemory.xcodeproj \
  -scheme KitchenMemory \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -only-testing:KitchenMemoryUITests
```

Do **not** pass `CODE_SIGNING_ALLOWED=NO` when executing macOS UI tests locally.
That flag is appropriate for the clean GitHub CI runner, but it prevented local
Xcode from re-signing the assembled test runner after adding its plug-ins and
frameworks.

The resulting broken local bundle produced the alarming “damaged” or “move to
Trash” behavior. Inspection established that:

- the bundle did not have a quarantine attribute;
- the copied runner executable still carried Apple's template signature;
- the assembled bundle failed strict verification because its resources no
  longer matched that template signature; and
- a normal local build used Xcode's `Sign to Run Locally` ad-hoc signature,
  sealed the assembled resources, passed strict code-signature verification,
  and executed the UI test successfully.

Gatekeeper may still reject an ad-hoc runner if it is opened directly. That is
expected. Launch UI tests through Xcode or `xcodebuild`; do not double-click the
generated runner application.

For iOS, use an available simulator and normal local Xcode behavior:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
  -project KitchenMemory.xcodeproj \
  -scheme KitchenMemory \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO \
  -only-testing:KitchenMemoryUITests/KitchenMemoryUITests
```

Avoid interacting with the simulator while UI tests are running. User input can
move or dismiss the exact element XCTest is about to activate and can look like
a navigation or accessibility regression.

## Diagnosing a new audit failure

Do not broaden the issue handler from the one-line failure summary. Preserve an
`.xcresult` bundle and inspect the evidence.

1. Run only the failing test with a result bundle:

   ```sh
   xcodebuild test ... \
     -only-testing:KitchenMemoryUITests/KitchenMemoryUITests/testRecipeLibraryPassesAccessibilityAudit \
     -resultBundlePath /tmp/KitchenMemory-Accessibility.xcresult
   ```

2. Read the test-level failure:

   ```sh
   xcrun xcresulttool get test-results tests \
     --path /tmp/KitchenMemory-Accessibility.xcresult \
     --format json
   ```

3. Export only failure attachments:

   ```sh
   xcrun xcresulttool export attachments \
     --path /tmp/KitchenMemory-Accessibility.xcresult \
     --output-path /tmp/KitchenMemory-Accessibility-Attachments \
     --only-failures
   ```

4. Read `Complete Issue Description.txt`, the app screenshot, and the element
   screenshot. The small element image often reveals whether the problem is
   recipe content, an offscreen coordinate, or system chrome.
5. Inspect the failing test's activity tree with `xcresulttool get test-results
   activities`. The activities immediately before the failure name the element
   type and often its identifier.
6. If necessary, temporarily print `issue.element?.debugDescription` from the
   handler. It includes the element frame, subtree, and path through the app.
   Remove diagnostic printing before committing.
7. Prefer a real semantic correction. Add an exception only after proving that
   the reported element is correctly represented or system-owned.
8. Run both appearances and both platforms after changing shared SwiftUI
   semantics.

An exception is suspicious if it matches only error text. A strong exception
also proves which element produced the error and why no user-owned control is
hidden by the filter.

## CI policy

Build and core-test jobs are required separately for macOS and iOS.
Accessibility jobs are temporarily disabled while the UI is still changing
rapidly. Keep the UI tests available for deliberate local audits, but do not use
their platform-sensitive results as routine CI signals until the primary recipe
workflows and accessibility tree stabilize.

Re-enabling CI should restore separate macOS and iOS jobs rather than folding UI
audits into core tests. That keeps framework-specific failures visible without
obscuring the health of domain and persistence work.

See [Continuous integration](continuous-integration.md) for the complete job
graph and merge policy.

## Upgrade checklist

When adopting a new Xcode or OS version:

1. run both semantic audits without changing the exception handler;
2. temporarily disable each exception in turn and see whether the underlying
   Xcode issue still reproduces;
3. remove exceptions that are no longer necessary;
4. inspect new element types and identifiers rather than extending an old
   matcher by guesswork;
5. rerun the exact spoken-content read-flow test on both platforms; and
6. update the tested-environment section in this document.

False-positive exceptions are versioned compatibility code. They should shrink
as Apple fixes the underlying accessibility tree and audit behavior.
