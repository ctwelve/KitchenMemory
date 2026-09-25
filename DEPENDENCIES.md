# Kitchen Memory software inventory

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

This inventory covers third-party source packages and executable build tools
resolved by the committed Xcode workspace, plus pinned GitHub Actions. The machine-readable source of truth
is [`SBOM.spdx.json`](SBOM.spdx.json); `Package.resolved` remains the resolver's
pin record. CI rejects disagreement among those files and the application's
committed marketing version.

Kitchen Memory does not download executable code or optional modules at runtime.
Apple operating-system frameworks are supplied by the supported platform and
SDK rather than vendored into the application, so they are outside this source
package inventory.

## Runtime component

| Component | Version | License | Purpose |
| --- | --- | --- | --- |
| [Defaults](https://github.com/sindresorhus/Defaults) | 9.0.9 | MIT | Typed local application preferences and observation; iCloud key-value synchronization only for the sample-onboarding preference |
| [swift-collections](https://github.com/apple/swift-collections) | 1.7.0 | Apache-2.0 WITH Swift-exception | `DequeModule` for the ordered Cooking Session outbox, stack-safe causal-graph worklists, and Logic dependency discovery; `OrderedCollections` for first-seen identity coalescing; `HeapModule` for ready organization receipts |
| [swift-algorithms](https://github.com/apple/swift-algorithms) | 1.2.1 | Apache-2.0 WITH Swift-exception | `Algorithms` coalesces duplicate immutable Recipe rows, preserves first-seen uniqueness, selects bounded maintenance pages, and stops import yield discovery at the first valid value |

Only the `Defaults` library product from that package is linked. `DefaultsMacros` is deliberately
not linked: preferences remain behind Kitchen Memory's testable storage
interfaces, with native Observation forwarding for organization preferences.

Defaults includes its own privacy manifest and declares no collected data. Its
iCloud helper owns the 0.1.1 preference synchronization; Kitchen Memory retains
only the product-specific rule that an iCloud account change clears the prior
account's answer. Value-bearing `Defaults.iCloud` debug logging must not be
enabled under Kitchen Memory's privacy policy.

Organization visibility and scoped disclosure preferences reuse Defaults with
explicit local-only keys. Defaults' KVO keys cannot contain dots, so binding a
scope copies existing dotted-key values to supported keys only when the new
value is absent. Owner/store scope is UTF-8 hex encoded in expansion keys;
Kitchen identity remains part of the key. Boolean and Folder string-array
representations are unchanged. This is a local preference-key adoption, not a
SwiftData/CloudKit schema migration. Pending organization commands retain their
separate existing JSON storage and recovery behavior.

`KitchenMemory` and `KitchenKit` link and import the `Collections` umbrella
product. The app uses its deque for the in-memory Cooking Session command outbox
while preserving arrays at the presentation-store codec boundary. KitchenKit
uses deques for causal-graph worklists and dependency traversal, ordered sets for
first-seen identity coalescing, and a heap for causally ready organization
receipts. KitchenKit also links `Algorithms` for immutable-row coalescing, stable
uniqueness, bounded minimum selection for maintenance pages, and first-valid
import yield selection.

The umbrella brings BitCollections, DequeModule, HashTreeCollections, HeapModule,
OrderedCollections, and _RopeModule into the build graph, with implementation
modules including InternalCollectionsUtilities and SpanPreview. This is a
source-import convenience; the SBOM inventories the swift-collections package
regardless of which products are selected. Dead-code stripping remains enabled,
but build-graph membership does not establish which code survives in a shipping
binary. KitchenKit is an ordinary dynamic framework, embedded and signed by the app. Package types
remain implementation details behind KitchenMemory-owned presentation, Domain,
Logic, and repository interfaces. Swift Async Algorithms is not present in the
graph. `KitchenKitTests` also links Collections: optimized `@testable`
access emits references to its internal storage metadata, which is not exported
by the ordinary dynamic KitchenKit framework.

The Xcode 26.6 investigation found that Xcode did not propagate swift-algorithms' transitive `_NumericsShims` C
module-map search path when an Xcode framework target imports `Algorithms`.
Every KitchenKit configuration therefore adds the DerivedData-relative
`swift-numerics/Sources/_NumericsShims/include` path for both standard build and
ArchiveIntermediates layouts. Normal builds place BUILD_DIR two levels below
DerivedData; archives place it five levels below. The ordinary path alone fails
when archiving; the additional archive path resolves the same pinned C headers.
Use Xcode's standard SourcePackages location for these builds. A pristine control
build fails without the module-map path and passes with it. Kitchen Memory neither imports nor
directly links `RealModule`; retain it pending a clean build and archive comparison; remove it when Xcode or the
resolved packages propagate the transitive module map correctly.

The 2026-09-25 review reconfirmed the tagged 1.7.0 and 1.2.1 sources and current
release notes.
Both packages are maintained by the Swift project and use the Apache License 2.0
with Swift's Runtime Library Exception. Neither tagged package contains a
privacy manifest, plugin, executable target, binary target, or runtime network
behavior. swift-collections 1.7.0 requires Swift 6.2 and declares no package
dependencies; swift-algorithms 1.2.1 requires Swift 5.7 and depends only on
swift-numerics. Kitchen Memory's Xcode 27 / Swift 6.4 toolchain and iOS/macOS 27 deployment
targets satisfy those requirements.

Binary distributions must reproduce the Apache 2.0 license, the applicable
Swift project copyright attribution, and the Runtime Library Exception alongside
Kitchen Memory's own notices. The reviewed swift-collections 1.7.0,
swift-algorithms 1.2.1, and swift-numerics 1.1.1 tags do not contain a `NOTICE`
file, so they add no upstream `NOTICE` text to reproduce. Before distribution,
the release acknowledgement surface must include the license and exception text
from each resolved source package; the signed-product inspection verifies that
the shipped acknowledgement still matches the resolved graph.

The application now bundles `Resources/ThirdPartyNotices.txt`, containing the
complete MIT texts for Kitchen Memory and Defaults and the upstream license,
copyright, and Swift Runtime Library Exception texts for Collections,
Algorithms, and Numerics. A hosted test checks the compiled resource against the
reviewed digest. The [0.3 signed-product inspection](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-dependencies-0.3.md)
records actual linkage, privacy manifests, and packaged notices; passing source
checks alone does not prove those files were packaged.

## Build and resolution components

| Component | Version | License | Purpose |
| --- | --- | --- | --- |
| [SwiftLintPlugins](https://github.com/SimplyDanny/SwiftLintPlugins) | 0.65.1 | MIT | Direct SwiftPM build-tool plugin used by Xcode targets |
| [SwiftLintBinary](https://github.com/realm/SwiftLint) | 0.65.1 | MIT | Executable artifact selected by SwiftLintPlugins; SHA-256 pinned in the SBOM |
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | 604.0.0 | Apache-2.0 | Resolved transitive dependency of Defaults' macro targets; not linked because `DefaultsMacros` is unused |
| [swift-numerics](https://github.com/apple/swift-numerics) | 1.1.1 | Apache-2.0 WITH Swift-exception | `RealModule` transitive source dependency of Algorithms; KitchenKit sees only its C module-map search path for Xcode compatibility |

The CI tooling is also pinned and inventoried: [actions/checkout 7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1)
and [actions/upload-artifact 7.0.1](https://github.com/actions/upload-artifact/releases/tag/v7.0.1),
both MIT. Their bundled JavaScript dependency graphs are not individually
enumerated in this source inventory. Checkout retains disabled credential
persistence; we do not enable its unsafe fork-checkout override. The existing
workflow triggers and artifact names/retention remain unchanged. These actions
require a Node 24-capable Actions runner (2.327.1 or later); GitHub-hosted runners
supply it. Their remote execution still requires a subsequent CI run.

Xcode Cloud bypasses interactive package-plugin fingerprint approval because it
cannot answer that prompt. That exception is bounded by exact revisions in
`Package.resolved`, the SwiftLint artifact checksum, this inventory, and review
of every dependency update.

## 0.3 source review

The working application is **0.3.4**. Its source build-number seed remains **1**
under the [release contract](docs/release-engineering.md); Xcode Cloud owns
advancing distributed build numbers. `RELEASE` still identifies the earlier
submitted version. This source preparation creates no release tag or distribution.

All six resolved packages and the SwiftLint binary were checked against upstream
stable releases on 2026-09-25. Collections advances from 1.6.0 to 1.7.0, and
SwiftSyntax advances from 603.0.2 to 604.0.0, matching Swift 6.4. Defaults,
Algorithms, Numerics, and SwiftLint remain at their latest stable releases.
Collections changes DequeModule's internal dependency from ContainersPreview to
SpanPreview and updates standard-library availability for platform 27. Its
additional ownership-aware APIs do not change our selected public interfaces.
SwiftSyntax adds its 604 version marker and internal warning-control dependencies;
the application still does not link DefaultsMacros. Neither update adds an
external package dependency or changes the reviewed license text.

| Component | Reviewed capability and disposition |
| --- | --- |
| [Defaults 9.0.9](https://github.com/sindresorhus/Defaults/releases/tag/9.0.9) | Latest stable; Swift 6.2, iOS 14/macOS 11 minimum. MIT. Its library uses person-directed iCloud key-value transport and declares no collected data; UserDefaults reason C56D.1 remains in its privacy manifest. Optional macro targets resolve SwiftSyntax but are not linked. |
| [Collections 1.7.0](https://github.com/apple/swift-collections/releases/tag/1.7.0) | Latest stable; selected manifest uses Swift 6.2. Apache 2.0 with Swift exception; no package dependency, plugin, executable/binary target, privacy manifest, or runtime network operation in the selected library products. |
| [Algorithms 1.2.1](https://github.com/apple/swift-algorithms/releases/tag/1.2.1) | Latest stable; Swift 5.7. Same Swift-project license; Numerics is its only package dependency. No plugin, executable/binary target, privacy manifest, or runtime network operation. |
| [Numerics 1.1.1](https://github.com/apple/swift-numerics/releases/tag/1.1.1) | Latest stable; Swift 5.9. Same Swift-project license; no further package dependency or executable/plugin/binary target. Its C shim remains a build input; no direct application import or new runtime transport. |
| [SwiftSyntax 604.0.0](https://github.com/swiftlang/swift-syntax/releases/tag/604.0.0) | Latest stable; Swift 5.9 manifest, matching the installed Swift 6.4 generation. Apache 2.0. No root package dependency, plugin, binary target, or privacy manifest. 604.0.0 is now stable and within Defaults’ declared dependency range; prerelease 605 versions are excluded. |
| [SwiftLintPlugins 0.65.1](https://github.com/SimplyDanny/SwiftLintPlugins/releases/tag/0.65.1) / [SwiftLint binary](https://github.com/realm/SwiftLint/releases/tag/0.65.1) | Latest stable patch; MIT, Swift tools 5.9/macOS 12 plugin minimum. Build and command plugins wrap the checksum-pinned executable; command-plugin write permission applies to explicit fixes. No product runtime linkage or new permissions. |

The selected revisions and SwiftLint binary checksum are recorded in the SBOM.
The current validation toolchain is Xcode 27 / Swift 6.4,
which satisfy these source requirements. Collections is the only updated runtime package. No new telemetry or data
recipient is introduced by the reviewed dependency changes. Native frameworks and package
code remain behind the existing application/Kit seams.

## Update procedure

For every dependency change:

1. review the upstream source, changelog, license, privacy manifest, products,
   transitive graph, and executable artifacts;
2. confirm that the dependency's terms permit its intended distribution with
   the MIT-licensed application, preserve every required notice, and remain
   compatible with Kitchen Memory's no-collection privacy stance;
3. update `Package.resolved`, `SBOM.spdx.json`, and this human explanation in the
   same change;
4. run `ruby Tools/Tests/check_software_inventory_test.rb` and
   `ruby Tools/check-software-inventory.rb`; and
5. inspect the final signed application for bundled privacy manifests and
   unexpected frameworks before release.

The inventory describes reviewed source inputs; it is not a vulnerability scan
or a claim that an upstream component has no defects. It exists so later
security review has exact names, versions, revisions, licenses, roles, and
relationships to examine.
