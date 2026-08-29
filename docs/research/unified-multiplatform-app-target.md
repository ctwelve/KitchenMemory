# A unified native multiplatform app target for Kitchen Memory

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Research complete; prototype specified but not yet run
- Researched: 2026-08-29
- Scope: Replacing the separate native `KitchenMemoryIOS` and
  `KitchenMemoryMacOS` application targets with one native iOS/iPadOS/macOS
  Xcode target, including signing, resources, tests, CI, distribution, and
  startup presentation

## Conclusion

**Yes. Kitchen Memory is presently a strong candidate for one native
multiplatform application target.** Apple explicitly supports iOS, iPadOS,
macOS, tvOS, and visionOS in one app target, recommends the arrangement when
the platforms share substantial code and settings, and calls out a shared
SwiftUI `App` lifecycle as the favorable case. Apple recommends separate
targets when the implementations do not overlap substantially, using UIKit on
one platform and AppKit on another as its example.
[Configuring a multiplatform app](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)

Kitchen Memory matches Apple's favorable case unusually closely today. Both
native targets compile one shared SwiftUI application layer, use the same
`KitchenMemoryApp`, link the same `KitchenKit`, share localization, starter
content, UI assets, privacy manifest, and Icon Composer app icon, and already
use the same production and development bundle identifiers. The platform
folders contain no platform-specific Swift source. The Mac folder contains only
its property list and production/testing entitlements; the iOS folder contains
those equivalents plus its required iOS launch-screen resources.
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
| One app target? | Membership and build settings for the native app product selected by a destination | Prototype and, if the gates pass, adopt one `KitchenMemory` target |
| One bundle identifier / App ID? | Signing identity and system identity | Keep today's shared production ID; condition only if a future product decision requires independent apps |
| One App Store Connect record? | Universal purchase and store metadata grouping | Compatible with the shared ID, but a distribution choice rather than a target requirement |
| One scheme? | Build, run, test, profile, analyze, and archive action defaults | One app scheme is sufficient if platform CI actions choose destinations explicitly |
| One test plan? | Test targets and runtime configurations invoked by Test | One app plan is plausible after the hosted-test target is also made multiplatform |
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
prerequisite for one target. The lower-risk first prototype should preserve the
existing source files and condition `INFOPLIST_FILE` by SDK. This keeps the
iOS-only remote-notification and launch configuration out of the native Mac
bundle while changing only target ownership. A later cleanup can combine the
two small files with platform-qualified keys after inspecting both built
property lists.
[iOS property list](../../KitchenMemoryIOS/Info.plist)
· [macOS property list](../../KitchenMemoryMacOS/Info.plist)

The main settings that need deliberate qualification are:

- `SDKROOT = auto` and `SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx`;
- both `IPHONEOS_DEPLOYMENT_TARGET` and `MACOSX_DEPLOYMENT_TARGET`;
- the iOS and macOS `INFOPLIST_FILE` values;
- `UILaunchStoryboardName`, scene-manifest generation, orientations, and
  indirect-input keys for iPhone device and simulator SDKs only;
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

Kitchen Memory must **not** flatten its entitlement files. The production iOS
app uses `aps-environment`; native macOS uses
`com.apple.developer.aps-environment` and additionally requires App Sandbox and
outgoing network-client entitlements. The test hosts also differ: iOS is
deliberately empty while macOS retains its least-privilege sandbox and network
client. A unified target should select the existing files with
SDK-qualified `CODE_SIGN_ENTITLEMENTS` values for each of `Debug`, `Develop`,
`Testing`, `Production`, and `ProductionTesting`.
[iOS production entitlements](../../KitchenMemoryIOS/KitchenMemory.entitlements)
· [macOS production entitlements](../../KitchenMemoryMacOS/KitchenMemory.entitlements)
· [iOS testing entitlements](../../KitchenMemoryIOS/KitchenMemory-Testing.entitlements)
· [macOS testing entitlements](../../KitchenMemoryMacOS/KitchenMemory-Testing.entitlements)

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
· [iOS launch storyboard](../../KitchenMemoryIOS/Base.lproj/LaunchScreen.storyboard)

## Tests, schemes, and plans

One application target can be accompanied by separate test targets, exactly as
Apple's multiplatform app template does. A scheme associates the product and
test activity, while the active test plan chooses test targets and runtime
configuration. The chosen run destination remains the platform selector; a
test-plan configuration is not a destination selector.
[Configuring a target](https://developer.apple.com/documentation/xcode/configuring-a-new-target-in-your-project)
· [Organizing tests with plans](https://developer.apple.com/documentation/xcode/organizing-tests-to-improve-feedback)

Kitchen Memory's app-test source is already shared but is compiled into two
hosted unit-test targets. The UI-smoke source already uses one multiplatform
target. After the app target is unified, the coherent endpoint is:

- one `KitchenMemory` native multiplatform app target;
- one `KitchenMemoryTests` hosted multiplatform test target;
- the existing one `KitchenMemoryUITests` multiplatform UI target;
- one `KitchenMemory.xctestplan` containing those two test targets;
- one `KitchenMemory` scheme that builds only the app and references that plan;
  and
- the unchanged standalone `KitchenKit` scheme and plan for canonical
  business-logic coverage.

This test-target merge is a second migration step, not proof that the app-target
merge succeeded. First make both current platform plans pass against the
prototype app target. Then replace the two hosted targets and two plans, and
prove the single plan on both destinations. Retaining destination-specific
schemes would also be valid if future Run/Profile arguments diverge, but they
are not necessary merely to distinguish iOS from macOS because Xcode already
does that through the destination.

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

**Falsifier:** a one-target prototype preserves every existing build, test,
signing, archive, and product-identity contract while deleting more duplicated
configuration than it introduces in platform qualifications.

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

**Falsifier:** the prototype needs numerous opaque exclusions, cannot select
the intended entitlements and provisioning profiles in every environment,
cannot host the shared tests on both destinations, or makes future
platform-specific UI ownership harder to inspect than today's duplication.

### H2 — Merge only the app target but retain platform schemes and plans

This is a useful intermediate state. It proves native product construction and
signing before changing test ownership. It may also remain the endpoint if the
platform Run/Profile actions later need meaningfully different arguments or
diagnostics.

**Falsifier:** both schemes become structurally identical except for names and
their Xcode Cloud actions already select explicit destinations; then one scheme
and plan communicate the topology more truthfully.

## Recommendation

Run the prototype and expect to adopt **H1**, staged through **H2**. The current
project is closer to Apple's multiplatform template than to Apple's example for
separate targets, and the remaining differences are precisely the kinds of
platform-specific settings, entitlements, and resources that Xcode supports in
one target.

Treat [ADR 0009](../adr/0009-separate-native-app-targets.md) as the record of a
useful earlier decision, not a permanent build constraint. If the prototype
passes, supersede its current status and update live architecture/CI documents
in the same change. If later UIKit/AppKit divergence makes the target shallow
again, splitting it is a reversible project-organization decision.

## Falsifiable prototype

Perform this in a disposable branch or worktree using Xcode's native target,
Supported Destinations, Signing & Capabilities, Build Phases platform filters,
scheme, and test-plan editors:

1. Add a new app target named `KitchenMemoryPrototype` rather than deleting
   either accepted target. Give it native iPhone, iPad, and Mac destinations.
2. Add the shared `KitchenMemory/` application layer and `KitchenKit` dependency.
   Preserve the shared Icon Composer file and shared resources.
3. Use `SDKROOT = auto`; add iOS, iOS Simulator, and macOS supported platforms;
   and reproduce the existing configuration matrix with SDK-qualified plist,
   entitlement, runpath, hardened-runtime, and iOS launch settings.
4. Add the launch storyboard, launch catalog, and launch localizations for iOS
   only. Do not add them to the Mac resource build.
5. Point the two existing hosted test targets and the UI target at the prototype
   target one at a time. Keep the current platform plans for this first pass.
6. Build `Debug`, `Develop`, `Testing`, `Production`, and `ProductionTesting` for
   both native platforms. Run Analyze and each complete platform plan.
7. Inspect the two built `Info.plist` files, linked/embedded `KitchenKit`, code
   signatures, and effective entitlements. Confirm the iOS bundle has the launch
   and remote-notification declarations; confirm the Mac bundle does not; confirm
   Mac sandbox, network-client, hardened-runtime, and notification entitlements;
   and confirm test hosts have only their intended least privilege.
8. Produce unsigned local Production archives for generic iOS and native Mac.
   Confirm there are two platform artifacts with the expected product name,
   version, build, bundle ID, resources, and Mac notarization eligibility.
9. Only after all of that passes, prototype one multiplatform hosted-test target,
   one app plan, and one app scheme. Run that same plan on a compact iPhone
   simulator and native Mac, then exercise the exact Xcode Cloud action matrix.

Adopt the unified topology only if all of these assertions pass and the final
qualified-setting count is smaller and clearer than the removed target/scheme/
plan duplication. A failure in signing, built metadata, resource filtering,
test hosting, archive identity, or CI destination selection falsifies the
proposal until explained; it is not a reason to weaken an existing product
contract.
