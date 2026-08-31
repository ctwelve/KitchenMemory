# Kitchen Memory 0.2.1

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Kitchen Memory 0.2.1 is a repair release for the public alpha.

## Fixed

- Library reset no longer fails when synchronized alpha data contains a legacy
  Kitchen alongside the current personal Kitchen.
- Starting a Cooking Session no longer resolves a duplicate recipe through the
  wrong legacy Kitchen.
- Startup now converges compatible legacy alpha Kitchens before the library is
  shown and repeats that guarded repair after CloudKit imports.

## Privacy and safety

- Schema V4 records an opaque, container-scoped CloudKit account identifier as
  Kitchen ownership evidence. It does not store a person's name, email address,
  or Apple ID.
- A Kitchen with a different explicit owner is never merged automatically; the
  app stops before changing it.

## Alpha data contract

Alpha builds remain destructive crash-test-dummy software. Nothing stored in
the alpha should be considered permanent, and people should retain original
copies of anything that matters. Kitchen Memory will deliberately hard-reset
alpha cloud storage and stabilize its data contract when beta begins.

The GitHub release includes the verified, signed, notarized universal macOS
application and its checksum.
