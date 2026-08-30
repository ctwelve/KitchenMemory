# A unified native multiplatform app target for Kitchen Memory

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Adopted and validated by [ADR 0013](../adr/0013-unified-native-multiplatform-app-target.md)
- Researched: 2026-08-29
- Scope: Replacing the former separate native iOS and macOS application targets
  with one native iOS/iPadOS/macOS
  Xcode target, including signing, resources, tests, CI, distribution, and
  startup presentation

## Conclusion

**Yes. Kitchen Memory uses one native multiplatform application target.**
Apple explicitly supports iOS, iPadOS,
macOS, tvOS, and visionOS in one app target, recommends the arrangement when
the platforms share substantial code and settings, and calls out a shared
SwiftUI `App` lifecycle as the favorable case. Apple recommends separate
targets when the implementations do not overlap substantially, using UIKit on
one platform and AppKit on another as its example.
[Configuring a multiplatform app](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)

Kitchen Memory matches Apple's favorable case unusually closely. The unified
target compiles one shared SwiftUI application layer, uses `KitchenMemoryApp`,
links `KitchenKit`, and shares localization, starter content, UI assets,
privacy manifest, Icon Composer app icon, and production/development bundle
identifiers. SDK-qualified settings select separate editable iOS and macOS
property lists and entitlement files, while platform filters keep the localized
launch-screen resources in iOS products only.
[Current implementation architecture](../implementation-architecture.md)
· [Shared app entry point](../../KitchenMemory/KitchenMemoryApp.swift)
· [Xcode project](../../KitchenMemory.xcodeproj/project.pbxproj)

The useful merge is therefore **one application target with platform-qualified
settings and platform-filtered resources**, not an attempt to pretend that iOS
and macOS have identical bundles. One target still produces a platform-specific
app for the selected run or archive destination. It also does not decide App
Store identity, universal purchase, scheme topology, or test-plan topology;
those are related but independent choices.
[Running an app on selected destinations](https://developer.apple.com/documentation/xcode/building-and-running-an-app)
· [Distributing apps](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

Do **not** reuse the iOS launch-screen mechanism on native macOS. Apple's launch
screen documentation is specifically for iOS, and the Human Interface
Guidelines say launch screens are not applicable to macOS. macOS indicates
launch progress with the app icon bouncing in the Dock; the app should then
show its normal or restored window promptly. If Kitchen Memory needs visible
preparation, reuse the launch artwork in a real initial SwiftUI view inside that
window, not by compiling `LaunchScreen.storyboard` for Mac.
[Specifying an app's launch screen](https://developer.apple.com/documentation/xcode/specifying-your-apps-launch-screen)
· [Launching](https://developer.apple.com/design/human-interface-guidelines/launching/)
· [Reducing app launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time)

## Keep the meanings of “one app” separate

| Question | What it controls | Recommendation now |
| --- | --- | --- |
| Shared source? | Which files implement each build | Already shared; retain platform-specific file filters where needed |
| One app target? | Membership and build settings for the native app product selected by a destination | Adopted as one `KitchenMemory` target after the validation gates passed |
| One bundle identifier / App ID? | Signing identity and system identity | Keep today's shared production ID; condition only if a future product decision requires independent apps |
| One App Store Connect record? | Universal purchase and store metadata grouping | Compatible with the shared ID, but a distribution choice rather than a target requirement |
| One scheme? | Build, run, test, profile, analyze, and archive action defaults | One app scheme is sufficient if platform CI actions choose destinations explicitly |
| One test plan? | Test targets and runtime configurations invoked by Test | Adopted as one app plan containing the multiplatform hosted and UI-smoke targets |
| One archive? | A distributable build for a class of destination | No; iOS and native macOS remain separate archive actions and artifacts |

A target is Xcode's description of a product to build; a scheme selects targets
and action defaults; and a test plan describes the tests and configurations for
a scheme's Test action. Apple documents these as distinct project objects.
[Configuring a target](https://developer.apple.com/documentation/xcode/configuring-a-new-target-in-your-project)
· [Organizing tests with plans](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback)

Likewise, one target does not force universal purchase. Xcode defaults a
multiplatform target to the same bundle ID on every platform so it can
participate in universal purchase, but its Signing editor permits distinct
platform bundle IDs and signing settings when independently distributed
versions are desired. Conversely, App Store Connect says a single multiplatform
record uses one bundle ID while storing platform-specific information
separately. Since Xcode 11.4, one App ID can be used to build iOS, macOS, tvOS,
and watchOS apps. These rules make target topology and store topology
orthogonal.
[Preparing an app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)
· [Adding a multiplatform App Store record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
· [Registering an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id)

## What one target supports

### Native destinations and conditional source

Adding **Mac** as a supported destination creates a native macOS build that can
use AppKit and SwiftUI; it is not Mac Catalyst and not an unmodified iOS app on
Apple silicon. The same target can retain iPhone and iPad destinations. Xcode
chooses the effective SDK from the active destination, and platform-specific
frameworks or APIs can be isolated with `canImport`, `#if os(...)`, or a
per-source-file platform filter in Build Phases.
[Configuring a multiplatform app](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)

Apple's installed Xcode 26.6 templates corroborate the public documentation.
The first-party “Multiplatform Base” template uses `SDKROOT = auto`, supports
`iphoneos`, `iphonesimulator`, and `macosx` in one target, and applies iOS
scene/launch keys only to iPhone device and simulator SDKs. Its multiplatform
SwiftUI template creates matching multiplatform unit- and UI-test bundles.
These template files are installed under
`Xcode.app/Contents/Developer/Library/Xcode/Templates/Project Templates/MultiPlatform/Base/`.

Kitchen Memory already uses this form successfully in two places:
`KitchenKit` builds for iOS, iOS Simulator, and macOS with `SDKROOT = auto`, and
the shared UI-test target builds for all three while choosing its current app
host with SDK-qualified settings.
[Current Xcode project](../../KitchenMemory.xcodeproj/project.pbxproj)

### Build settings and information property lists

Xcode lets a target specialize a build setting by platform and configuration.
The final `Info.plist` is also a build product: Xcode substitutes build-setting
variables and inserts keys derived from target configuration. Within a source
property list, a key may be qualified as
`[key]-[platform]~[device]`; supported qualifiers include `iphoneos`, `macos`,
`iphone`, `ipad`, and `mac`.
[Configuring a multiplatform app](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)
· [Managing information property-list values](https://developer.apple.com/documentation/bundleresources/managing-your-app-s-information-property-list)

Kitchen Memory could therefore use one source `Info.plist`, but that is not a
prerequisite for one target. The adopted implementation preserves separate
source files and conditions `INFOPLIST_FILE` by SDK. This keeps both files
directly editable in Xcode's property-list editor and keeps the iOS-only
remote-notification and launch configuration out of the native Mac bundle.
[iOS property list](../../KitchenMemory/Info-iOS.plist)
· [macOS property list](../../KitchenMemory/Info-macOS.plist)

The main settings that need deliberate qualification are:

- `SDKROOT = auto` and `SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx`;
- both `IPHONEOS_DEPLOYMENT_TARGET` and `MACOSX_DEPLOYMENT_TARGET`;
- generated common bundle metadata plus the iOS and macOS `INFOPLIST_FILE`
  adapters;
- `LD_RUNPATH_SEARCH_PATHS`, because native macOS embeds frameworks one bundle
  level above the iOS location;
- macOS hardened-runtime and signing settings; and
- `CODE_SIGN_ENTITLEMENTS` by both SDK and build environment.

This is normal multiplatform-target configuration, but it should remain a
checked contract rather than an undocumented collection of exceptions. Apple
describes build settings as controlling compilation, linking, packaging, and
distribution, and its reference defines `CODE_SIGN_ENTITLEMENTS` as the path
to the entitlements file used for signing.
[Configuring target build settings](https://developer.apple.com/documentation/xcode/configuring-the-build-settings-of-a-target)
· [Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)

### Capabilities, entitlements, and signing

Entitlements are embedded in each executable's code signature. Xcode combines
the selected entitlements file, developer-account information, and project
settings while signing. Capabilities vary by platform, and adding a capability
may update the entitlements, property list, frameworks, and signing assets.
[Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)
· [Adding capabilities](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app)

Kitchen Memory must **not** flatten its production entitlement files. The iOS
app uses `aps-environment`, while native macOS uses
`com.apple.developer.aps-environment`. A unified target selects those files
with SDK-qualified `CODE_SIGN_ENTITLEMENTS` values for production-capable
configurations. App Sandbox and outbound network access are ordinary macOS
target capabilities, so the project expresses them through SDK-qualified build
settings. Testing configurations need no entitlement source file: Xcode
synthesizes the macOS sandbox values from those settings, while the iOS test
host requires no source entitlements.
[iOS production entitlements](../../KitchenMemory/KitchenMemory-iOS.entitlements)
· [macOS production entitlements](../../KitchenMemory/KitchenMemory-macOS.entitlements)

The production targets already share `net.ctwelve.KitchenMemory`, and both
development targets already share `net.ctwelve.dev.KitchenMemory`. A unified
target therefore need not change product identity. Still validate the final
signed entitlements for every platform and environment; Apple recommends
checking the entitlements in the built app and the provisioning profile rather
than trusting only the source file.
[Diagnosing entitlement issues](https://developer.apple.com/documentation/bundleresources/diagnosing-issues-with-entitlements)

### Resources and app icons

Asset catalogs natively support variants by platform, device, resolution,
appearance, and language, and Xcode chooses the applicable variant at runtime.
For app icons, iOS/iPadOS and macOS have different size requirements, which can
coexist in the same catalog. Apple's current Icon Composer can instead provide
one multilayer icon file with platform and appearance variants across iOS,
iPadOS, macOS, watchOS, and the App Store.
[Managing asset catalogs](https://developer.apple.com/documentation/xcode/managing-assets-with-asset-catalogs)
· [Configuring app icons](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
· [Creating an icon with Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)

Kitchen Memory already has the favorable structure: its Icon Composer file,
UI colors, sample assets, localization, credits, and privacy manifest are in
the shared application folder. Keep those shared. Mark the iOS launch
storyboard, launch asset catalog, and localized launch strings as iOS-only
resources using Xcode's platform filter. No duplicate Mac app icon or resource
catalog is required.
[Shared app icon](../../KitchenMemory/AppIcon.icon/icon.json)
· [iOS launch storyboard](../../KitchenMemory/Base.lproj/LaunchScreen.storyboard)

## Tests, schemes, and plans

One application target can be accompanied by separate test targets, exactly as
Apple's multiplatform app template does. A scheme associates the product and
test activity, while the active test plan chooses test targets and runtime
configuration. The chosen run destination remains the platform selector; a
test-plan configuration is not a destination selector.
[Configuring a target](https://developer.apple.com/documentation/xcode/configuring-a-new-target-in-your-project)
· [Organizing tests with plans](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback)

Kitchen Memory now uses this coherent endpoint:

- one `KitchenMemory` native multiplatform app target;
- one `KitchenMemoryTests` hosted multiplatform test target;
- the existing one `KitchenMemoryUITests` multiplatform UI target;
- one `KitchenMemory.xctestplan` containing those two test targets;
- one `KitchenMemory` scheme that builds only the app and references that plan;
  and
- the unchanged standalone `KitchenKit` scheme and plan for canonical
  business-logic coverage.

The migration proved app construction on both destinations before replacing
the two hosted targets and platform plans. The resulting single plan then
passed on both destinations. Destination-specific schemes remain an available
future choice if Run/Profile arguments diverge, but they are not necessary
merely to distinguish iOS from macOS because Xcode already does that through
the destination.

## CI and distribution consequences

Unifying the target should reduce project duplication, **not platform
coverage**. Xcode Cloud still needs separate iOS and macOS Build, Analyze, and
Test actions, each selecting the same scheme and plan but a different native
destination. Apple's workflow guidance demonstrates one project archiving both
iOS and macOS as distinct actions, and Xcode's distribution documentation says
the archive is built for the class of device selected as the run destination.
[Create practical workflows in Xcode Cloud](https://developer.apple.com/videos/play/wwdc2023/10278/)
· [Distributing apps](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

The release workflow likewise keeps separate iOS and native Mac archive
artifacts. Only the Mac archive receives Developer ID/notarization handling;
universal purchase does not combine the two platform binaries into one archive.
The existing release tag, source version, and Mac notarization contracts remain
in force.
[Current CI contract](../continuous-integration.md)
· [Preparing apps for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)

Migration must update the repository's structure checker, release-version
checker, software inventory, project documentation, Xcode Cloud action scheme
names, plan references, and any test-host target names together. A green local
build alone is insufficient because CI also depends on the saved scheme and
plan topology and on platform-specific archive/post-action selection.

## Native macOS startup presentation

An iOS launch screen is a system-owned, static placeholder displayed before the
app draws its first interface. It may be configured through `UILaunchScreen` or
an iOS storyboard, and a storyboard launch screen may use UIKit views only.
macOS has no equivalent launch-screen contract.
[Specifying an app's launch screen](https://developer.apple.com/documentation/xcode/specifying-your-apps-launch-screen)
· [`UILaunchScreen`](https://developer.apple.com/documentation/bundleresources/information-property-list/uilaunchscreen)

Apple's supported Mac launch experience is the normal application lifecycle:
the Dock icon indicates that launch is in progress, and the app presents or
restores its real windows when ready. Apple's guidance is to launch instantly,
restore previous state, and show something as soon as possible; if actual
loading lasts more than a moment, use placeholders or a progress indicator in
the app's interface. A splash is permitted only after launching, preferably as
part of onboarding, and should not delay access to the app.
[Launching](https://developer.apple.com/design/human-interface-guidelines/launching/)
· [Loading](https://developer.apple.com/design/human-interface-guidelines/loading)
· [macOS window restoration](https://developer.apple.com/documentation/swiftui/customizing-window-styles-and-state-restoration-behavior-in-macos)

Kitchen Memory already defines `KitchenLoadingView`, but
`KitchenMemoryApp.init()` synchronously calls `AppRuntime.prepare()` before the
scene is constructed, so the loading case is not currently part of the
startup-state enum and the view cannot cover that preparation interval.
[App entry point](../../KitchenMemory/KitchenMemoryApp.swift)
· [Startup view](../../KitchenMemory/KitchenStartupView.swift)
· [Runtime preparation](../../KitchenMemory/AppRuntime.swift)

The Mac-appropriate reuse is therefore:

1. add a `.preparing` application state;
2. construct the real Mac window immediately with `KitchenLoadingView`;
3. perform preparation from the presented scene rather than synchronously in
   the `App` initializer;
4. transition to content or the existing unavailable state; and
5. if desired, promote the launch background artwork to a shared asset and use
   it in that real loading view.

This can make the Mac startup visually related to iOS without misclassifying a
UIKit storyboard as a macOS launch resource. It also creates a closer match
between the iOS launch screen and the first real screen, which Apple recommends.
The iOS storyboard itself should remain iOS-only.

## Competing hypotheses

### H0 — Keep the two application targets

Separate targets remain the better model if the near-term Mac implementation
switches materially to AppKit while mobile switches to UIKit, or if the products
need substantially different capabilities, resources, configurations, release
identities, or source membership. This is Apple's stated boundary for when one
target stops being a good fit.
[Configuring a multiplatform app](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)

**Falsified by the adoption:** the one-target implementation preserved every
existing build, test, signing, archive, and product-identity contract while
deleting more duplicated configuration than it introduced in platform
qualifications.

### H1 — One native multiplatform app target now

This fits the current source tree and Apple's SwiftUI guidance. It removes a
duplicated target, scheme, plan, hosted-test target, synchronized-folder
membership surface, and repeated build settings while retaining native iOS and
native macOS outputs.

Its main risk is replacing visible target ownership with a hard-to-audit matrix
of SDK-qualified settings. The project checker should therefore require the
supported destinations, both deployment floors, each environment's entitlement
selection, iOS-only launch membership, Mac runpaths/hardening, shared bundle
identities, and two-platform CI actions.

**Future falsifier:** the implementation accumulates numerous opaque
exclusions, cannot select the intended entitlements and provisioning profiles
in every environment, cannot host the shared tests on both destinations, or
makes platform-specific UI ownership harder to inspect than separate targets.

### H2 — Merge only the app target but retain platform schemes and plans

This is a useful intermediate state. It proves native product construction and
signing before changing test ownership. It may also remain the endpoint if the
platform Run/Profile actions later need meaningfully different arguments or
diagnostics.

**Falsifier:** both schemes become structurally identical except for names and
their Xcode Cloud actions already select explicit destinations; then one scheme
and plan communicate the topology more truthfully.

## Outcome

Kitchen Memory adopted **H1** in [ADR 0013](../adr/0013-unified-native-multiplatform-app-target.md).
The project is closer to Apple's multiplatform template than to Apple's example
for separate targets, and its remaining differences are the platform-specific
settings, entitlements, property lists, and resources that Xcode supports in
one target. [ADR 0009](../adr/0009-separate-native-app-targets.md) is retained as
the record of a useful earlier decision. If later UIKit/AppKit divergence makes
the target shallow again, splitting it remains a reversible project-organization
decision.

## Validation record

Issue 67 applied the falsifiable gates from this research to the adopted target:

- the project checker proved exactly five native targets, two shared schemes,
  and two saved plans, including SDK-qualified plist and entitlement selection;
- all five configurations built for native macOS and iOS Simulator;
- Analyze passed on both destinations;
- the complete saved application plan passed on native Mac, and its 66 iOS
  tests passed on iPhone Simulator after one transient localization smoke retry;
- built products and separate signed Production archives preserved bundle
  identity, platform-correct plist keys, iOS-only localized launch resources,
  and the intended platform entitlements; and
- the canonical `KitchenKit` lane remained exactly 8,166/8,166 covered business
  logic lines, with the same 105 runtime-adapter lines excluded.

The remaining operational step is outside the repository: before push or
merge, Xcode Cloud actions that named the deleted platform schemes must be
migrated to `KitchenMemory` while retaining their existing native destination.
