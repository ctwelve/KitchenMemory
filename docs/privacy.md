# Privacy

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Accepted direction
- Date: 2026-08-23

Kitchen Memory is not interested in learning about the person using it. Recipe
content exists to serve that person's kitchen, not to produce analytics,
advertising profiles, engagement measurements, or saleable data.

The shipped privacy manifest must describe the code in the current release. The
0.1 application declares no tracking and no collected data. Its only declared
required-reason API is `UserDefaults`, used to retain the app-local answer to the
sample-recipe onboarding question and the device-local iCloud synchronization
choice. One application preferences store owns both keys while preserving those
different scopes. Only the onboarding answer uses iCloud key-value storage; the
synchronization choice must not travel to another device. Private iCloud
synchronization is a person-directed product function, not telemetry, and must
never be repurposed as an analytics channel.

## Diagnostic boundary

Operational diagnostics are the one category the project may have a legitimate
reason to collect in the future. There is no diagnostic collection service in
the 0.1 application today. Before adding one, the implementation and release
review must:

- identify the specific failure that cannot be diagnosed adequately on-device;
- minimize the data and retention period rather than adopting a provider's
  broad defaults;
- exclude recipe content, preserved source evidence, source URLs, Kitchen and
  recipe identifiers, iCloud account information, and unnecessary device or
  person identifiers;
- prevent diagnostic data from being used for advertising, profiling, or
  product-engagement analytics;
- make any person-facing choice and recovery behavior honest; and
- update the privacy manifest, App Store privacy disclosure, and this document
  before the collecting build is distributed.

Debug logs intended to remain on the person's device follow the same content
rules. A convenient log statement is not sufficient reason to expose kitchen
data or account details.

When a person deliberately supplies a private artifact for support, the project
may inspect only what is necessary to answer that report. Any private data
exposed during debugging is temporary: delete it when the immediate diagnostic
need ends, and do not retain it as a fixture, regression corpus, issue
attachment, or institutional memory. Derive the smallest non-private regression
case that still proves the defect.

Private debugging material must never appear in a public issue, commit, pull
request, documentation page, presentation, model-training corpus, or other
public context. This includes recipe JSON, preserved source evidence, family
recipes, photographs, account details, identifiers, and logs that contain any
of them. Explaining a defect never requires publishing Aunt Matilda's secret
artichoke dip recipe.

## Release review

Every release candidate audits app and bundled dependency API use against the
privacy manifest. Adding a telemetry, crash-reporting, advertising, attribution,
or other data-transmitting dependency is a privacy change even when it arrives
as a transitive package. A manifest copied from an earlier release is not
evidence that the current binary has the same behavior.
