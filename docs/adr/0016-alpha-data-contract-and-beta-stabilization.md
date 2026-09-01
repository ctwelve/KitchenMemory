# ADR 0016: Treat alpha data as disposable and stabilize at beta

- Status: Accepted
- Date: 2026-08-31

Kitchen Memory will move aggressively during alpha: alpha builds are destructive crash-test-dummy software, and no alpha library or cloud record is promised to survive. Every public alpha must state that contract plainly. Beta begins with one deliberate hard reset of alpha local and CloudKit data, followed by storage stabilization and migration-compatible evolution; destructive alpha freedom ends at that boundary. Privacy, owner isolation, and bounded diagnostics remain mandatory throughout alpha, so destructive development never permits cross-owner merging or disclosure of private content.

## Consequences

- Alpha fixes may claim and rewrite unowned legacy alpha records when the current owner is established, and may discard incompatible alpha data when preservation would endanger correctness.
- V4 records an opaque Kitchen Owner and refuses to converge Kitchens carrying different owners.
- The beta reset and Production CloudKit stabilization require their own reviewed runbook, user notice, and release evidence before beta distribution.
- Every GitHub release includes the verified notarized macOS artifact; source-only public releases are no longer sufficient.
