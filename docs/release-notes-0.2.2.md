# Kitchen Memory 0.2.2

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Kitchen Memory 0.2.2 is a repair release for the public alpha.

## Fixed

- Library reset now works when synchronized alpha data contains an older
  Kitchen alongside the current personal Kitchen.
- Starting a Cooking Session now finds the recipe in the correct Kitchen.
- Kitchen repair settles cleanly after synchronization instead of repeatedly
  doing the same work in the background.

## Privacy and safety

- Schema V4 records an opaque, container-scoped iCloud account identifier as
  Kitchen ownership evidence. It does not store a person's name, email address,
  or Apple ID.
- A Kitchen with a different explicit owner is never merged automatically.

## Alpha data contract

Alpha builds remain destructive crash-test-dummy software. Nothing stored in
the alpha should be considered permanent, and people should retain original
copies of anything that matters. Kitchen Memory will deliberately hard-reset
alpha cloud storage and stabilize its data contract when beta begins.

The GitHub release includes the verified, signed, notarized universal macOS
application and its checksum.
