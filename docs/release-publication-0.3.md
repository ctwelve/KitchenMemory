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
comparison evidence. The operator then deliberately deployed the reviewed changes. CloudKit Console
reported “Changes Deployed.” A fresh export from the actual Production
environment exactly matches the staged schema and working V7 reference. All
three V7 exports have SHA-256
`e531cafe311f83939ee138435ce92a4e21bdd826849d733cd33b604c24c4dc3e`.
Production now has all 24 expected record types, including `Users`, with the
accepted fields, indexes, and grants.
Raw exports, account identifiers, store paths, and diagnostic logs remain
private and uncommitted.

## Release submission and artifact

[PR 178](https://github.com/ctwelve/KitchenMemory/pull/178) passed every governed
PR check and merged as `492b6980e7b01e5107a619ffe0a639aa58e0ea68`. Both actual-merge
Production builds passed before tag creation. The source marker is 0.3.0 and
all five application configurations agree.

The signed annotated `release/0.3.0` tag has object
`913c2a0a41782474a568f1d83c1fa7fcfdd73ef0` and peels to that exact merge. Local
signature verification passed; GitHub reports the signature valid and verified.
Creation used the repository's configured maintainer allowlist; readiness and
immutability protections remain unchanged. The tag was created once and its
normal Xcode Cloud archive workflow started successfully.

Xcode Cloud build **418** passed both tagged Archives and the Mac notarization
post-action, using Xcode 26.6 (`17F113`). The downloaded products report version
**0.3.0 (418)**, SDK `macosx26.5` / `iphoneos26.5`, and the expected Production
CloudKit container and environment. The Mac product is universal (`arm64`,
`x86_64`), Developer ID signed, hardened, and timestamped; deep/strict signature
verification, Gatekeeper's Notarized Developer ID assessment, and stapled-ticket
validation all passed. The iOS App Store export is `arm64`, Apple Distribution
signed, and passes deep/strict verification. Neither permits debugger attachment.

Both products contain one application Mach-O, no embedded frameworks, and only
Apple system dynamic dependencies. Both retain the two reviewed privacy manifests
(no collected data or tracking; UserDefaults reasons `CA92.1` and `C56D.1`) and
identical third-party notices with SHA-256
`f68923bf4cc1a9552d1db90f2d6e882518b48da6e178e1f5f33b72eaf1a5a57e`.
All six localization bundles contain metadata, credits, and application strings;
compiled assets/icons and the iOS launch storyboard are present. The tagged iOS
archive emitted duplicate Swift Collections debug-map warnings; Archive passed,
and signed-product inspection found no extra binaries or dynamic packages.

Safari expanded the notarized Mac download. The unchanged application was packed
with macOS resource metadata preserved, extracted into a fresh local directory,
and verified again. Every extracted application file matches the notarized
source byte-for-byte. The app launched normally outside Xcode into the Recipe
Library; existing library content appeared, the new Recipe editor opened, its
empty verification draft was discarded, and Settings opened. No store reset or
existing Recipe mutation was performed. This is an ordinary launch/navigation
check, not a claim of comprehensive clean-install/update or synchronization proof.

The [0.3.0 GitHub prerelease](https://github.com/ctwelve/KitchenMemory/releases/tag/release/0.3.0)
was published with the verified **KitchenMemory-0.3.0-macOS.zip** (11,787,749 bytes)
and matching **KitchenMemory-0.3.0-macOS.zip.sha256**. GitHub's uploaded-asset digest
matches the local ZIP SHA-256:
`b5b125ea96c0ec6cc9660ebb7dc76a336b034aaebd827353f3045f409c5f9035`.
The checksum was checked before publication. No iOS tester distribution or
App Store review submission was performed. The accepted engineering limitations
remain in the engineering packet and release notes.
