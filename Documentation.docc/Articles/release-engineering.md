# 0.1 release engineering

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: 0.1 public alpha published
- Planned: 2026-08-23
- Completed: 2026-08-25

The 0.1 feature baseline is complete. Kitchen Memory can create, import, review,
revise, scale, read, localize, and privately synchronize recipes. The following
work was therefore not Slice 11 and did not introduce another product
capability. It was the project's first release-engineering pass: practice
proving that the existing product could be built, installed, operated,
diagnosed, and recovered with release-level discipline.

This was an early-alpha rehearsal, not a claim that 0.1 satisfies the full 1.0
acceptance bar. Expensive gates may be exercised with a representative subset
or deferred when they do not protect an immediate alpha risk. Every reduction
must remain explicit in the candidate evidence; a deferred gate is never a
passing result.

Hardening began from `main` after the completed feature-slice integration branch
was merged. Focused fixes remained small and reviewable; the pass was not
permission to redesign settled domain boundaries or quietly add deferred
features.

## Versioned slice discipline

The working application version now advances with every product slice. Version
0.1.1 is the first slice built on the functioning 0.1.0 public-alpha baseline.
A slice chooses and commits its next semantic marketing version when work
begins, so every accepted slice is identifiable and can become a release
candidate without a later version-only rewrite.

This rule advances `MARKETING_VERSION` across every iOS and macOS application
configuration. It does not change the source `CURRENT_PROJECT_VERSION`, which
remains the Xcode Cloud seed value `1`. A release still requires a matching
immutable `release/<major>.<minor>.<patch>` tag and all applicable acceptance,
production-build, archive, signing, and distribution evidence; advancing a
slice version does not claim that those release gates have passed.

Version allocation and publication are separate decisions. A patch version may
identify a focused bug fix or a coherent body of feature work that hangs
together without constituting the next minor release. Kitchen Memory may accept
that version and begin the next one without publishing an artifact; skipped
public versions are ordinary history, not failed releases. Only an intentional
release commit and tag advance `RELEASE` and begin distribution.

The root `RELEASE` marker records the last submitted release version. It remains
at 0.1.0 during 0.1.1 development. The final release operation changes it to
`0.1.1` in a dedicated source commit, attaches the annotated `release/0.1.1`
tag to that exact commit, and submits the commit and tag together. `RELEASE` is
deliberately a build-visible root file rather than excluded documentation: Xcode
Cloud requires a newly imported file change as well as the tag before it starts
the Archive workflow.

The read-only release contract requires the root marker, every application
configuration's `MARKETING_VERSION`, and the numeric suffix of the immutable
release tag to agree. An untagged development commit may have a newer marketing
version than `RELEASE`; it is a potential release, not a submitted one.

Record candidate-specific results in <doc:release-evidence-0.1>. A plan states
what must be proven; the evidence ledger identifies the exact source state,
environment, result, and non-private record that earned each release claim.

## 0.1 outcome

The accepted candidate is merge commit `98038e9`, protected by the immutable
annotated tag `release/0.1.0`. Its final pull-request Test, Build, Analyze, source-
branch policy, and `main` Production Build actions passed. The production
CloudKit schema was reviewed and deliberately deployed before distribution.

Xcode Cloud did not import the new Git tag and therefore did not start the two
configured Archive actions. GitHub held the correct tag and target throughout;
moving or recreating that evidence to replay a service event was rejected. For
this alpha, the release operator instead archived the same accepted source
locally, exported a universal Developer ID macOS application, notarized it,
stapled the ticket, installed it outside Xcode, and completed an ordinary-use
walkthrough. The verified 0.1.0 (1) ZIP and its checksum were published in the
GitHub prerelease for the existing tag after the release documentation merged
and the resulting iOS and macOS Production Build actions passed.

That fallback is an explicit 0.1 exception, not a silent weakening of the normal
contract. There is no public iOS artifact or TestFlight group. The broader
synchronization, recovery, accessibility, localization, and recipe-corpus gates
listed in <doc:release-evidence-0.1> remain deferred or open exactly as recorded.

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
- For 0.1, run the bundled examples and a small number of varied, non-private
  additions through manual entry or editing, URL import, correction, relaunch,
  scaling, and source review. A roughly twenty-recipe corpus remains a 1.0
  acceptance gate.

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
- Normally run the iOS and macOS Archive actions from the reviewed release tag
  with normal signing, production entitlements, and the production CloudKit
  environment. The documented 0.1 fallback produced only the directly
  distributed Developer ID macOS artifact after Apple's tag synchronization
  failed.
- Confirm version and build numbering, archive contents, privacy declarations,
  credits, license resources, localized metadata, and icon/launch assets.
- TestFlight distribution is not configured yet. The release archives are
  prepared for App Store Connect, but no post-action sends them to a tester
  group. Establish and document the beta-distribution path before beta testing,
  including installation on clean devices and update installation over an older
  candidate.
- Set the project's marketing version, commit it, and allow the reviewed commit
  to pass the required `main` actions before creating a matching tag such as
  `release/0.1.0`. The tag is intended to start the configured archive and
  notarization workflow; release tags are immutable evidence and must never be
  moved to a different commit or reused, even when a service fails to consume
  the event. Keep the source build number at `1`; Xcode Cloud owns Cloud-
  distributed build numbers, while an explicitly accepted local artifact may
  retain the source build number.
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

- For 0.1, enforce automated catalog completeness and perform a developer
  walkthrough of plural behavior, sample content, fallback behavior, and
  representative longer-text layouts. Native-language review of every
  translated locale remains a 1.0 acceptance gate and must not be implied by
  the alpha walkthrough.
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

## Exit criteria and alpha reduction

The full release-engineering target is complete when:

- all required development and pull-request Test and Analyze gates pass for the
  final candidate, the configured production Build actions pass on `main`, and
  all Archive actions pass from its immutable release tag;
- signed archives and the notarized Mac artifact install and launch on the
  supported device classes;
- the representative 0.1 recipe set preserves meaningful recipe content across
  the selected relaunch and synchronization exercises;
- release locales and stable workflows pass the explicitly scoped alpha
  accessibility and layout review;
- the production CloudKit schema and distribution procedure are documented and
  rehearsed; and
- no open defect can lose data, corrupt source meaning, prevent ordinary use, or
  leave a synchronization failure falsely reported as success.

The 0.1 public alpha intentionally completed a smaller acceptance exercise. It
passed the final automated candidate, production schema, immutable tag, direct
Mac signing/notarization, post-extraction security validation, and outside-Xcode
launch gates. It deferred public iOS/TestFlight distribution, native-language
review, the twenty-recipe corpus, and much of the broad device/recovery matrix.
The precise result is recorded in <doc:release-evidence-0.1>; publication does
not convert any omitted row into a pass.

This accepted alpha baseline allows feature development to resume with the 0.2
cooking-session work described in <doc:cooking-sessions>, while the deferred
1.0-quality gates remain visible release work.
