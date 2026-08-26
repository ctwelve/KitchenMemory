<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# Privacy

Kitchen Memory is not interested in your data. Your recipes exist to serve your
kitchen, not to produce analytics, advertising profiles, engagement
measurements, or saleable data.

## What the app does today

The 0.1 application does not include advertising, analytics, telemetry, or a
crash-reporting service. It declares no tracking and no collected data in its
Apple privacy manifest.

Kitchen Memory uses `UserDefaults` for two preferences: remembering your answer
to the sample-recipe onboarding question and whether this device should
synchronize recipes with iCloud. When private iCloud sync is available, Apple's
iCloud key-value store carries only the sample-recipe answer between your
devices. The synchronization choice stays on this device so one device cannot
silently change another device's setting. The app privately synchronizes your
recipe library through your iCloud account only while that setting is enabled.
Private iCloud synchronization is a feature you direct, not a way for this
project to observe you, and it will never be repurposed for analytics.

## Debugging and support

Debugging information is the only category of data the project might have a
legitimate reason to request or collect in the future. Any such use must be
narrow, necessary to diagnose a specific failure, and disclosed before a build
that collects it is distributed.

If you deliberately provide a private artifact with a support report, we may
inspect only what is necessary to answer that report. We will not retain private
data exposed during debugging. We will delete it when the immediate diagnostic
need ends, will not add it to a test or regression corpus, and will derive the
smallest non-private example that still reproduces the defect.

We will never reveal private debugging material in a public issue, commit, pull
request, documentation page, presentation, model-training corpus, or other
public context. That includes recipe JSON, preserved source evidence, source
URLs, family recipes, photographs, account details, identifiers, and logs that
contain any of them. We do not need to publish Aunt Matilda's secret artichoke
dip recipe to explain or fix a bug.

Any future diagnostic system must minimize collection and retention, exclude
recipe and account content by design, and prohibit advertising, profiling, or
engagement-analytics use. Before it ships, the project must update the app's
privacy manifest, App Store privacy disclosure, and this policy.

## Release discipline

Every release candidate audits the app and its bundled dependencies against the
privacy manifest. Adding telemetry, crash reporting, advertising, attribution,
or another data-transmitting dependency is a privacy change even when it arrives
through a transitive package.

The privacy manifest describes the current binary. This document states the
project's broader promise. Neither may be treated as paperwork copied forward
without verifying what the release actually does.
