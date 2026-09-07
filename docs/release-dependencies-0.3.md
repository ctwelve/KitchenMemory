# 0.3 dependency and signed-product evidence

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

[Issue 125](https://github.com/ctwelve/KitchenMemory/issues/125) prepares the
0.3.0 source state. It does not tag, publish, or accept a distribution.
The current component review and update procedure live in
[the software inventory](../DEPENDENCIES.md); exact revisions, licenses, and
relationships live in [the SBOM](../SBOM.spdx.json).

## Candidate and environment

Base: `5d03c91b2adb7dfd73e1cb3131fe7b386a1fb4cc`, after the documentation
consolidation. Source, test, resource, and project candidate: `d701bcd3865a058f41bb5711a386b8a0d3a4186f`.
The working marketing version is 0.3.0 in every application configuration;
the build-number seed remains 1 under [the release contract](release-engineering.md).
Xcode Cloud advances distributed build numbers. The existing `RELEASE` marker,
schema declarations, CloudKit deployment, and runtime behavior are unchanged.

Validation date: September 7, 2026. Xcode 26.6 (17F113), Swift 6.3.3
(swiftlang-6.3.3.1.3), macOS 26.6.2 (25G83). Native application tests use Xcode's
Test action and its managed test-runner signing. The standalone framework
runner owns the canonical exact coverage result.

## Dependency review and reproducibility

All six source packages were compared with their current upstream stable
releases and tagged manifests. Defaults 9.0.9, Collections 1.6.0, Algorithms
1.2.1, Numerics 1.1.1, and SwiftSyntax 603.0.2 remain current stable pins.
SwiftLintPlugins and its executable advance together to 0.65.1. The inventory
records platform/toolchain requirements, licensing, privacy, product roles,
executable/plugin capabilities, and the reason for deferring newer SwiftSyntax
prereleases. No runtime package changes or new data recipient are introduced.

The reviewed SwiftLint plugin implementation and permissions are unchanged.
Its new artifact SHA-256 is
`c3a1d77647ca18c1b7e9be7dbc6cd4490d26422f28814b76370244ff61970869`.
The tagged plugin manifest, upstream release-asset digest, downloaded ZIP, and
SBOM agree. A fresh package resolution produced all six committed revisions;
subsequent platform builds use only versions from the committed resolver file.
No lint rule, baseline, or exclusion was relaxed.

The application now packages the complete upstream license texts for Defaults,
Collections, Algorithms, and Numerics, including Swift's Runtime Library
Exception and copyright attribution, alongside its own license. The reviewed
`ThirdPartyNotices.txt` SHA-256 is
`f68923bf4cc1a9552d1db90f2d6e882518b48da6e178e1f5f33b72eaf1a5a57e`.
The hosted resource test checks those exact bytes in the compiled bundle.

## Archive correction

The existing Numerics C module-map workaround addressed ordinary builds only.
A signed Archive action relocates BUILD_DIR under ArchiveIntermediates, so both
platform archives failed to resolve `_NumericsShims`. KitchenKit now searches
the standard ordinary and archive paths to the same pinned headers. This changes
no linked package product or source implementation. Actual signed archives are
the regression check; a source-only assertion about the path would not establish
that Xcode can import the module.

An earlier command also supplied a separate package checkout directory, which
is incompatible with this documented DerivedData-relative workaround. Final
builds use Xcode's standard SourcePackages location. Xcode initially rejected
the changed SwiftLint fingerprint; the maintainer trusted the reviewed update
through Xcode before native testing resumed.

## Validation ledger

| Gate | Result |
| --- | --- |
| Upstream and pin review | Six source revisions match fresh resolver checkouts; SwiftLint ZIP, upstream digest, manifest, and SBOM checksums agree. |
| Source contracts | 92 Ruby tests / 334 assertions and seven Python tests passed. Documentation, localization, project/resource membership, inventory, and ordinary untagged release checks passed. |
| Strict lint | SwiftLint 0.65.1: zero violations across 347 Swift files. |
| Exact durable coverage | 568/568 framework tests passed; 13,817/13,817 executable lines, with the same 130 runtime-adapter lines excluded under ADR 0007. Fresh canonical runner exited successfully against the final project configuration. |
| Native macOS | Final full Xcode Test action 1799-9: 186/186 passed (180 hosted + six UI), including the corrected attribution digest. |
| Native iOS | Final full Xcode Test action 1799-10: 184/184 passed (178 hosted + six UI), including the corrected attribution digest; iPhone 17 Pro simulator, iOS 26.5 (23F77). |
| Static analysis | Testing configuration: native macOS and generic iOS Analyze actions passed. |
| Signed Production archives | Final reviewed candidate: universal macOS and arm64 iOS archives passed; both signed payload inspections passed. |
| Independent Standards review | One missing source-attribution finding corrected in d701bcd; zero remaining actionable findings. |
| Independent Spec review | Zero actionable findings in both implementation and signed-product/evidence review. |

All final test actions reported zero failures, skips, or expected failures.
The native counts come from the saved platform result bundles, not a cached
bridge summary. Final source, tests, resources, pins, and project configuration
are d701bcd; later edits affect documentation only. Static analysis remains
applicable because the subsequent review correction adds notice text and updates
its test digest without changing analyzed production code.

The signed archive logs retain the previously observed Swift Collections
shared-object debug-map warnings and the AppIntents tool's no-dependency notice.
Both Archive actions completed successfully; no compiler error, new lint waiver,
or relaxed gate is hidden by those diagnostics.

## Signed payload observations

Both Production archives carry version **0.3.0 (1)** and the production app
identifier. macOS includes arm64 and x86_64; iOS includes arm64. Both use Apple
Development certificates and pass deep, strict code-signature verification.
These are signed release-configuration engineering artifacts; they are not
Developer ID exports, notarization/Gatekeeper proof, or TestFlight uploads.

Each application contains exactly one Mach-O executable and no embedded
frameworks. The executable dynamically loads only Apple system frameworks and
libraries. Archive linker inputs confirm Defaults and DequeModule in the app;
the merged KitchenKit includes Algorithms, OrderedCollections, and transitive
RealModule and Collections implementation modules. SwiftLint, SwiftSyntax,
DefaultsMacros, test runners, and other executable tools are absent from the
application payload. Stripped binary symbols alone are not used to infer this
graph; final payload enumeration and actual linker inputs are checked together.

Exactly two privacy manifests are present: the application manifest and the
Defaults resource-bundle manifest. Their decoded dictionaries exactly match
the reviewed source files. Both declare no collected data; neither declares
tracking. UserDefaults reasons remain CA92.1 for the app and C56D.1 for Defaults.
The notices in both signed products match the reviewed digest above, including
the source-header attribution added after independent review.

Signed entitlements retain `iCloud.net.ctwelve.KitchenMemory` and CloudKit; the
Mac app retains its sandbox. These artifacts were inspected without launching
them against a personal library or deploying any CloudKit schema.

| Reviewed executable | SHA-256 |
| --- | --- |
| macOS universal | `eda9f4c95c5d3855923e0dbfb0054437d904642e3ca5b2f6edf6ae513b45abed` |
| iOS arm64 | `2ccfeaacd15ad6639eaf1d9fb5e841c6ec9544784f542c304586f468b1f164bd` |

Reproduce with the committed project and resolver: use `xcodebuild archive`,
KitchenMemory scheme, Production configuration, standard DerivedData package
layout, and generic macOS/iOS destinations. Use
`-onlyUsePackageVersionsFromResolvedFile` and the maintainer's configured signing.
Inspect completed products with `codesign --verify --deep --strict`, `otool -L`,
architecture inspection, manifest decoding, payload enumeration, and the notice
digest. Both archive checkouts matched all six committed revisions after build.
Signing/cache paths and local account details are intentionally not recorded here.

## Alpha scope and remaining acceptance

This change affects no navigation, control semantics, focus, layout, or authored
copy. The bounded Mac ordinary-use evidence from
[the Recipe Library pass](accessibility-alpha-library-evidence.md) and
[the shell and Session pass](accessibility-alpha-shell-evidence.md) therefore
carries forward for those unchanged interactions on the same Xcode/macOS
environment. Fresh native semantic tests supplement that evidence.

The maintainer selected macOS-only 0.3-alpha distribution in
[Issue 126](https://github.com/ctwelve/KitchenMemory/issues/126). iOS compilation,
archive, and native tests remain engineering checks; an iOS ordinary-use
walkthrough and iOS distribution are deferred. The comprehensive device,
VoiceOver, focus, language, and layout matrix remains unverified beta work under
[Issue 168](https://github.com/ctwelve/KitchenMemory/issues/168). Cloud UI testing
remains suspended under [Issue 155](https://github.com/ctwelve/KitchenMemory/issues/155).
None of those deferred checks is reported as passed.

Final documentation reconciliation (#85), the engineering acceptance packet
(#126), and explicit maintainer release acceptance remain separate gates.
