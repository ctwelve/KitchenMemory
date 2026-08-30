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

Only the `Defaults` library product is linked. `DefaultsMacros` is deliberately
not linked: the onboarding preference remains behind Kitchen Memory's testable
storage protocol, and no application model currently needs its observation
macro.

Defaults includes its own privacy manifest and declares no collected data. Its
iCloud helper owns the 0.1.1 preference synchronization; Kitchen Memory retains
only the product-specific rule that an iCloud account change clears the prior
account's answer. Value-bearing `Defaults.iCloud` debug logging must not be
enabled under Kitchen Memory's privacy policy.

## Build and resolution components

| Component | Version | License | Purpose |
| --- | --- | --- | --- |
| [SwiftLintPlugins](https://github.com/SimplyDanny/SwiftLintPlugins) | 0.65.0 | MIT | Direct SwiftPM build-tool plugin used by Xcode targets |
| [SwiftLintBinary](https://github.com/realm/SwiftLint) | 0.65.0 | MIT | Executable artifact selected by SwiftLintPlugins; SHA-256 pinned in the SBOM |
| [swift-syntax](https://github.com/swiftlang/swift-syntax) | 603.0.2 | Apache-2.0 | Resolved transitive dependency of Defaults' macro targets; not linked because `DefaultsMacros` is unused |

Xcode Cloud bypasses interactive package-plugin fingerprint approval because it
cannot answer that prompt. That exception is bounded by exact revisions in
`Package.resolved`, the SwiftLint artifact checksum, this inventory, and review
of every dependency update.

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
