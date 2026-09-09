# Reversible bundled sample pack

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Issue [#88](https://github.com/ctwelve/KitchenMemory/issues/88) makes the bundled
sample pack an explicit, reversible request. Its accepted enabled state is
separate from observed content: edited, deleted, unavailable, partially installed,
and fully installed samples remain visible as observations. Neither launch,
refresh, nor personal-iCloud preference delivery performs installation or removal.
The displayed counts describe this device's available evidence, not global sync
completion.

`SamplePackCommand` retains one request identity, localized ordinary organization
names, caller-proposed Folder and Tag identities, bundled content, and the exact
Recipe identities offered for removal. The app retains a failed command for
explicit retry in the current process. Relaunch reads accepted evidence and never
replays an unaccepted request automatically. A new explicit request after relaunch
is a new operation; an accepted root receipt prevents duplicate command effects.

`SwiftDataSamplePackRepository` owns a fresh local transaction. It uses the ordinary
Recipe Save, Delete and Restore acceptance helpers and Folder/Tag policies in
that transaction. A receipt in the existing V7 `sample-pack` namespace binds the
request digest, enabled state, and ordinary organization identities. Receipts
are retained; current maintenance only compacts Folder and Tag namespaces.
Kitchen ownership convergence and explicit reset already include all organization
namespaces. The physical SwiftData schema is unchanged.

An explicit off-to-on transition creates or reuses case-insensitive live matches
for the localized root Sample Pack Folder and samples Tag. Leading hashes remain
Tag presentation syntax. Concurrent ordinary names can still collide and use
Organization Recovery. During an enabled period, explicit installation of missing
samples reuses the recorded identities through ordinary aliases, respects renamed
or moved organization, and does not recreate deleted organization or reassign
existing Recipes. Toggling off and then on begins a fresh matching opportunity.

Removal previews the untouched current samples, then rechecks them at acceptance.
A Recipe with additional revision history or content differing from the bundled
Revision is preserved, including an edit accepted after the preview. Unrelated
Recipes, Folders, and Tags are never deleted. The comparison is deliberately
conservative: an older or otherwise different bundled Revision is preserved
rather than guessed to be untouched. Ordinary deletion retains Recipe and Session
evidence and uses the existing Deleted Items and retention contracts.

An explicit reinstall restores only available, untouched deleted samples, using
ordinary resolutions for the observed deletions. A concurrent unobserved deletion
can keep a Recipe hidden. Edited deleted Recipes, pruned identities, and incomplete
or invalid authority stay retained and are not replaced. An ordinary refresh or
an installation request during an already enabled period does not restore manually
deleted samples. Restoring a sample independently never changes the enabled state
or triggers another removal.

Tests use synthetic in-memory Kitchens to exercise atomic rollback, stable retries,
localized matching, identity preservation, edited and late-edited histories,
ordinary deletion/restoration, and refresh behavior. Hosted tests exercise the
setting's confirmation and retry seams; UI automation remains limited to the
existing accessible application shell.

Kitchen reset reads the accepted sample-pack setting before erasing Kitchen
contents. A disabled pack leaves the reset Kitchen empty; reset does not change
the first-run sample response into consent. An enabled pack retains the existing
reset behavior of restoring the bundled samples.
