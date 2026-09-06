# Startup latency investigation (#72)

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

## Scope and source

Measured on 2026-09-06 with signed `Develop` builds from baseline
`7cb98dbe5b15982f31e8cdd4e694c566f7e26ac6` (0.2.7). The focused optimization is
`55ff9b6e1626e9fe0eba6b1f2864b6945d84f355` (0.2.9); 0.2.8 is reserved by the independent Tag slice. No release tag,
Production schema change, or distribution is part of this investigation.

Xcode 26.6 (17F113), macOS/iOS SDK 26.5, Swift 6 language mode, Develop's ordinary
unoptimized and coverage-enabled build settings, existing development signing,
and `net.ctwelve.dev.KitchenMemory` were used throughout. Hardware:

- MacBook Pro, Mac15,6, Apple M3 Pro; macOS 26.6.2 (25G83).
- iPhone 16 Pro Max, iPhone17,2; iOS 26.6.1 (23G83), wireless developer connection.
- iPad Pro 12.9-inch, third generation, iPad8,7; iPadOS 26.6.1 (23G83), wired.

The temporary overlay is documented in [StartupMeasurements](../Tools/StartupMeasurements/README.md).
Preparation script SHA-256:
`dce209e2e499d195c73b2d0cc2eb05c92f97ce9c7431b77a1c03b88c2d3a90cb`.
Swift template SHA-256:
`39b1135b8dade10fee15bf2f69e876a8d42590e8597d34107f2502cddc60672f`.
These hashes identify the overlay used for the accepted baseline and candidate
measurements. The production source has no measurement hooks.

## Protocol and boundaries

There are three successful repetitions in every hardware × local/cloud ×
attached/detached cell: 36 baseline launches. Each verifies the twenty expected
synthetic Recipe identities. Seed launches, locked-device failures, exploratory
harness runs, and receiver launches are excluded from those cells. Both debugger
modes capture bounded console milestones. Attached device launches suspend before
dyld, wait for a confirmed LLDB attachment, and continue; the app independently
checks its traced state. This measures that developer launch configuration,
including debugger/console effects, not an uninstrumented release launch SLA.

Fixtures use deterministic synthetic identities and simple titles. Local and
cloud replicas use separate sandbox stores with the ordinary V7 schema,
migration plan, repository, startup coordinator, and external-refresh path.
Cloud replicas select only `iCloud.net.ctwelve.dev.KitchenMemory`'s private
Development database. That database may contain other development records;
fixture verification proves the expected identities, not an identical total
cloud/local dataset. Thus a cloud-minus-local difference is not a measurement of
transport overhead. No account IDs, private content, raw console logs, or per-run
timing history are committed. No normal store was reset.

All table times are seconds from app entry, shown as median (minimum–maximum).
The first-frame marker is the existing draw/display-link observer's display
boundary approximation. Library readiness follows the first successful ordinary
library read, including its presentation assignment. The read column isolates
that read from model construction and view scheduling. Kernel process-start
offsets were also collected: attached device offsets include deliberate debugger
setup and suspension, so those seconds must not be called application work.
Host wall duration includes launch services, console transport and observation
holds; it is not used as time to first frame.

## Baseline matrix

| Hardware / store / debugger | First frame | Locally readable library | Median library read |
| --- | ---: | ---: | ---: |
| Mac / local / detached | 0.190 (0.175–0.203) | 0.421 (0.396–0.457) | 0.171 |
| Mac / local / attached | 1.344 (1.261–1.406) | 1.615 (1.548–1.707) | 0.205 |
| Mac / cloud / detached | 0.174 (0.169–0.248) | 0.485 (0.476–0.610) | 0.248 |
| Mac / cloud / attached | 1.495 (1.392–1.705) | 1.851 (1.832–2.247) | 0.315 |
| iPhone / local / detached | 0.053 (0.050–0.059) | 0.214 (0.211–0.217) | 0.126 |
| iPhone / local / attached | 5.939 (5.663–6.289) | 9.206 (7.882–9.421) | 0.133 |
| iPhone / cloud / detached | 0.057 (0.053–0.058) | 0.283 (0.283–0.285) | 0.185 |
| iPhone / cloud / attached | 5.396 (4.887–5.727) | 8.715 (8.213–9.980) | 0.209 |
| iPad / local / detached | 0.148 (0.147–0.155) | 0.560 (0.560–0.567) | 0.337 |
| iPad / local / attached | 0.838 (0.670–0.927) | 2.058 (1.920–2.359) | 0.317 |
| iPad / cloud / detached | 0.148 (0.147–0.150) | 0.723 (0.723–0.803) | 0.490 |
| iPad / cloud / attached | 0.763 (0.675–0.829) | 2.230 (2.023–2.297) | 0.465 |

Three separate fresh receiving stores initially lacked the synthetic fixtures.
The ordinary library refresh subsequently made both the twenty base Recipes and
one additional synthetic Recipe readable at 11.286 seconds on Mac, 10.345 seconds
on iPhone, and 10.303 seconds on iPad. Their local empty libraries were available
before the imported evidence. These are receiving-store observations with
one-second polling granularity, not sender-to-receiver delivery SLAs or global
CloudKit completion. No startup path waits for this observation loop.

## Ownership and focused correction

For attached local and cloud launches on all hardware, the largest added delay
is associated with the debugger/console launch configuration. The wireless
iPhone difference is particularly large and occurs mostly before the actual
library read. The probes do not isolate LLDB, console transport, or individual
framework initialization internals from each other; attributing all of that
time to CloudKit or repository work would be unsupported.

For detached iPhone and iPad launches, the app's synchronous repository read and
SwiftData reconstruction are the largest measured post-entry stage. On detached
Mac, that work and initial UI/framework presentation are comparable. Later
receiving-store arrival is a separate managed-transport/import/refresh interval
of roughly ten to eleven seconds in these three runs. There is no evidence here
for moving durability, migration, or authority validation out of startup.

One avoidable application cost was identified directly in the measured read
path: `recipes(in:)` reconstructed authority to exclude Recovery, then `recipe(id:)`
reconstructed the same authority again for ordinary content. The correction
reuses that call-local projection through the same availability/error mapping.
It introduces no retained cache, different authority rules, global lock, or
cross-call reuse. Each later read still reconstructs current retained evidence.
A regression exercise reads, saves a successor, deletes, restores, and reads
again through the same repository instance. Existing corruption, missing-payload,
Recovery, ownership, and external-refresh cases retain their original contracts.

## Candidate comparison and validation

Twelve additional signed Mac launches repeat all four modes, three times each,
with the same retained fixtures and overlay. Compilation and native test runs
were idle during the comparison. Median time inside the initial library read:

| Mac store / debugger | Baseline seconds | Candidate seconds | Reduction |
| --- | ---: | ---: | ---: |
| local / detached | 0.171 | 0.152 | 11.3% |
| local / attached | 0.205 | 0.156 | 24.2% |
| cloud / detached | 0.248 | 0.208 | 15.9% |
| cloud / attached | 0.315 | 0.238 | 24.5% |

These small samples support retaining the eliminated duplicate read, not a
universal percentage improvement. The after comparison is Mac-only; the full
hardware matrix characterizes the baseline. No additional cache, background
rewrite, or authority shortcut is justified by these results. The much larger
debugger-associated startup delay remains outside this narrow optimization.

The candidate passes 522 standalone framework tests and the exact
12,407/12,407 business-logic executable-line coverage gate (118 runtime-adapter
lines excluded). Xcode's iOS application/UI plan passes all 162 tests on the
iPhone 17 Pro Max simulator. Seven measurement-tool tests reject missing actual
reads, absent fixtures, requested-but-unverified debugger modes, duplicate or
out-of-order milestones, malformed output, and unexpected/private fields. They also verify controller reaping after a
device-cleanup timeout and exact Develop-bundle identification.
Xcode’s native Mac application/UI plan also passes all 164 tests.
Project-structure, software-inventory, and version-contract checks pass.

Both physical devices were restored to the ordinary signed Develop 0.2.9 app
from the real checkout after measurements. The restored executable contains no
`KM_STARTUP` or `StartupMeasurement` symbols/strings. The final controller also
passed a signed Mac smoke launch after its timeout/cleanup fix; its additional
sample is excluded from the performance comparison. A later locked-device
controller check timed out, correctly returned incomplete with an unknown-PID
cleanup flag, and was followed by reinstallation of the ordinary Develop app.
No unknown PID was killed by executable name.

Independent Standards and Spec reviews found no application or spec defects.
The Standards review's bounded-controller cleanup finding was fixed and
re-reviewed. No native source changed after the validated optimization commit.
