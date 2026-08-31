# Session managed CloudKit acceptance harness

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

This separate signed harness exercises Cooking Session V3 evidence through
SwiftData's managed private-CloudKit transport. It is intentionally absent from
the Kitchen Memory project, schemes, archives, and Production binaries.
Reusable reconstruction and classification remain in `KitchenKit`; this tool
only stages synthetic evidence and records bounded observations.

The executable refuses any container except
`iCloud.net.ctwelve.dev.KitchenMemory` and refuses to open a store unless the
wrapper supplies a disposable-root marker. It never initializes or promotes
Production schema.

## Build and local checks

Build the signed Mac harness and run the deterministic fixture matrix:

```sh
Tools/SessionCloudKitAcceptance/build.sh
Tools/SessionCloudKitAcceptance/run.sh --replica-root \
  /private/tmp/KitchenMemorySessionAcceptance-localmatrix local-matrix
Tools/SessionCloudKitAcceptance/run.sh --replica-root \
  /private/tmp/KitchenMemorySessionAcceptance-schema schema
```

Initialize the additive V3 schema only when the Development environment is
ready for it:

```sh
Tools/SessionCloudKitAcceptance/run.sh --replica-root \
  /private/tmp/KitchenMemorySessionAcceptance-schema initialize
```

`schema` reports generated entity and field shape. CloudKit Console remains the
authority for reviewing server indexes, standard security roles, and the
absence of unexpected encryption changes before any later Production
promotion.

## Transport commands

Every phase uses a fresh UUID and a named disposable replica. `stage` appends
one actor's transactions; `reconnect` reopens a retained local-only replica
with managed CloudKit; `observe` polls a receiving store until its retained
domain evidence satisfies the requested checkpoint or the operator-controlled
timeout expires.

```sh
Tools/SessionCloudKitAcceptance/run.sh --replica-root \
  /private/tmp/KitchenMemorySessionAcceptance-A \
  stage --scenario E2b --run <uuid> --actor A --store cloud --wait 30

Tools/SessionCloudKitAcceptance/run.sh --replica-root \
  /private/tmp/KitchenMemorySessionAcceptance-B \
  stage --scenario E2b --run <uuid> --actor B --store cloud --wait 30

Tools/SessionCloudKitAcceptance/run.sh --replica-root \
  /private/tmp/KitchenMemorySessionAcceptance-clean \
  observe --scenario E2b --run <uuid> --store cloud --timeout 300
```

For a local-only reconnection, stage with `--store local`, then reopen the same
replica with `reconnect`. A successful framework operation is reported only as
an operation result. The sole pass authority is the final
`receiving-store-domain-evidence` conclusion. A pass compares the complete
expected evidence multiset and every row's content, not only classification,
counts, identifiers, or operation status.

## Required matrix

| Scenario | Phases | Required receiving-store conclusion |
| --- | --- | --- |
| E1 | A and B, both reconnect orders | Identical roots coalesce; conflicting roots classify as Recovery. |
| E2b | A and B, both orders | Both immutable Facts survive in ordinary projection. |
| E3 | foreground, background, and terminated-then-relaunch phases | Foreground and background require a remote-store notification before exact receiving-store evidence; relaunch rebuilds from retained evidence without requiring a new notification. |
| E4a | A, partial observe, then B; reverse full delivery order too | A's Closure and Restore prefix is Unavailable; full root, Fact, Closure, Delete, and Restore evidence rebuilds a restored Finished Session. |
| E4b | One local-only replica plus one cloud replica, both reconnect orders | Both retained Facts converge; neither copy is treated as an authoritative backup. |
| E5 | Delete, independent offline Fact, deleted checkpoint, Restore, both orders | Deleted and restored checkpoints retain the Fact and all disposition evidence without cascade or silent resurrection. |
| E7 | A1, successful operation window, A2, clean receiver | A later export is possible and only receiver content proves receipt. |

A timeout is inconclusive and rerunnable. A repeatable content mismatch, lost
evidence, silent resurrection, or unreconstructable graph is a failure.

### E3 lifecycle phases

Use a new run UUID for each phase. For `foreground` and `background`, start the
receiver's `observe` command first, put the signed app in the named lifecycle
state, and then stage actor A from another replica. Those phases cannot pass
until both a persistent-store remote-change callback and the exact expected
domain evidence are observed. For `relaunch`, keep the receiver terminated
while actor A stages, then launch it with `--phase relaunch`; retained store
evidence is authoritative even if no new notification accompanies that launch.

```sh
Tools/SessionCloudKitAcceptance/run.sh --replica-root \
  /private/tmp/KitchenMemorySessionAcceptance-E3-receiver \
  observe --scenario E3 --run <uuid> --phase foreground \
  --store cloud --timeout 300
```

The product's hosted tests separately prove that a remote-store callback
crosses to the main actor and that the composition root discards the Session
read context before reloading ordinary, Deleted, Unavailable, and Recovery
presentation. The signed phases prove transport and relaunch behavior; neither
substitutes for the other.

## iPhone and iPad

Build the separate iOS harness with the signed Develop product's provisioning
profile, install it with Xcode's device tools, and launch the same `observe`
command against an already staged synthetic run:

```sh
Tools/SessionCloudKitAcceptance/build-ios.sh
xcrun devicectl device install app --device <device> \
  /private/tmp/KitchenMemorySessionAcceptanceIOSBuild/SessionCloudKitAcceptance.app
xcrun devicectl device process launch --device <device> --console \
  --terminate-existing \
  --environment-variables \
  '{"KM_ACCEPTANCE_DISPOSABLE_ROOT":"/private/tmp/KitchenMemorySessionAcceptance-iOS","KM_ACCEPTANCE_REPLICA":"iOS-clean"}' \
  net.ctwelve.dev.KitchenMemory observe --scenario E3 --run <uuid> \
  --phase relaunch --store cloud --timeout 300
```

The harness uses the Development app identifier and therefore replaces an
installed Develop build on that device. It never replaces a Production build.
Keep the device unlocked while Xcode installs and launches it.

## Evidence and cleanup

Output contains scenario and synthetic run identifiers, counts, short digests,
classification, bounded operation counts, and conclusions. It does not contain
recipes, authored Session content, account identifiers, store locations, or
database dumps. Raw console output and build products remain local and
disposable; commit conclusions only.

Replica stores live under the harness sandbox's temporary directory. Remove
obsolete build products and stores deliberately after the acceptance run. Do
not reset a tester's ordinary Kitchen Memory store or retain private diagnostic
artifacts.
