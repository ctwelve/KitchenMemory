# Kitchen Memory software inventory

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

This inventory covers third-party source packages and executable build tools
resolved by the committed Xcode workspace. The machine-readable source of truth
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
| [Defaults](https://github.com/sindresorhus/Defaults) | 9.0.9 | MIT | Typed local storage, observation, and iCloud key-value synchronization for the sample-onboarding preference |
| [swift-collections](https://github.com/apple/swift-collections) | 1.6.0 | Apache-2.0 WITH Swift-exception | `DequeModule` for the ordered Cooking Session outbox, stack-safe causal-graph worklists, and Logic dependency discovery; `OrderedCollections` for first-seen identity coalescing |
| [swift-algorithms](https://github.com/apple/swift-algorithms) | 1.2.1 | Apache-2.0 WITH Swift-exception | `Algorithms` coalesces duplicate immutable Recipe rows during CloudKit merge reconciliation |

Only the `Defaults` library product from that package is linked. `DefaultsMacros` is deliberately
not linked: the onboarding preference remains behind Kitchen Memory's testable
storage protocol, and no application model currently needs its observation
macro.

Defaults includes its own privacy manifest and declares no collected data. Its
iCloud helper owns the 0.1.1 preference synchronization; Kitchen Memory retains
only the product-specific rule that an iCloud account change clears the prior
account's answer. Value-bearing `Defaults.iCloud` debug logging must not be
enabled under Kitchen Memory's privacy policy.

The `KitchenMemory` application target links `DequeModule` for its in-memory
Cooking Session command outbox while preserving arrays at the presentation-store
codec boundary. `KitchenKit` links `DequeModule`, `OrderedCollections`, and
`Algorithms`; the Collections products implement causal-graph worklists,
first-seen identity semantics, and dependency traversal, while Algorithms
coalesces duplicate immutable rows inside the owned Recipe repository. The umbrella
`Collections` product and unrelated collection modules are not linked. Package
types remain implementation details behind Kitchen
Memory-owned presentation, Domain, Logic, and repository interfaces. Swift Async
Algorithms is not present in the graph.

Xcode 26.6 does not propagate swift-algorithms' transitive `_NumericsShims` C
module-map search path when an Xcode framework target imports `Algorithms`.
Every KitchenKit configuration therefore adds the DerivedData-relative
`swift-numerics/Sources/_NumericsShims/include` path for both standard build and
ArchiveIntermediates layouts. Normal builds place BUILD_DIR two levels below
DerivedData; archives place it five levels below. The ordinary path alone fails
when archiving; the additional archive path resolves the same pinned C headers.
Use Xcode's standard SourcePackages location for these builds. A pristine control
build fails without the module-map path and passes with it. Kitchen Memory neither imports nor
directly links `RealModule`; remove this compatibility setting when Xcode or the
resolved packages propagate the transitive module map correctly.

The 2026-09-07 review reconfirmed the tagged 1.6.0 and 1.2.1 sources and current
release notes.
Both packages are maintained by the Swift project and use the Apache License 2.0
with Swift's Runtime Library Exception. Neither tagged package contains a
privacy manifest, plugin, executable target, binary target, or runtime network
behavior. swift-collections 1.6.0 requires Swift 6.2 and declares no package
dependencies; swift-algorithms 1.2.1 requires Swift 5.7 and depends only on
swift-numerics. Kitchen Memory's Xcode 26.6 toolchain and iOS/macOS 26 deployment
targets satisfy those requirements.

Binary distributions must reproduce the Apache 2.0 license, the applicable
Swift project copyright attribution, and the Runtime Library Exception alongside
Kitchen Memory's own notices. The reviewed swift-collections 1.6.0,
swift-algorithms 1.2.1, and swift-numerics 1.1.1 tags do not contain a `NOTICE`
file, so they add no upstream `NOTICE` text to reproduce. Before distribution,
the release acknowledgement surface must include the license and exception text
from each resolved source package; the signed-product inspection verifies that
the shipped acknowledgement still matches the resolved graph.

The application now bundles `Resources/ThirdPartyNotices.txt`, containing the
complete MIT texts for Kitchen Memory and Defaults and the upstream license,
copyright, and Swift Runtime Library Exception texts for Collections,
Algorithms, and Numerics. A hosted test checks the compiled resource against the
reviewed digest. Signed archive inspection verifies the actual distribution
payload; passing source checks alone does not prove notices were packaged.

## Build and resolution components

| Component | Version | License | Purpose |
| --- | --- | --- | --- |
| [SwiftLintPlugins](https://github.com/SimplyDanny/SwiftLintPlugins) | 0.65.1 | MIT | Direct SwiftPM build-tool plugin used by Xcode targets |
| [SwiftLintBinary](https://github.com/realm/SwiftLint) | 0.65.1 | MIT | Executable artifact selected by SwiftLintPlugins; SHA-256 pinned in the SBOM |
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | 603.0.2 | Apache-2.0 | Resolved transitive dependency of Defaults' macro targets; not linked because `DefaultsMacros` is unused |
| [swift-numerics](https://github.com/apple/swift-numerics) | 1.1.1 | Apache-2.0 WITH Swift-exception | `RealModule` transitive source dependency of Algorithms; KitchenKit sees only its C module-map search path for Xcode compatibility |

Xcode Cloud bypasses interactive package-plugin fingerprint approval because it
cannot answer that prompt. That exception is bounded by exact revisions in
`Package.resolved`, the SwiftLint artifact checksum, this inventory, and review
of every dependency update.

## 0.3 source review

The working application is **0.3.0**. Its source build-number seed remains **1**
under the [release contract](docs/release-engineering.md); Xcode Cloud owns
advancing distributed build numbers. `RELEASE` still identifies the earlier
submitted version. This source preparation creates no release tag or distribution.

All six resolved packages were checked against upstream stable releases and tag
commits on 2026-09-07. Five retain their current stable versions. SwiftLintPlugins
and its binary advance together from 0.65.0 to 0.65.1. The plugin implementation
and permissions are unchanged; its package manifest changes the binary URL and
SHA-256, while upstream workflow changes affect only upstream release/test jobs.
The removed SwiftLint `allow_multiline_func` option and moved rule-author API are
not used here. No rule or baseline is loosened for the upgrade.

| Component | Reviewed capability and disposition |
| --- | --- |
| [Defaults 9.0.9](https://github.com/sindresorhus/Defaults/releases/tag/9.0.9) | Latest stable; Swift 6.2, iOS 14/macOS 11 minimum. MIT. Its library uses person-directed iCloud key-value transport and declares no collected data; UserDefaults reason C56D.1 remains in its privacy manifest. Optional macro targets resolve SwiftSyntax but are not linked. |
| [Collections 1.6.0](https://github.com/apple/swift-collections/releases/tag/1.6.0) | Latest stable; selected manifest uses Swift 6.2. Apache 2.0 with Swift exception; no package dependency, plugin, executable/binary target, privacy manifest, or runtime network operation in the selected library products. |
| [Algorithms 1.2.1](https://github.com/apple/swift-algorithms/releases/tag/1.2.1) | Latest stable; Swift 5.7. Same Swift-project license; Numerics is its only package dependency. No plugin, executable/binary target, privacy manifest, or runtime network operation. |
| [Numerics 1.1.1](https://github.com/apple/swift-numerics/releases/tag/1.1.1) | Latest stable; Swift 5.9. Same Swift-project license; no further package dependency or executable/plugin/binary target. Its C shim remains a build input; no direct application import or new runtime transport. |
| [SwiftSyntax 603.0.2](https://github.com/swiftlang/swift-syntax/releases/tag/603.0.2) | Latest stable; Swift 5.9 manifest, matching the installed Swift 6.3 generation. Apache 2.0. No root package dependency, plugin, binary target, or privacy manifest. Newer 604/605 tags are prereleases: changing compiler-coupled, unused macro infrastructure introduces compatibility risk without application benefit. Revisit with the toolchain/actual macro consumer. |
| [SwiftLintPlugins 0.65.1](https://github.com/SimplyDanny/SwiftLintPlugins/releases/tag/0.65.1) / [SwiftLint binary](https://github.com/realm/SwiftLint/releases/tag/0.65.1) | Latest stable patch; MIT, Swift tools 5.9/macOS 12 plugin minimum. Build and command plugins wrap the checksum-pinned executable; command-plugin write permission applies to explicit fixes. No product runtime linkage or new permissions. |

The selected revisions and SwiftLint binary checksum are recorded in the SBOM.
Package resolution and signed-product validation use Xcode 26.6 / Swift 6.3.3,
which satisfy these source requirements. No runtime component changes, new
telemetry, or new data recipient are introduced. Native frameworks and package
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
