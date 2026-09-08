# 0.3.0 publication record

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

[Issue 177](https://github.com/ctwelve/KitchenMemory/issues/177) executes the
maintainer-authorized Mac-only alpha release. The accepted
[engineering packet](release-evidence-0.3.md) and
[signed-product record](release-dependencies-0.3.md) retain their exact test,
privacy, dependency, and artifact scope. iOS tester distribution and App Store
review submission remain deferred.

## Candidate and authorization

The maintainer accepted the engineering packet on September 7, 2026, then
explicitly authorized release execution. Merged candidate
`92ac90501686e163aa830d36bdf2e007cb283e55` passed both actual-merge Production
builds. Product source/tests/resources/project/pins remain unchanged from
`d701bcd3865a058f41bb5711a386b8a0d3a4186f`; the previously inspected Mac/iOS
Production archives therefore remain applicable engineering artifacts.

The separate administration tool is pinned to frozen V7 at `becd981`; its
reviewed procedure is `4d27a9d8cfe0f5c4c822580b986f7d9a1bdd88d3`. Its standalone
build needed the package module and Numerics header paths already used by the
Session acceptance harness. Both independent reviews passed after correcting
the tool index and distinguishing live server additions from local model
comparison. Normal-keychain deep/strict signature verification passed; decoded
entitlements name `iCloud.net.ctwelve.KitchenMemory`, **Development**, and the
Mac sandbox. Shipping targets, schemes, and archives exclude this tool.

## Production schema comparison

The operator supplied the working V7 export from the **Production environment
of `iCloud.net.ctwelve.dev.KitchenMemory`**. The release baseline was separately
exported from **Production in `iCloud.net.ctwelve.KitchenMemory`**, still V4.
These containers and environments are distinct; neither export alone deploys
anything.

The baseline contains 17 model record types plus `Users`; V7 contains 23 model
record types plus `Users`. Exact normalized comparison preserves every existing
field definition, index flag, and grant. No type or field is removed, renamed,
retyped, or given a different encryption choice. The accepted additions are:

| New record type | Generated CloudKit fields, including system fields |
| --- | ---: |
| CD_RecipeSaveRecord | 23 |
| CD_RecipeSelectionRecord | 17 |
| CD_RecipePruneRecord | 19 |
| CD_RecipeImagePayloadRecord | 13 |
| CD_OrganizationActionRecord | 19 |
| CD_OrganizationCheckpointRecord | 20 |

Existing `CD_RecipeDeletionRecord` adds `CD_deletedAt` (TIMESTAMP, queryable and
sortable). Existing `CD_RecipeDeletionResolutionRecord` adds `CD_kitchenID`
(STRING, queryable/searchable/sortable) and `CD_restoredAt` (TIMESTAMP,
queryable/sortable). These are the accepted V5 chronology/ownership additions.
The six new families use the expected generated asset companions and standard
creator-write, iCloud-create, and world-read schema grants; the app uses a
private CloudKit database. No new encryption annotation is introduced.

The local generated V4/V7 comparison separately verifies 17 legacy entity hashes
unchanged and six added scalar-only families, with no relationships or uniqueness
constraints. That comparison uses the current source declarations; the live
server comparison above is the authority for the three newly deployed fields.

The reviewed one-shot tool successfully initialized V7 only in **Development
within the Production container**. It used a unique disposable local store and
reported `productionDeployed: false`. The staged export exactly matches the
working V7 reference, including fields, indexes, and grants. The deployment
summary names the expected eight affected types, 144 added index flags
(2/5 for the two existing types and 22/24/13/24/31/23 for the six new types),
and the three standard roles gaining grants on the new types. All counts match
the export comparison. The Console Diff View rendered an empty pane; the
complete exported definitions and populated Changes summary provide the
comparison evidence. Production deployment and its verification are pending.
Raw exports, account identifiers, store paths, and diagnostic logs remain
private and uncommitted.

## Release submission and artifact

Pending: deploy and verify Production,
merge the intentional RELEASE=0.3.0 commit through required checks, verify that
merge's Production builds, and create the immutable annotated `release/0.3.0`
tag. Archive, notarization, installed-artifact checks, checksums, and GitHub
publication are recorded only after they complete. The existing public 0.2.2
artifact remains the published release until then.
