# Release and milestone records

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

[Documentation map](README.md)

Completed records live in Git history so the working tree stays focused on
current work. The links below pin their original candidate SHAs, observations,
omissions and milestone plans. An open checkbox describes the recorded candidate;
it is not the live backlog or publication status. Use [GitHub Releases](https://github.com/ctwelve/KitchenMemory/releases)
for published artifacts and [GitHub Issues](https://github.com/ctwelve/KitchenMemory/issues)
for remaining work. Current release procedure lives in [release engineering](release-engineering.md).
Use commit-pinned links when citing retired files from issues or pull requests.

- [0.1 roadmap and release boundary](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/alpha-roadmap.md)
- [0.2 roadmap — Cooking Sessions](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/roadmap-0.2.md)
- [Kitchen Memory 0.2 acceptance contract](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/acceptance-0.2.md)
- [0.1 release engineering](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-engineering-0.1.md)
- [0.1 release evidence](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-evidence-0.1.md)
- [Kitchen Memory 0.1.0](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-notes-0.1.md)
- [0.2 release evidence](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-evidence-0.2.md)
- [0.2.1 release evidence](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-evidence-0.2.1.md)
- [Kitchen Memory 0.2.1 rejected candidate](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-notes-0.2.1.md)
- [0.2.2 release evidence](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-evidence-0.2.2.md)
- [Kitchen Memory 0.2.2](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-notes-0.2.2.md)
- [0.3 durable coverage audit](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/coverage-audit-0.3.md)
- [0.3 release preparation evidence](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-preparation-0.3.md)
- [0.3 dependency and signed-product evidence](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-dependencies-0.3.md)
- [0.3 engineering evidence](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-evidence-0.3.md)
- [0.3.0 publication record](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-publication-0.3.md)
- [Kitchen Memory 0.3.1](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-notes-0.3.1.md)
- [Kitchen Memory 0.3.0](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/release-notes-0.3.md)
- [Startup latency investigation (#72)](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/startup-latency-0.2.9.md)
- [Alpha Recipe Library accessibility evidence](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/accessibility-alpha-library-evidence.md)
- [Alpha shell and Cooking Session accessibility evidence](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/accessibility-alpha-shell-evidence.md)
- [Alpha translation validation](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/localization-alpha-validation.md)

## Primary-screen integration

- [Primary-screen slice validation](https://github.com/ctwelve/KitchenMemory/blob/f3592ce39af63b737b49ae7dee80cd558cc64b2a/docs/primary-screen-validation.md): completed #182/#189 evidence, integrated through [PR #209](https://github.com/ctwelve/KitchenMemory/pull/209).

The disposable #183 prototype remains in [Git history](https://github.com/ctwelve/KitchenMemory/tree/8aa01d1/Tools/PrimaryScreenPrototype).
Its implementation has been replaced by the production slice; no prototype
project reference belongs in the shipping workspace.

## Platform 27 and release validation

- [Platform-27 native validation and dynamic-linkage investigation](https://github.com/ctwelve/KitchenMemory/blob/f3592ce39af63b737b49ae7dee80cd558cc64b2a/docs/continuous-integration.md#local-platform-27-validation): completed candidate observations, including warnings and testing limits.
- [Earlier Xcode 26 UI-runner diagnostic](https://github.com/ctwelve/KitchenMemory/blob/f3592ce39af63b737b49ae7dee80cd558cc64b2a/docs/continuous-integration.md#current-ui-runner-diagnostic): historical tooling messages, not the current toolchain baseline.
- [0.3.4 candidate preparation](https://github.com/ctwelve/KitchenMemory/blob/f3592ce39af63b737b49ae7dee80cd558cc64b2a/docs/release-engineering.md#034-alpha-candidate): the immutable candidate failed Cloud validation and was not published.
- [0.3.5 candidate preparation](https://github.com/ctwelve/KitchenMemory/blob/f3592ce39af63b737b49ae7dee80cd558cc64b2a/docs/release-engineering.md#035-alpha-candidate): its pending gates describe preparation time; publication subsequently completed.
- [Kitchen Memory 0.3.5 alpha](https://github.com/ctwelve/KitchenMemory/releases/tag/release/0.3.5): published September 25, 2026, from `ef0ce4817805a319af32ba846b43eb66a3e5d388`, Cloud build 483. The release includes the exact artifact identity/checksum and records signature, Gatekeeper, stapling and standalone-launch acceptance. It requires macOS/iOS 27; public distribution remains the Mac download. No beta or new TestFlight acceptance is implied.
