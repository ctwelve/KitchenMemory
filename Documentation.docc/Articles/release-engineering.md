# 0.1 release engineering

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Accepted plan
- Date: 2026-08-23

The 0.1 feature baseline is complete. Kitchen Memory can create, import, review,
revise, scale, read, localize, and privately synchronize recipes. The next pass
is therefore not Slice 11 and does not introduce another product capability. It
is the project's first release-engineering pass: prove that the existing product
can be built, installed, operated, diagnosed, and recovered with release-level
discipline.

Hardening begins from `main` after the completed feature-slice integration
branch is merged. Focused fixes should remain small and reviewable; this pass is
not permission to redesign settled domain boundaries or quietly add deferred
features.

Record candidate-specific results in <doc:release-evidence-0.1>. A plan states
what must be proven; the evidence ledger identifies the exact source state,
environment, result, and non-private record that earned each release claim.

## Release candidate

The candidate is the personal, local-first 0.1 application for iPhone, iPad,
and Mac. Its supported loop is:

```text
Create or import
      ↓
Review and preserve source meaning
      ↓
Save an immutable recipe revision
      ↓
Scale and read
      ↓
Synchronize through a private iCloud database
```

Cooking sessions, pantry holdings, planning, shopping, household sharing, OCR,
and social features remain outside 0.1. A hardening finding may produce a bug
fix, test, diagnostic, or documentation change; it should not expand this loop.

## Engineering gates

### Product correctness

- Keep exact coverage of executable business logic and preserve the narrow,
  documented exclusion for Apple-owned runtime notification glue.
- Exercise local persistence, immutable revision history, import limits,
  localization fallback, sample identities, and synchronization convergence.
- Add regression tests for every release-blocking defect found during the pass.
- Run an acceptance corpus of roughly twenty varied real recipes through manual
  entry, URL import, correction, relaunch, scaling, and source review.

### Data and iCloud

- Verify the V1 SwiftData model and generated CloudKit schema on clean installs
  before promoting the production schema.
- Test two-device creation and revision, offline work followed by reconnection,
  concurrent edits, deletion, interrupted synchronization, account loss, and
  recovery without fabricating success.
- Confirm that stable Kitchen, recipe, revision, child-row, media, and sample
  identities survive every exercised path.
- Freeze the shipped V1 model. After 0.1, persistence changes require a new
  immutable schema version and additive production CloudKit evolution.

### Production builds and distribution

- Require the development and pull-request Test and Analyze gates to pass for
  the final candidate. Then allow the intentional iOS and macOS production Build
  actions to pass on the resulting `main` commit.
- Run the iOS and macOS Archive actions from the reviewed release tag with normal
  signing, production entitlements, and the production CloudKit environment.
- Confirm version and build numbering, archive contents, privacy declarations,
  credits, license resources, localized metadata, and icon/launch assets.
- TestFlight distribution is not configured yet. The release archives are
  prepared for App Store Connect, but no post-action sends them to a tester
  group. Establish and document the beta-distribution path before beta testing,
  including installation on clean devices and update installation over an older
  candidate.
- Set the project's marketing version, commit it, and allow the reviewed commit
  to pass the required `main` actions before creating a matching tag such as
  `release/0.1.0`. The tag starts the configured archive and notarization
  workflow; release tags are immutable evidence and must never be moved to a
  different commit or reused. Keep the source build number at `1`; Xcode Cloud
  owns the distributed build sequence.
- GitHub requires the aggregate Xcode Cloud pull-request result before merging
  to `main`. Active `release/*` rulesets restrict creation to the release
  operator, require a successful Xcode Cloud `Merge to main` result on the
  target commit, and prohibit tag updates or deletion with no bypass available.
  Xcode Cloud validates the version after the protected tag starts the release.
- Verify the notarized Mac artifact installs and launches outside Xcode before
  treating the workflow result as release evidence.
- Record the production-schema promotion, archive, and submission steps so they
  are repeatable rather than dependent on memory.

### Person-facing quality

- Verify every release locale for catalog completeness, plural behavior, sample
  content, and representative longer-text layouts.
- Audit the durable application shell, Settings, import/review path, recipe
  reading, scaling, and failure surfaces for accessibility on supported
  platforms. Provisional editing interactions remain candidates for later
  redesign, but release-blocking barriers must still be corrected.
- Check startup, empty-library, partial-sample, offline, no-iCloud-account,
  restricted-account, synchronization-failure, and recovery states.

### Diagnostics and recovery

- Ensure operational failures produce actionable, privacy-conscious diagnostics
  without logging recipe contents or unnecessary account identifiers.
- Verify the shipped privacy manifest against the release binary and the
  diagnostic boundary in <doc:privacy>.
- Document what iCloud synchronization does and does not replace, how local data
  behaves offline, and which reset or recovery actions are destructive.
- Maintain a release-blocker list and known-issues record. A workaround must be
  explicit; an unexplained intermittent failure is not a passing result.

## Exit criteria

The first release-engineering pass is complete when:

- all required development and pull-request Test and Analyze gates pass for the
  final candidate, the configured production Build actions pass on `main`, and
  all Archive actions pass from its immutable release tag;
- signed archives and the notarized Mac artifact install and launch on the
  supported device classes;
- the acceptance corpus preserves meaningful recipe content across relaunch and
  synchronization exercises;
- release locales and stable workflows pass the agreed accessibility and layout
  review;
- the production CloudKit schema and distribution procedure are documented and
  rehearsed; and
- no open defect can lose data, corrupt source meaning, prevent ordinary use, or
  leave a synchronization failure falsely reported as success.

Passing these gates establishes the 0.1 release baseline. Feature development
then resumes with the 0.2 cooking-session work described in
<doc:cooking-sessions>.
