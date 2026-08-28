# Internal framework linkage for Kitchen Memory

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Research complete; experiment specified but not yet run
- Researched: 2026-08-28
- Scope: Linkage and packaging of `KitchenMemoryDomain`,
  `KitchenMemoryImport`, `KitchenMemoryPersistence`, and `KitchenMemoryLogic`
  in the native iOS and macOS products

## Conclusion

Kitchen Memory's module boundaries should remain, but its shipping products do
not have a demonstrated need for four separately loaded private dynamic
libraries. **Module separation, framework packaging, and static-versus-dynamic
linkage are different decisions.** The four targets can continue to enforce the
current dependency graph and Swift import boundaries even if their code is
incorporated into a larger binary at link time.

The best first experiment is **mergeable internal frameworks in the
distributable `Production` configuration**, not an immediate conversion of all
configurations to static frameworks. In Xcode 15 and later, mergeable dynamic
libraries remain ordinary dynamic libraries in unoptimized builds and are
merged into their direct dependent in optimized builds. Apple positions this as
static-like launch behavior in release builds without static-library iteration
cost in debug builds. Kitchen Memory's apps already link all four frameworks as
direct dependencies, so each app is a natural merged binary. Keep `Testing` and
the non-distributable `ProductionTesting` host on today's ordinary dynamic
topology until a controlled experiment proves that changing the hosted-test
topology is safe. [Configuring mergeable libraries](https://developer.apple.com/documentation/xcode/configuring-your-project-to-use-mergeable-libraries)
· [Meet mergeable libraries](https://developer.apple.com/videos/play/wwdc2023/10268/)

Straight static frameworks are a sound second hypothesis. Xcode 15 and later
officially supports a framework bundle whose main binary is a static archive;
the client links the code into its own binary, while Xcode omits that archive
from the embedded framework bundle. This preserves a framework's module and
resource packaging and is not the same as flattening the source into an app
target. [Creating a static framework](https://developer.apple.com/documentation/xcode/creating-a-static-framework)

Do not choose either alternative on intuition alone. The current app-hosted
XCTest bundles directly link the same four modules as their host apps, and the
exact coverage gate addresses four `.framework` coverage products by name.
Those contracts make runtime uniqueness and coverage attribution acceptance
criteria, not cleanup after the conversion.

## What the project has today

The repository deliberately treats the four modules as technical boundaries,
not independently distributed packages. Domain is persistence-independent;
Import and Persistence each depend on Domain; Logic depends on all three; and
both native app targets link all four. This direction is part of the
architecture and should not change merely because linkage changes.
[Implementation architecture](../implementation-architecture.md#target-organization)
· [Domain architecture](../domain-architecture.md#module-organization)

The Xcode project currently declares all four products as
`com.apple.product-type.framework`, links all four from each app, and copies all
four into each app's `Frameworks` directory with `CodeSignOnCopy`. Logic links
Domain, Import, and Persistence; Import and Persistence each link Domain.
Both app-hosted unit-test targets also link all four framework products.
[Current framework targets and link phases](../../KitchenMemory.xcodeproj/project.pbxproj)

The target type matters: Apple's framework template produces a dynamic
framework by default, and the project has no `MACH_O_TYPE` override for these
targets. A pre-existing local Production artifact also identified their main
binaries as Mach-O dynamic libraries, but that artifact predates the current
source state and is useful only as topology corroboration. Its byte sizes are
not a current baseline. [Creating a static framework](https://developer.apple.com/documentation/xcode/creating-a-static-framework)

The four framework resource phases contain no resources, and the four module
directories currently contain Swift source only. Application resources already
live in the shared or platform-specific app layers. This makes resource
migration a future-proofing concern rather than an immediate conversion
blocker. [Implementation architecture: localization and sample resources](../implementation-architecture.md#localization-resources)

## Packaging is not linkage

The useful distinctions are:

| Form | Compile-time module boundary | Runtime code location | Resource packaging |
| --- | --- | --- | --- |
| Dynamic framework | Yes | A separately loaded Mach-O dylib inside a framework bundle | Framework bundle |
| Static framework | Yes | Selected archive objects are linked into the consuming executable or dylib | Framework bundle; Xcode omits the already-linked archive from the embedded copy |
| Plain static library | Yes, when its Swift/Clang module artifacts are configured | Selected archive objects are linked into the consumer | No framework bundle; resources need a separate bundle or app ownership |
| Mergeable dynamic framework | Yes | Ordinary dylib in unoptimized builds; code is combined into the configured merged binary in optimized builds | Xcode preserves an embedded resource bundle and supplies a `Bundle(for:)` hook unless explicitly disabled |

Apple's Xcode 15 static-framework support is therefore more precise than the
old shorthand that “a framework is dynamic.” To convert a framework target,
Apple directs the developer to set its **Mach-O Type** to **Static Library**.
The documented build-setting route preserves the existing target organization
and is therefore the smaller project-layout experiment.
[Creating a static framework](https://developer.apple.com/documentation/xcode/creating-a-static-framework)
· [Xcode build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)

A plain `.a` target would be reasonable only if Kitchen Memory deliberately no
longer wanted framework-bundle behavior. It would not make the code “more
static” than a static framework, and it would create more resource and module
packaging work without answering the architectural question. Because the
existing named framework targets are useful boundaries, a static framework is
the smaller experiment.

## Consequence matrix

| Concern | Ordinary dynamic frameworks | Static frameworks | Mergeable dynamic frameworks |
| --- | --- | --- | --- |
| App launch | `dyld` must find, map, and bind four additional private images. Modern launch closures and page-in linking reduce but do not erase per-image work. | No four private framework binaries for `dyld` to load; their code is in the consumer. | Same central release benefit as static linking: fewer loaded images after merging. Debug and other unoptimized builds retain dynamic loading. |
| Iterative build and link time | Small changes do not require copying framework code into each final executable, which favors active development. | Rebuilding an archive and statically linking it can slow iteration, especially for code under active development. | Explicitly designed to retain dynamic-library build behavior in unoptimized builds and pay merge cost in optimized builds. |
| Code and bundle size | Each app carries one copy of each framework binary plus framework/signing/alignment overhead. The main executable contains references rather than copied framework code. | The linker selectively loads archive members that satisfy unresolved symbols, and dead stripping can remove unreachable code. The larger main binary may still make the total bundle smaller or larger; measurement decides. | Merging is comparable to `-all_load`, then the linker can deduplicate strings, Objective-C selectors, message-send stubs, and apply ordinary size optimizations. Apple says the result is normally a smaller overall bundle, but Kitchen Memory still needs its own measurement. |
| Memory | Dynamic code pages can be shared when the same dylib is mapped by multiple processes; each dylib also contributes separate data pages and fixups. | One process has one linked copy, and the linker can co-locate globals. Separate executables each receive their own copy. | A merged executable has static-like runtime layout. A deliberately unmerged group framework can still be shared by several executables. |
| Resources | `Bundle(for:)` naturally identifies the framework bundle. | Xcode 15's static framework keeps the bundle/resource role even though its archive code is already in the consumer. | Xcode supplies a lookup hook for a merged library's resource bundle. Disabling that hook is valid only when no caller relies on bundle lookup. |
| Future app extensions or executables | Apple supports an embedded framework as shared code between a containing app and extension, subject to extension-safe APIs. | Every app, widget, extension, helper, or XPC executable that uses the archive gets its own linked code. | Automatic merging into every executable can duplicate code. Manual merging can leave a framework dynamic or create a group library when shared size matters. |
| Binary distribution and evolution | Can be distributed separately, but only when versioning, signing, module stability, and library evolution are intentionally designed. | Can also be distributed as an XCFramework; static linkage does not prevent binary distribution. | Mergeable XCFrameworks can be distributed with merge metadata, and each client decides whether to merge. |
| Runtime lookup and plug-ins | A real library path remains available to `dlopen` and bundle lookup. | There is no separately loadable framework implementation binary. | Callers of `dlopen` or bundle APIs must point at the merged product/bundle behavior described by Apple. |

Apple's linker team explains the underlying trade: static archives contribute
only object files needed to resolve symbols, while a dynamic link records a
runtime promise instead of copying code. Dynamic libraries improve link
scalability and can share physical read-only pages across processes, but loading
more dylibs increases launch work and separate dylibs add data pages. Static
archives can slow rebuild/link work, especially for code under active
development. [Link fast: Improve build and launch times](https://developer.apple.com/videos/play/wwdc2022/110362/)

Apple's current launch guidance likewise says every additional embedded
third-party framework adds work even though launch closures cache much of it,
and recommends limiting embedded frameworks or using mergeable libraries.
That establishes direction, not a Kitchen Memory performance result.
[Reducing your app's launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time)

For a future widget or extension, dynamic sharing becomes materially more
credible: Apple documents embedded frameworks as the mechanism for sharing code
between an app extension and its containing app. Apple also explicitly cites a
dependency shared by an app and extension as a reason to choose manual rather
than automatic merging. [App Extension Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html)
· [Configuring mergeable libraries](https://developer.apple.com/documentation/xcode/configuring-your-project-to-use-mergeable-libraries)

Today, however, the iOS and macOS apps are separate platform products, and each
embeds its own private copies. They do not receive cross-program disk or memory
sharing merely because the internal code is dynamically linked. Installing one
common macOS framework outside both app bundles would be a different deployment,
versioning, signing, and update architecture that Kitchen Memory has not chosen.

## Swift, Objective-C, and binary evolution

Changing linkage does not merge the Swift source modules or relax their access
control. Imports, `public` interfaces, `internal` implementation, target
membership, and compile-time dependency direction remain module properties.
`@testable import` depends on Xcode's testability build setting, not on whether
the final implementation resides in a dylib or an executable.

The core source is currently Swift. These folders include several `NSObject`
subclasses and notification selectors bridged with `@objc`, but no Objective-C
source or category implementation files. That avoids today's classic static
archive category trap while making the hosted-test runtime-identity check
important. [Import URL-session delegate](../../KitchenMemoryImport/RecipeURLRedirectController.swift)
· [Persistence runtime observers](../../KitchenMemoryPersistence/Cloud/PersistentStoreChangeObserver.swift)

If categories are introduced later, Apple documents that the linker
may not pull their object files because calling a category method does not
create an undefined linker symbol; `-ObjC` forces the relevant archive members
but can increase size. [QA1490: Building Objective-C static libraries with categories](https://developer.apple.com/library/archive/qa/qa1490/_index.html)

Dynamic linkage also does not by itself give these internal frameworks a useful
independent-evolution contract. Swift's library-evolution guidance says
frameworks built and distributed together with their app should leave library
evolution off; `BUILD_LIBRARY_FOR_DISTRIBUTION` is for a framework built or
updated separately from its clients and changes performance and language
semantics. Kitchen Memory ships these modules and each client app together, so
the current source-built model is appropriate under all three linkage options.
[Library evolution in Swift](https://www.swift.org/blog/library-evolution/)

## Hosted XCTest and coverage are the sharp edge

`KitchenMemoryIOSTests` and `KitchenMemoryMacTests` are app-hosted bundles. Each
sets `BUNDLE_LOADER` to its app executable and directly links Domain, Import,
Persistence, and Logic, while the host app also links those four products.
[Xcode project](../../KitchenMemory.xcodeproj/project.pbxproj)

Apple defines `BUNDLE_LOADER` precisely: undefined symbols from the bundle are
checked against the named executable as though the executable were a dynamic
library. Apple also notes that an app hosting XCTest must preserve its exported
symbols. These facts make it plausible that test references can resolve to the
host's statically incorporated definitions, but they do **not** prove that every
Swift metadata record, generic specialization, protocol conformance, global, or
Objective-C-visible class will exist only once in Kitchen Memory's final test
process. [Xcode build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
· [Link fast: Improve build and launch times](https://developer.apple.com/videos/play/wwdc2022/110362/)

The competing failure hypothesis is that the app and test-bundle link steps
each pull some of the same static module objects, creating two runtime copies.
Possible symptoms include duplicate Objective-C class warnings, unequal
singleton/global state, distinct Swift type metadata, or a failure that dead
stripping masks by choosing one duplicate. Apple's linker team warns generally
that incorporating a static library into multiple loaded images can create
duplicate definitions and Objective-C runtime warnings. Xcode 11 also recorded
a then-known issue in which a package product linked into both an app and its
test target produced duplicated symbols. The release note is historical, not
evidence that Xcode 26 has the same bug; it is evidence that this topology must
be tested rather than assumed safe. [Link fast: Improve build and launch times](https://developer.apple.com/videos/play/wwdc2022/110362/)
· [Xcode 11 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-11-release-notes)

Coverage has a separate compatibility risk. The repository's checker asks
`xccov` for four targets named `KitchenMemoryDomain.framework`,
`KitchenMemoryImport.framework`, `KitchenMemoryLogic.framework`, and
`KitchenMemoryPersistence.framework`, then verifies that every source appears
under its expected framework product. Statically linked coverage regions may be
reported under the final app or test binary instead. Apple documents that
`xccov` reports coverage by target, file, and function, but does not promise
that static-archive input retains today's framework-target attribution.
[Current coverage checker](../../Tools/check-core-framework-coverage.sh)
· [Testing in Xcode](https://developer.apple.com/videos/play/wwdc2019/413/)

This is why a Production-only mergeable experiment is lower risk. The canonical
coverage action uses the unoptimized `Testing` configuration, so the four dylibs
and today's coverage products can remain unchanged. The release-optimized but
non-distributable `ProductionTesting` app host should also remain unmerged until
its direct test dependencies are deliberately redesigned. That preserves
[ADR 0007](../adr/0007-business-logic-coverage-and-ui-smoke-tests.md)'s exact
framework coverage and both hosted app-test lanes while the shipping topology
is measured independently.

## Competing hypotheses

### H0 — Keep all four frameworks dynamic everywhere

This is favored if clean measurements show that four private dylibs have
negligible launch, size, signing, and maintenance cost, or if upcoming widgets,
helpers, or extensions will share enough code to make a common dynamic image
valuable. It is also the simplest topology for active development and hosted
tests.

**Falsifier:** a static or merged variant materially improves the agreed release
metrics without breaking build time, tests, coverage, resources, or future
product needs.

### H1 — Convert all four to static frameworks

This is favored by the user's architectural intuition: the modules are code
divisions within one built-and-versioned product family, not independently
updated shared-program components. It retains target/module boundaries, can
selectively link archive objects, and removes four private runtime dylibs.

Its risks are slower active-development links, selective-loading surprises,
one copy per future executable, and the unproven hosted-test/coverage topology.
Using a configuration-specific `MACH_O_TYPE` might avoid debug costs, but Apple
documents static framework conversion as a target choice rather than promising
every mixed-configuration topology. That variation belongs in the experiment,
not the initial decision.

**Falsifier:** duplicate runtime identities, loss of exact coverage evidence,
meaningful incremental-build regression, larger shipping bundles, or no
repeatable launch benefit.

### H2 — Keep the modules dynamic for development, merge them for Production

This is the recommended first experiment. It expresses the same product truth
as static shipping—one app-owned implementation binary—while retaining the
dynamic debug/test behavior Apple designed mergeable libraries to preserve.
Because all four frameworks are already direct dependencies of each app,
`MERGED_BINARY_TYPE = automatic` on only the apps' distributable `Production`
configuration is the smallest candidate change. No `BUILD_LIBRARY_FOR_DISTRIBUTION`
setting or new package is warranted.

Automatic merging handles direct dependencies only. Kitchen Memory already
makes Domain, Import, Persistence, and Logic direct app dependencies, even
though Logic also depends on the other three, so the current graph fits that
rule. If future tests or extensions must consume one merged dependency, Apple's
documented group-library pattern is the next option; adding such a fifth target
would change the four-framework topology in ADR 0009 and should be a separate
architecture decision rather than hidden in this experiment.

**Falsifier:** merge build or autolink failures in the real graph, missing
resource/module behavior, an inability to validate the actual Production
binary, worse size or launch results than straight static, or operational
complexity disproportionate to the measured gain.

## Falsifiable validation experiment

Run the experiment in an isolated branch or worktree with the current source
state and one Xcode version. Do not reuse the older Production artifact as the
size baseline.

1. **Create three clean variants from the same commit.** A is today's dynamic
   graph. B converts the four targets to documented static frameworks. C sets
   automatic merging only on both app targets' distributable `Production`
   configuration. Leave signing, optimization, architecture, destination,
   dependency versions, and source unchanged.
2. **Prove physical topology for iOS and macOS.** Produce clean Production
   archives. Use `file`, `otool -L`, `dyld_info`, bundle inventory, and code-sign
   verification to record the app executable's Mach-O type and dependencies,
   every embedded framework bundle and binary, and the absence or presence of
   the four private dylibs. A static or merged variant fails if a stale dynamic
   implementation remains or an expected resource bundle is malformed.
3. **Measure size without a preferred answer.** Record uncompressed archive and
   installed-app size, main-executable size, embedded-framework total, and
   signed/exported artifact size. Attribute differences to code, metadata,
   resources, or signatures. Require a repeatable improvement rather than a
   framework-directory cosmetic change.
4. **Measure build behavior.** From clean DerivedData, measure a full Production
   build. Then make the same no-semantics one-line edit in each core module and
   measure incremental Develop, Testing, and Production builds over several
   runs. H1 fails if it materially harms the ordinary edit-test loop; H2 should
   leave unoptimized iteration close to A.
5. **Measure launch on the same physical devices.** Use Instruments' App Launch
   and dyld activity evidence across repeated cold and warm launches for each
   platform. Record loaded-image count, pre-main/dyld work, time to the same
   signpost, and variance. Four fewer images is a topology success, not by
   itself a user-visible performance success.
6. **Exercise hosted tests deliberately.** For B, run both complete non-UI plans
   and both Production plans. Add a temporary synthetic sentinel module with a
   shared reference/global and an Objective-C-visible class, expose the host's
   identity through an app bridge, and assert from the XCTest bundle that host
   and test references have the same object/type identity. Inspect app and
   `.xctest` symbol definitions and runtime logs for duplicate class/metadata
   warnings. Remove the sentinel after the experiment. Any duplicate loaded
   identity rejects the static topology even if ordinary tests pass.
7. **Prove coverage rather than weakening it.** Generate a fresh canonical macOS
   result for each variant and inventory `xccov` target/file attribution. Every
   current framework source must still have exact integer line evidence. If
   attribution moves, prototype a checker keyed by canonical source paths and
   build-target membership; do not lower or aggregate away the existing 100%
   business-logic requirement.
8. **Check archive and runtime semantics.** Run strict lint, both native app-test
   lanes, UI smoke, privacy-manifest checks, clean archives, launch, recipe
   import, SwiftData store open/migration, and a representative Cooking Session.
   Search build and runtime logs for missing symbols, duplicate symbols/classes,
   loader failures, resource failures, and test discovery differences.
9. **Simulate the next executable before committing.** Add a throwaway minimal
   extension or command/helper target that consumes Domain and one higher layer.
   Compare whether static duplication or a deliberately retained/grouped
   dynamic framework better matches the plausible future product. This keeps a
   present optimization from silently taxing the first widget, intent, or
   helper.

Adopt H2 only if it removes the four private dylib loads from both Production
apps, preserves every correctness and coverage contract, and shows a worthwhile
size or launch improvement without meaningful build/maintenance regression.
Adopt H1 instead only if it beats H2 on measured release results and passes the
stronger hosted-test identity proof. Otherwise retain H0; four internal dylibs
are not a defect in the absence of measured cost.

## Decision consequence

The research supports the original intuition but refines the implementation:
Kitchen Memory's four deep modules are **organizational and compile-time
boundaries inside one product family**, not independently evolving runtime
products. Preserve those boundaries. First try making the distributed app one
runtime image through Production-only mergeable frameworks; use straight static
frameworks as the controlled comparison. An accepted linkage change would not
conflict with ADR 0003's domain/persistence boundary or ADR 0009's four reusable
framework targets. A new group framework or changed test topology would require
those architecture and CI documents to be updated explicitly.
